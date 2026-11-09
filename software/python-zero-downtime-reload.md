# Python Web 服务热更新与零宕机发布方案

```{contents}
```

Python 进程不像 PHP 那样「每个请求重新加载代码」，也不像 Go 1.8+ 自带
`http.Server` 的 graceful shutdown 与 reload。想在**不中断服务**的前提下换代码，
只能靠进程模型或外部组件配合。本文按「从简单到复杂」列出可落地的方案，
逐个说清优缺点与坑，并附本机实测数据。

> 结论先行：单机 gunicorn 用 `USR2` 起新 master 再 `TERM` 旧 master
> （或 `HUP` 简单重载）成本最低；有 nginx 就做双端口蓝绿；已容器化就交给
> K8s rolling update。**生产环境不要用 `--reload` / `importlib.reload`。**

## 一、先把「零宕机」拆成四件事

发布时可能丢东西的环节有四个，任何方案都只解决其中一部分：

| 环节 | 现象 | 靠什么解决 |
| --- | --- | --- |
| listen socket | 新连接 `ECONNREFUSED` / RST | socket 不随进程关闭：由 master、systemd 或前置代理持有 |
| in-flight 请求 | 正在处理的请求被掐断，502/超时 | graceful shutdown：先停 accept，处理完存量，再退出 |
| 客户端 keep-alive 连接 | 客户端复用旧连接 → RST | 进程退出前让连接自然过期，或客户端重连 |
| 进程内状态 | 会话、本地缓存、定时任务、内存队列 | 无状态化/外部化（Redis、消息队列、定时任务单实例） |

所以工程上说的「零宕机」= **零拒连 + 零 5xx**，不是字面意义的零影响。
字面零影响只有进程内热补丁能做到，而它拿状态一致性换的（见第九节）。

## 二、方案总览

| 档位 | 方案 | 一句话 | 推荐度 |
| --- | --- | --- | --- |
| L0 | 直接重启 | 基线，有明显的拒连与请求中断 | 仅内网工具 |
| L1a | gunicorn `HUP` | master 重新 fork worker，socket 不断 | 单机最省事 |
| L1b | gunicorn `USR2` + `TERM` | 新旧 master 并存，真滚动，可整体换依赖 | **单机推荐** |
| L1c | uvicorn `--workers` + `SIGHUP` | ASGI 原生逐个 worker 重叠替换 | ASGI 可用 |
| L2 | 双实例蓝绿 + nginx 切换 | 换端口 → 健康检查 → `nginx -s reload` | **最通用** |
| L3 | `SO_REUSEPORT` 多 master 同端口 | 内核分发，无需前置代理 | 无 nginx 时可用 |
| L4 | systemd socket activation | socket 由 PID 1 持有，`restart` 也不拒连 | systemd 单机推荐 |
| L5 | 容器/K8s 滚动更新 | `maxSurge` + readinessProbe + preStop | 已容器化的服务 |
| L6 | 进程内热补丁 | 不重启换字节码 | 生产不推荐 |
| L7 | 架构级：配置/插件化 | 把「常改的东西」移出进程 | 长期优化 |

## 三、L0 直接重启（基线）

```bash
systemctl restart myapp
# 或者
kill "$(cat /run/myapp.pid)" && sleep 1 && start-myapp
```

进程退出时它持有的 listen socket 被关闭：**已经在 accept 队列里排队的连接会被
RST，新连接直接被拒绝**；正在处理的请求随进程消失。

- 优点：最简单，没有状态残留，适合「改坏了重开就好」。
- 缺点：有肉眼可见的 downtime，不算零宕机。
- 注意：`Restart=always` 只解决进程自愈，不解决发布中断。

## 四、L1 进程管理器内重载（单机最小改造）

### 4.1 gunicorn `HUP`：最省事的重载

gunicorn 的 listen socket 由 master 持有，worker 只是继承。`HUP` 让 master
重读配置、**先起新 worker，再优雅停旧 worker**，期间 master 一直在 accept
（新连接进内核 backlog 排队，不会 refused）。

```bash
# 启动时一定要带 pidfile
gunicorn -w 4 -b 127.0.0.1:8000 app:app \
    --pid /run/myapp.pid --graceful-timeout 30

# 换代码后
kill -HUP "$(cat /run/myapp.pid)"
```

- 优点：一条命令；框架无感；连接不拒；in-flight 请求在
  `graceful_timeout`（默认 30s）内处理完。
- 缺点：
  - **`--preload` 时 `HUP` 不会加载新代码**（新 worker 是旧 master fork 出来的）。
  - 新旧 worker 交替瞬间容量最低，流量大时可能延迟尖刺或超时。
  - 新代码 import 失败 → 新 worker 起不来而旧 worker 已退出，**服务整体不可用**，
    且 master 还活着（`systemctl status` 看起来正常）。
  - master 自身、gunicorn 版本、Python 解释器、依赖都换不了。
- 适用：单机、只改业务代码、追求最小运维成本。

### 4.2 gunicorn `USR2` + `TERM`：真正的滚动 + 可回滚（单机推荐）

`USR2` 让 master **re-exec 出一个新 master**（新进程读的是新代码/新 venv），
新 master 继承 listen socket 并起自己的 worker；这时新旧两套同时在服务。
确认新版本健康后，让旧 master 优雅退出。

关键实现细节（gunicorn 26.2 源码）：

- `USR2` 后新 master 的 pidfile 是 `<pidfile>.2`，旧 master 退出后自动改名为
  `<pidfile>`（`maybe_promote_master`）。
- **`WINCH` 只在 `--daemon` 模式下才停 worker**（`handle_winch` 里判断
  `cfg.daemon`），systemd/前台运行时会被忽略并打 debug 日志。
  所以 systemd 场景要用 `TERM` 停旧 master（`TERM` = 优雅退出）。

```bash
#!/usr/bin/env bash
# deploy.sh：gunicorn 平滑发布（systemd / 前台模式）
set -euo pipefail

PIDFILE=/run/myapp.pid
HEALTH=http://127.0.0.1:8000/healthz
WORKERS=4

OLD=$(cat "$PIDFILE")
kill -USR2 "$OLD"

# 1. 等新 master 起来（pidfile.2 出现）
for _ in $(seq 40); do
  [ -f "$PIDFILE.2" ] && break
  sleep 0.25
done
NEW=$(cat "$PIDFILE.2")

# 2. 等新 worker 达到预期数量
for _ in $(seq 60); do
  [ "$(pgrep -P "$NEW" | wc -l)" -ge "$WORKERS" ] && break
  sleep 0.5
done

# 3. 新版本健康检查失败 → 回滚（旧 master 还在，随时能接回流量）
if ! curl -fsS --max-time 3 "$HEALTH" >/dev/null; then
  echo "health check failed, rollback: kill $NEW" >&2
  kill -TERM "$NEW"
  exit 1
fi

# 4. 旧 master 优雅退出（TERM，等待 graceful_timeout）
kill -TERM "$OLD"
```

- 优点：
  - 全程 listen socket 不关，连接不拒；实测 14 万请求 0 错误（见第十一节）。
  - **能整体升级**：新 master 是新进程，可换 venv、gunicorn 版本、C 扩展，
    甚至换 Python 小版本。
  - **可回滚**：旧 master 活着时只需 `kill -TERM $NEW` 并让旧 master 继续服务。
- 缺点：
  - 并存期间内存翻倍（尤其 `--preload` 加载大模型时）。
  - 需要脚本 + pidfile 管理；健康检查打的是共用端口，新旧都在服务，
    可能命中旧实例——严格的方案要按 worker 探测。
  - 脚本写错（提前 `TERM` 旧 master）就会丢 in-flight 请求。

### 4.3 uvicorn `--workers` + `SIGHUP`

uvicorn 0.54 的 multiprocess supervisor 支持 `SIGHUP`：**逐个 worker
「先起新、就绪后再停旧」**，是官方说的 near-zero-downtime。

```bash
uvicorn app:app --workers 4 --port 8000 --timeout-graceful-shutdown 30
kill -HUP "$(pgrep -f 'uvicorn app:app' | head -1)"
```

- 优点：ASGI 原生，不用再套 gunicorn；单 worker 级别重叠，容量不塌。
- 缺点（本机实测）：
  - 仍有约 **0.002% 的连接重置**（12.6 万请求里 3 个），属于「near-zero」不是零。
  - 父进程不 reload 配置；换依赖/解释器仍要整进程重启。
  - 生产上更成熟的组合仍是 `gunicorn -k uvicorn.workers.UvicornWorker`。
- 适用：ASGI（FastAPI/Starlette）单机、能接受极小概率重置。

### 4.4 uWSGI / Hypercorn

- uWSGI 支持 `systemd` socket activation、worker 分阶段优雅退出
  （`--lazy`、`--die-on-term`、`--need-app` 等），功能最全但配置项也最多，
  新项目不建议再选。
- Hypercorn 支持 `--workers` 与优雅退出（`--graceful-timeout`），
  但没有 gunicorn `USR2` 那种新旧 master 并存机制，发布还得靠重启或蓝绿。

## 五、L2 双实例蓝绿 + nginx 切换（最通用）

思路：新版本在**另一个端口**起一套，健康检查通过后改 nginx upstream
（只指向新端口），`nginx -s reload` 是平滑的（旧 worker 处理完存量连接才退），
最后等旧实例连接 drain 完再停。

```nginx
# /etc/nginx/conf.d/myapp.conf
upstream myapp {
    server 127.0.0.1:8001;   # 只写当前版本
    keepalive 32;
}

server {
    listen 80;
    location / {
        proxy_pass http://myapp;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 30s;
    }
}
```

```bash
#!/usr/bin/env bash
set -euo pipefail
OLD_PORT=8001
NEW_PORT=8002
CONF=/etc/nginx/conf.d/myapp.conf

# 0. 新代码放到新目录（或直接切换软链）
cd /opt/myapp && git fetch -q && git reset --hard -q origin/main

# 1. 用专用 venv 起新实例
/opt/myapp/.venv/bin/gunicorn -w 4 -b 127.0.0.1:$NEW_PORT app:app \
    --pid /run/myapp-$NEW_PORT.pid --daemon

# 2. 健康检查（应用层，不是 TCP 探活）
for _ in $(seq 30); do
  curl -fsS "http://127.0.0.1:$NEW_PORT/healthz" >/dev/null && break
  sleep 1
done

# 3. 切流量
sed -i "s/server 127.0.0.1:$OLD_PORT;/server 127.0.0.1:$NEW_PORT;/" "$CONF"
nginx -t && nginx -s reload

# 4. drain：等旧实例上残留的 keepalive 连接自然结束
sleep 30
kill -TERM "$(cat /run/myapp-$OLD_PORT.pid)"
```

回滚就是反向执行一次（把 upstream 改回旧端口）。

- 优点：
  - 对应用零侵入，框架无关；能整体换 Python/依赖/系统库。
  - 回滚 = 改回一行配置，秒级；还能按权重做灰度（`server ... weight=1`）。
  - 与进程管理器特性解耦，不依赖 gunicorn/uvicorn 的信号语义。
- 缺点：
  - 要维护两套端口/venv 与部署脚本，内存翻倍。
  - upstream `keepalive` 会让旧实例在切换后继续服务一段时间，
    drain 时间要预估（`proxy_read_timeout` + keepalive 超时）。
  - 有状态的东西（会话、内存缓存、定时任务）要靠外部化解决。
- HAProxy 变体：用 `option httpchk` + runtime API 做更精细的 drain：
  `echo "set server myapp/s1 state maint" | socat stdio /var/run/haproxy.sock`。

## 六、L3 `SO_REUSEPORT` 多 master 同端口

Linux 允许给同一端口设置 `SO_REUSEPORT`，多个**独立进程**都能 bind，
内核按四元组哈希把连接分下来。gunicorn 从 19.8 起支持 `--reuse-port`。

```bash
# 蓝实例
gunicorn -w 2 -b 127.0.0.1:8000 --reuse-port app:app --pid /run/app-blue.pid
# 绿实例（同端口）
gunicorn -w 2 -b 127.0.0.1:8000 --reuse-port app:app --pid /run/app-green.pid
# 健康检查后停蓝
kill -TERM "$(cat /run/app-blue.pid)"
```

- 优点：不需要 nginx/HAProxy，同端口滚动，改造成本低。
- 缺点：
  - 内核哈希**不感知负载**，连接数会不均；长连接会一直粘在某个进程。
  - 旧进程退出时，它 accept 队列里的连接会断——需要自己控制 drain。
  - 日志、监控、pid 管理都要聚合；不熟练容易把进程数搞乱。
- 适用：没有前置代理、又不能停服的小服务。

## 七、L4 systemd socket activation

把「监听端口」这件事从进程里搬到 systemd：`myapp.socket` 持有 listen socket，
服务进程从 `LISTEN_FDS` 继承 fd。这样 `systemctl restart myapp` 时
**socket 始终不关闭**，重启窗口内进来的连接在内核 backlog 排队，
不会被拒；服务起来后直接消费这些连接。

gunicorn 原生支持（`gunicorn/systemd.py` 读 `LISTEN_FDS`/`LISTEN_PID`），
所以不用改代码，也不用写 `sd_notify` 包装。

```ini
# /etc/systemd/system/myapp.socket
[Unit]
Description=myapp listening socket

[Socket]
ListenStream=0.0.0.0:8000
Backlog=4096

[Install]
WantedBy=sockets.target
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=myapp
Requires=myapp.socket
After=network.target myapp.socket

[Service]
User=app
WorkingDirectory=/opt/myapp
# 注意：不要再写 -b/--bind，gunicorn 会用继承来的 fd
ExecStart=/opt/myapp/.venv/bin/gunicorn -w 4 app:app --graceful-timeout 30
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
TimeoutStopSec=40
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now myapp.socket myapp.service
systemctl restart myapp        # socket 不关，新连接只排队
```

- 优点：
  - 系统级能力，框架无关；`systemctl restart` 就完成「不拒连」的发布。
  - 只有一个进程组，资源不翻倍；gunicorn/uvicorn 都兼容这套 fd 继承。
- 缺点：
  - 仍然要处理 in-flight：`TimeoutStopSec` 必须 ≥ `graceful_timeout`，
    否则旧进程被 SIGKILL，存量请求直接断。
  - 监听地址从应用挪到 unit 文件，两处配置要同步；改端口要改 socket unit。
  - backlog 满了照样丢连接（`Backlog=` 与 `net.core.somaxconn` 取小值）。
  - 换依赖/解释器仍需要停服务（只是不停 socket）。
- 实测：`systemd-socket-activate -l 18090 -- gunicorn -w 2 app:app` 可直接继承
  fd 监听成功，gunicorn 26.2 无需额外参数。

## 八、L5 容器 / K8s 滚动更新

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # 先多起一个，容量不塌
      maxUnavailable: 0
  template:
    spec:
      terminationGracePeriodSeconds: 60
      containers:
        - name: app
          image: registry.example.com/myapp:1.2.3
          readinessProbe:            # 就绪才接流量
            httpGet: { path: /healthz, port: 8000 }
            periodSeconds: 5
          lifecycle:
            preStop:
              exec: { command: ["sleep", "10"] }   # 等端点摘除传播
```

- 优点：声明式、自动回滚、多机容灾、扩缩容一体；`maxUnavailable: 0` 保证容量。
- 缺点：
  - 重：要镜像、registry、集群；构建+拉镜像分钟级，不适合「改一行立刻生效」。
  - **`preStop` 缺失是 502 的主要来源**：端点摘除与进程退出有竞态，
    必须 `sleep` 到 kube-proxy/Ingress 更新完。
  - 有状态服务要 StatefulSet + 优雅迁移；本地缓存/内存队列都会丢。
- 适用：已容器化的中大型服务。

## 九、L6 进程内热补丁（字面零中断，但不建议上生产）

- `importlib.reload(module)`：重新执行模块顶层代码，但**旧对象仍指向旧类**，
  单例、类属性、闭包全部不一致。
- `jurigged` 之类做字节码级替换，能换函数体，但处理不了类结构、模块级状态、
  已注册的回调引用。
- 更常见也更安全的子集是**配置/模板/规则热加载**：只换数据不换代码，
  用 mtime 或信号触发重读，例如：

```python
import json, threading, os

_config, _mtime, _lock = {}, 0, threading.Lock()

def get_config():
    global _config, _mtime
    path = "/etc/myapp/config.json"
    m = os.stat(path).st_mtime
    if m != _mtime:
        with _lock:
            if m != _mtime:
                with open(path) as f:
                    _config = json.load(f)
                _mtime = m
    return _config
```

- 优点：字面零中断、不双份内存、连接不丢。
- 缺点：状态一致性几乎无法保证；不能原子回滚；调试/排查成本极高。
- 结论：`--reload`（gunicorn/uvicorn 的 dev reloader）和 `importlib.reload`
  只用于本地开发；生产只做「数据热加载」，代码走 L1/L2/L4/L5。

## 十、L7 架构级：把「要热更新的东西」移出进程

真正降低发布频率比优化发布更划算：

- Feature flag / 配置中心：开关、阈值、文案走外部配置，不发版。
- 插件化（`entry_points` + 版本化模块目录）：主进程不动，只加载新插件版本。
- 定时任务独立成 worker（Celery beat / cron 单实例），避免发布时多实例重复执行。

## 十一、实测数据

环境：Linux（24 核）、Python 3.14.7、gunicorn 26.2.0、uvicorn 0.54.0，
2~4 worker，16 并发短连接压测，发布动作夹在压测中间。

| 方案 | 请求数 | 错误数 | 代码是否生效 | 结论 |
| --- | --- | --- | --- | --- |
| gunicorn `HUP` | 123,793 | 0 | v1 → v2 | 零拒连、零错误 |
| gunicorn `USR2` + `TERM` 旧 master | 144,006 | 0 | v1 → v2 | 零错误，新旧并存期双版本 |
| gunicorn `--preload` + `HUP` | — | — | **仍是 v1** | HUP 不加载新代码（坑） |
| gunicorn `--preload` + `USR2` | — | — | v1/v2 混合 → `WINCH`/`TERM` 后全 v2 | USR2 生效 |
| uvicorn `--workers 2` + `SIGHUP` | 126,340 | **3**（1× RemoteDisconnected，2× ConnectionReset） | v1 → v2 | near-zero，非零 |
| gunicorn `--reuse-port` ×2 master | — | — | 两 master 同端口监听成功 | 可用，需自己编排 |

压测脚本见附录 A，可复现。

## 十二、对比总表

| 方案 | 新连接会拒吗 | in-flight 请求 | 能换依赖/解释器 | 峰值内存 | 落地成本 | 典型场景 |
| --- | --- | --- | --- | --- | --- | --- |
| L0 直接重启 | 会 | 全断 | 能 | 1x | 最低 | 内网工具 |
| L1a gunicorn `HUP` | 不会（短暂排队） | 优雅 | 不能 | 1x（瞬时容量最低） | 低 | 单机小服务 |
| L1b gunicorn `USR2`+`TERM` | 不会 | 优雅 | **能** | 2x（短时） | 中 | 单机推荐 |
| L1c uvicorn `SIGHUP` | 极小概率 RST | 优雅 | 不能 | 1x+1 | 低 | ASGI 单机 |
| L2 蓝绿 + nginx | 不会 | 优雅 | **能** | 2x | 中 | 有 nginx 的任意规模 |
| L3 `SO_REUSEPORT` | 旧进程退出时可能 RST | 需自己 drain | 能 | 2x | 中 | 无前置代理 |
| L4 systemd socket | 不会（排队） | 优雅 | 能 | 1x~2x | 低 | systemd 单机 |
| L5 K8s 滚动 | 不会 | 优雅 | 能 | Nx | 高 | 多机/已容器化 |
| L6 进程内热补丁 | 不会 | 不断 | 能（但不可靠） | 1x | 高（风险） | 开发/极端场景 |

## 十三、最容易踩的十个坑

1. **`--preload` 下 `HUP` 不换代码**：新 worker 从旧 master fork，内存里是旧模块。
2. **`WINCH` 只对 `--daemon` 有效**：systemd/前台运行必须用 `TERM` 停旧 master。
3. **新代码 import 失败没有回滚**：`HUP` 已杀旧 worker，master 还活着但全是 502。
   健康检查要打应用层（`/healthz` 里 import 业务模块），不能只探 TCP。
4. **keep-alive 连接被 RST**：进程退出瞬间，客户端复用的旧连接会断；
   要么让连接先过期，要么客户端重试（幂等）。
5. **backlog 不够**：`net.core.somaxconn` 与 `Backlog=` 取小值，突发流量仍丢 SYN。
6. **定时任务重复执行**：多实例发布期间 beat/consumer 会跑两份，需单实例或加锁。
7. **数据库 migration 不兼容**：新旧代码并存期间必须 expand-contract
   （先加列/双写 → 切读 → 再删旧字段）。
8. **本地缓存/限流/会话不同步**：多实例各自计数，切流量后行为跳变。
9. **WebSocket/SSE 长连接**：蓝绿切换会断，需要客户端重连 + 服务端 drain 窗口。
10. **nginx upstream keepalive 让旧实例延寿**：切换后旧进程还在处理连接，
    停太早会 502，停太晚浪费资源。

## 十四、选型建议

| 你的情况 | 选什么 | 理由 |
| --- | --- | --- |
| 单机 systemd + gunicorn，只改业务代码 | `HUP` 或 `USR2`+`TERM` 脚本 | 一条/十几行命令，实测 0 错误 |
| 要连 Python/依赖一起升级，还要能回滚 | `USR2`+`TERM` 或蓝绿 | 新 master 是新进程 / 新实例 |
| 不想写脚本，希望 `systemctl restart` 就安全 | systemd socket activation | socket 由 PID 1 持有，不拒连 |
| 已经有 nginx | 双端口蓝绿 + `nginx -s reload` | 最通用，能灰度、能秒级回滚 |
| 已容器化、多机 | K8s rolling update + readiness + preStop | 声明式、自动回滚 |
| 有 WebSocket 长连接 | 蓝绿 + 客户端重连 + drain | 进程级重载必然断连 |
| 生产环境 | **禁止** `--reload` / `importlib.reload` | 状态不一致且无法回滚 |

验证方法：发布动作和压测同时跑，盯错误率与 p99 延迟。

```bash
# 一个终端压测，另一个终端执行发布
hey -z 60s -c 50 http://127.0.0.1:8000/     # 或用附录 A 的无依赖脚本
```

## 附录 A：无依赖压测脚本

保存为 `loader.py`，发布时另开终端跑：

```python
import sys, time, threading, http.client, collections

port, duration, nthreads = int(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3])
stop = time.time() + duration
lock, total = threading.Lock(), [0]
ok, err = collections.Counter(), collections.Counter()

def worker():
    while time.time() < stop:
        conn = None
        try:
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
            conn.request("GET", "/")
            r = conn.getresponse()
            body = r.read().decode()
            with lock:
                total[0] += 1
                (ok if r.status == 200 else err)[
                    body if r.status == 200 else f"http{r.status}"] += 1
        except Exception as e:
            with lock:
                total[0] += 1
                err[type(e).__name__] += 1
        finally:
            if conn:
                conn.close()

ts = [threading.Thread(target=worker) for _ in range(nthreads)]
[t.start() for t in ts]
[t.join() for t in ts]
print(f"total={total[0]} responses={dict(ok)} errors={dict(err)}")
```

```bash
python3 loader.py 8000 15 16 &
# 然后执行发布命令，结束后看 errors 是否为空
```

## 版本记录

| 版本 | 日期 | 使用模型 | 说明 |
| --- | --- | --- | --- |
| v1 | 2026-11-09 | deepseek-flash（DSH） | 初稿，含本机实测数据 |

本次消耗：输出约 7.8 万 tokens，定稿时上下文约 9.3 万 tokens
（其中约 9.2 万命中缓存；数据为 DSH 会话 `usage` 字段汇总）。
