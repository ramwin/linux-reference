# 把 DSH 暴露到公网：中转反代 vs frp 隧道

```{contents}
```

家里没有 80/443、或者干脆没有公网 IP，但想在手机/公司电脑上用 `dsh web` 的 GUI。
本文给两条已经跑顺的路子，以及踩过的坑（其中 nginx 那个坑能让你排查一下午）。

## 结论先行

| 问题 | 结论 |
|---|---|
| 家里有可解析域名（DDNS 也算） | **方案 A：中转机 nginx 反代** + 家里自签证书做 pin |
| 家里只能出站、不想暴露端口 | **方案 B：frp stcp 隧道**，visitor 绑中转机回环，nginx 直接反代 `127.0.0.1` |
| DSH 必需参数 | `--host 127.0.0.1 --trusted-host <公网域名>`，两个都不能省 |
| 链接想"重启不变" | 固定 launch token（`~/.dsh/launch-token` + 给 `processLaunchToken()` 打补丁） |
| nginx Basic 认证密码文件 | 只能用 `openssl passwd -apr1`，**别用 `-6`（sha512crypt）** |

## 三种角色的位置关系

```
浏览器 ──https──► 中转机（有 80/443 + 证书 + nginx + Basic 认证）
                    │
                    ├─ 方案 A：https + 证书 pin ──► 家里机器 3090（自签证书）
                    └─ 方案 B：http://127.0.0.1:3080 ──► frpc visitor ──► frps:7000
                                                                        ▲
                                                      家里 frpc（stcp server，只出站）
                                                        │  http://127.0.0.1:3080
                                                        ▼
                                                    dsh web --trusted-host <域名>
```

一台机器一套入口，互不干扰；同一台中转机上可以用不同子域名挂多台机器（各自一份 vhost，
各自一份 htpasswd 或共用一个）。

## 方案 A：中转反代 + 自签证书 pin

家里那台在 3090 起 nginx 终止内层 TLS，中转机反代时**校验家里那张自签证书**，
即使家里的公网 IP 变、DNS 被污染，中间人也没法冒充：

```nginx
server {
    listen 443 ssl http2;
    server_name dsh.example.com;

    ssl_certificate     /etc/letsencrypt/live/dsh.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dsh.example.com/privkey.pem;

    auth_basic           "DSH restricted";
    auth_basic_user_file /etc/nginx/dsh.htpasswd;

    location / {
        # 家宽 IP 会漂：走域名让 nginx 定期重新解析
        resolver 223.5.5.5 119.29.29.29 valid=60s ipv6=off;
        set $upstream home.example.com:3090;
        proxy_pass https://$upstream;
        proxy_http_version 1.1;

        proxy_ssl_server_name         on;
        proxy_ssl_name                dsh.example.com;
        proxy_ssl_verify              on;
        proxy_ssl_trusted_certificate /etc/nginx/ssl/home-internal.crt;
        proxy_ssl_verify_depth        2;

        # Host 必须等于浏览器地址栏的 host，见下文「trusted-host」
        proxy_set_header Host            dsh.example.com;
        proxy_set_header X-Real-IP       $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade         $http_upgrade;
        proxy_set_header Connection      $connection_upgrade;

        # Basic 凭据不往家里传
        proxy_set_header Authorization "";

        # DSH 响应是流式的（SSE/websocket），必须关缓冲
        proxy_buffering         off;
        proxy_request_buffering off;
        proxy_read_timeout      3600s;
        proxy_send_timeout      3600s;
    }
}
```

还有一条 80 端口：`/.well-known/acme-challenge/` 交给 certbot，其余 308 跳 https。

## 方案 B：frp stcp 隧道

适合"家里只能出站"的机器。要点是 **stcp 的 server 端在家里、visitor 端在中转机**，
visitor 把 `127.0.0.1:3080` 当上游，nginx 因此看不到任何跨公网的转发细节。

家里 `frpc.ini`（frps 在中转机 `relay.example.com:7000`）：

```ini
[common]
server_addr = relay.example.com
server_port = 7000
login_fail_exit = false

[dsh_home]
type = stcp
local_ip = 127.0.0.1
local_port = 3080
sk = <32字节以上随机串>          # stcp 的共享密钥，泄露等于门被拆
use_encryption = true
```

中转机 `frpc-visitor.ini`（frps 在本机，所以 `server_addr` 是回环）：

```ini
[common]
server_addr = 127.0.0.1
server_port = 7000
login_fail_exit = false

[dsh_home_visitor]
role = visitor
type = stcp
server_name = dsh_home
sk = <与上面一致>
bind_addr = 127.0.0.1
bind_port = 3080
use_encryption = true
```

vhost 只要把 `proxy_pass` 换成 `http://127.0.0.1:3080` 即可，其余与方案 A 相同。
两个 frpc 都做成常驻（supervisor / systemd），`Restart=always`。

自测技巧：visitor 和 nginx 在同一台机器，所以可以在中转机上直接问隧道通不通 ——

```bash
curl -H 'Host: dsh.example.com' http://127.0.0.1:3080/
# DSH 回 401 说明隧道是好的，只是没带 token；回 502 才是隧道/家里进程的问题
```

## DSH 侧的两个硬要求

```bash
dsh web --host 127.0.0.1 --port 3080 --trusted-host dsh.example.com --no-open
```

- `--trusted-host`：DSH 对 `/api` 有 Host 围栏，不挂这个参数时公网域名访问 `/api` 一律 403
  （页面能打开、看起来像"白屏/加载不出来"）。只放行你要的那一个域名，别放宽。
- `--host 127.0.0.1`：DSH 只监听回环，外面由 nginx / frp 接管，3077/3080 不裸奔。

登录流程：无 token → 401；带 `?token=<43 字符>` 且正确 → 303 + 下发 `dsh-auth-*`
HttpOnly 签名 cookie（默认 30 天），之后直接用域名访问即可。

## 让链接"重启不变"：固定 launch token

默认每次 `dsh web` 启动都会随机生成 launch token，重启一次，之前收藏的链接就失效了。
补丁思路：给 `@deepseek-ai/dsh-client-connection` 的 `processLaunchToken()` 加一段前置逻辑 ——
先读 `DSH_LAUNCH_TOKEN` 环境变量，再读 `~/.dsh/launch-token`，值合法（32 字节 base64url，
43 字符）就采用，否则回退随机。这样不用改 systemd unit、不用 root。

```bash
TOKEN=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')  # 43 字符
printf '%s' "$TOKEN" > ~/.dsh/launch-token && chmod 600 ~/.dsh/launch-token
```

脚本要做的就是在 `lib/index.js` 里插两处锚点（import、函数首部），用 marker
（如 `dsh-fixed-launch-token`）保证幂等，并在改完后跑 `node --check` 校验语法、
把原文件备份成 `index.js.bak-launch-token`。

注意事项：

- **`npm i -g @deepseek-ai/dsh@新版本` 会覆盖 `lib/index.js`，补丁被冲掉** —— 升级后重跑脚本再重启。
- 补丁只在**下次进程启动**时生效，当前进程的 token 不会变。
- 找不到 patch 脚本时，从启动日志里捞当次 token 也能救急：
  `grep -o 'token=[A-Za-z0-9_-]\{43\}' ~/.dsh/dsh-web.log | tail -1`

## 第一道门：cookie 门 + Basic 认证

只用 `auth_basic` 会让浏览器在每个新会话都问一次密码；常见做法是"Basic 通过一次，
换一个一年期 cookie"，之后靠 cookie 走，配合 DSH 自己的 token cookie 共三道门：

```nginx
map $cookie_dsh_pass $dsh_pass_ok {
    default 0;
    "<cookie 的固定值，随机 hex>" 1;
}

location / {
    error_page 418 = @dsh_gate;
    if ($dsh_pass_ok = 0) { return 418; }     # 没 cookie 就进 Basic 门
    proxy_pass http://127.0.0.1:3080;
    include snippets/dsh-proxy.inc;
}

location @dsh_gate {
    auth_basic           "DSH restricted";
    auth_basic_user_file /etc/nginx/dsh.htpasswd;
    add_header Set-Cookie "dsh_pass=<同一个随机 hex>; Path=/; Max-Age=31536000; HttpOnly; Secure; SameSite=Lax";
    proxy_pass http://127.0.0.1:3080$request_uri;
    include snippets/dsh-proxy.inc;
}
```

## 坑：htpasswd 用了 sha512crypt，nginx 校验不了

**症状**：新浏览器/新电脑打开链接一直 401；而原来的浏览器（带着旧 cookie）照常能用，
于是表现成"有时能用、有时不能用"，很容易误判成 DSH 或隧道的问题。
中转机 `error_log` 里是：

```
user "dsh": password mismatch
```

**根因**：`/etc/nginx/dsh.htpasswd` 里的哈希是 `openssl passwd -6` 生成的
sha512crypt（`$6$...`）。nginx 的 `auth_basic` 只支持 `$apr1$`、`{SHA}`、
DES-crypt（13 字符）和明文，**`$6$` 这一类它验不了**，于是所有走到 Basic 门的人全部 401。
（同一批文件里如果是 `$apr1$`，就一直正常 —— 这也是为什么"另一套站点没事"。）

**修法**：

```bash
# 备份 → 用 apr1 重写 → 校验并 reload
sudo cp -a /etc/nginx/dsh.htpasswd /etc/nginx/dsh.htpasswd.bak-$(date +%Y%m%d)
printf 'dsh:%s\n' "$(openssl passwd -apr1 '新密码')" | sudo tee /etc/nginx/dsh.htpasswd
sudo chown root:www-data /etc/nginx/dsh.htpasswd && sudo chmod 640 /etc/nginx/dsh.htpasswd
sudo nginx -t && sudo systemctl reload nginx
```

**验证必须用无 cookie 的 curl**，用浏览器抽检会被旧 cookie 骗过：

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -u 'dsh:新密码' https://dsh.example.com/
# 期望 200（或带 token 的 303）；401 = 还没对
```

顺带记两条：`htpasswd -B`（bcrypt `$2y$`）同样不行；改完一定要看 `error_log` 里的
`password mismatch` 有没有消失，这是最快的确认信号。

## 排查清单

| 现象 | 先看什么 | 命令 |
|---|---|---|
| 新浏览器 401，老浏览器能用 | htpasswd 格式 / error_log | `curl -u 用户:密码` 裸测 + `tail /var/log/nginx/xxx-error.log` |
| 401 且日志 `password mismatch` | 哈希不是 `$apr1$` | 见上一节 |
| 502 / 504 | 隧道或家里 DSH 进程 | 中转机 `curl -H 'Host: <域名>' http://127.0.0.1:3080/` |
| 页面能开但白屏、控制台 `/api` 403 | `--trusted-host` 没加或写错 | 看进程命令行 `ps aux \| grep 'dsh web'` |
| 带 token 也 401 | token 属于旧进程世代 | 从 `dsh-web.log` / journal 取当前 token |
| 换手机/换网络连不上 | DNS 缓存、证书过期 | `getent hosts <域名>`；`openssl s_client -connect <域名>:443 -servername <域名> \| openssl x509 -noout -enddate` |
| 登录后一会儿掉线 | Host 头与地址栏不一致（Origin 围栏） | nginx `proxy_set_header Host` 必须是浏览器域名 |

## `--public-url` 管"广告"，`--trusted-host` 管"信任"

`dsh web --help` 里和公网相关的三个参数，职责别混：

| 参数 | 作用 | 影响鉴权？ |
|---|---|---|
| `--public-url <url>` | 把打印的 URL、自动打开的 URL、`DSH_WEB_URL` 环境变量、模型运行时上下文里的"GUI URL"都换成这个根。帮助文本原话是 **grants no trust** | 否 |
| `--trusted-host <authority>` | 给 `/api` 的 Host/Origin 围栏额外放行一个 authority；不加则公网域名访问 `/api` 一律 403（页面能开、看着像白屏） | 是 |
| `--tls-cert` / `--tls-key` | DSH 自己终结 TLS。读一次固定文件，不续期、不做 80→443 跳转、不发 HSTS | 否 |

只挂 `--trusted-host`、不挂 `--public-url` 的后果：启动日志打印的是
`http://127.0.0.1:3080/?token=...`，`DSH_WEB_URL` 也是它，模型在回答里贴"GUI 地址"
时贴出来的就是回环地址——用户点不开。所以反代部署建议两个都挂：

```ini
ExecStart=/home/<user>/node_modules/.bin/dsh web --port 3080 --no-open \
  --trusted-host dsh.example.com \
  --public-url https://dsh.example.com/
```

两个注意点：

- 生效要重启进程；但 cookie 签名密钥是**持久化**在 credential provider 里的，
  浏览器已有 cookie 重启后照常可用（固定 launch token 同理），不用重新登录。
- 打印 URL 从 `http://127.0.0.1:...` 变成 https 之后，那种"从 journal 里 grep
  `http://127.0.0.1:3080/?token=`"的救急脚本会失配，改成 grep
  `token=[A-Za-z0-9_-]\{43\}` 即可。

## 能不能不挂 nginx、直接裸跑公网

技术上能：`--host <公网 IP> --tls-cert/--tls-key --trusted-host <域名>` 就够跑起来。
但把两边逐项摊开看，反代赢在"它替 DSH 做了 DSH 不打算做的事"：

| 维度 | nginx 前置 | `dsh web` 裸跑 |
|---|---|---|
| TLS / 证书续期 | certbot 续期 + reload，成熟 | 只吃静态 PEM，不续期，到期即挂；无 HSTS、无 80→443 跳转 |
| HTTP/2 | `listen 443 ssl http2`，多路复用 | Node `https` 只有 HTTP/1.1，页面要并行拉 index/2×JS/2×CSS/2×插件 combo，全挤在 6 条连接里 |
| 静态资源缓存头 | 可以按 location 注入 `immutable`（DSH 自己写死 `no-cache`） | 无配置项。`dsh-host-frontend-static` 源码里就是 `no-cache` + 弱 ETag，0.2.2-rc.2 也一样 |
| 鉴权纵深 | Basic/cookie 门 + DSH token/cookie 两层 | 只剩 DSH 一层（token + 签名 cookie + Host 围栏） |
| 限流 / 防爆破 / 连接数 | `limit_req` / `limit_conn` 可用 | 没有 |
| 日志审计 | access_log 带 UA、字节数、状态码，可直接算首屏字节 | 只有 journald 里的应用日志 |
| 额外开销 | nginx worker 实测 4.7 MB RSS | 0 |
| 防护面 | 可接 fail2ban / WAF / IP 白名单 | 全暴露给 Node，没有这些钩子 |

**结论**：单人自用、且愿意自己续证书、且不要静态长缓存，裸跑也能活；否则维持
nginx 前置。真正"贵"的那项是缓存头——裸跑等于放弃第 1 档优化（见下节），
这一条就足够否掉裸跑。

## 有没有 debug / release 两种模式

没有。三条证据：

- npm 包全量 grep，唯一读 `NODE_ENV` 的是 `@deepseek-ai/dsh-experimental-liveshare`；
  `dsh web --help` 也没有 `--dev` / `--debug` / `--prod` 之类的开关，只有
  `--host/--port/--no-open/--public-url/--trusted-host/--tls-*`。
- 装进 `node_modules` 的是 Vite 预构建产物：JS 压缩，`dist` 里 **0 个 `.map`**。
  所以线上永远是同一个 release 形态，不存在"生产模式少打日志/关断言"那种差异。
- 唯一的"开发形态"是源码 checkout + `pnpm run dev:web`：Vite dev server 负责外壳，
  客户端插件由 watcher 重建，`dsh-client-hmr` 每 500 ms stat 一次 rev，变了通过
  `/plugins/events` 推给浏览器热替换。用 npm 包跑时这条链路常驻但空闲（无变化不推送）。

排障只有 `journalctl -u <unit> -f` 和 `dsh --profile web --dump-config`，没有
"打开 debug 就多打日志"的开关。所以"线上出问题想开 debug"这条路本身不存在，
要靠复现 + `--dump-config` 对比配置。

## 想更稳、少刷新、缓存更省、CPU/内存更低：可动项盘点

先给实测基线（2 vCPU / 899 MB 阿里云小机，2026-11-13）：

| 指标 | 实测 |
|---|---|
| 冷加载（全量） | **4.3 MB**（gzip 后）：index 7 KB + 外壳 JS 543 KB + CSS 29 KB + 插件 combo 3.7 MB；原始 14.8 MB |
| 已缓存后的整页重载 | index 7 KB + 4 个 `/assets/` 条件请求（全 304，零字节） |
| node 进程 RSS | 386–399 MB（约占整机 43%） |
| nginx worker RSS | 4.7 MB |
| 970 KB 的 JS gzip 一次 | 30–37 ms CPU |
| 命中 ETag 的 304 | 5–10 ms（本机回环；移动端还要加 1 个 RTT） |
| 插件 combo 缓存头 | 已是 `public, max-age=31536000, immutable`（对的） |
| `/assets/` 缓存头 | `no-cache` + 弱 ETag（每次重载 4 个条件请求的来源） |

按"收益/风险"分档：

| 档 | 动作 | 需要 | 收益 | 风险 |
|---|---|---|---|---|
| 1 | nginx 给 `location ^~ /assets/` 注入 `immutable` | root + reload nginx，**不重启 dsh** | 每次重载少 4 个条件请求（移动端约省 1–4 个 RTT）；缓存被清时少下 470 KB；node 不再参与已缓存资源 | 极低（文件名带内容 hash） |
| 2 | 补 `--public-url` | 重启 dsh | 日志 / `DSH_WEB_URL` / 模型上下文里的 URL 变正确 | 低 |
| 3 | 给 OOM 定优先级（`OOMScoreAdjust` / `MemoryHigh`） | root + 重启 | 内存打满时先杀 dsh 并自动拉起，而不是连带 sshd/nginx 一起没 | 低 |
| 4 | 砍掉不用的 client 模块 | 改 profile | 首屏 combo 3.7 MB 按比例下降，浏览器解析内存也降 | 中（要试） |
| 5 | 让 nginx 直接 serve `/assets/`（绕过 node） | root | 冷加载省掉 node 的 gzip CPU | 中：路径耦合包目录 |
| — | 关 gzip / 关 HTTP/2 / 改裸跑 | — | 负收益 | 不做 |

### 一条命令做完（手机上 sudo 跑）

上面五档真正要动手的是前三档，已经收进一个幂等脚本，SSH 上去一条命令：

```bash
bash ~/dsh-www-tuneup.sh --dry-run     # 先看会改什么（不需要 root）
sudo bash ~/dsh-www-tuneup.sh          # 应用：nginx 长缓存 → public-url → OOM drop-in
sudo bash ~/dsh-www-tuneup.sh --revert # 全部撤销
```

脚本行为：

- 三步幂等，第二次跑全是「跳过」；只有真有改动才重启 dsh（2、3 步合并成一次）。
- nginx 块用 `# >>> dsh-tuneup` 标记包住，`nginx -t` 失败自动回滚；
  unit 改动前备份成 `*.bak-tuneup-<时间戳>`；drop-in 单独一个 `tuneup.conf`，不碰别的覆盖。
- 跑完自带验证：资源响应只有一行 Cache-Control 且含 immutable；启动日志里出现
  `dsh web: https://<域名>/?token=...`；cgroup 的 `OOMScoreAdjust`/`MemoryHigh` 已生效；
  最后打印一个可直接点的登录链接。
- `--no-restart` 只改文件，等你挑时间 `systemctl restart dsh-www`（重启会掐断正在跑的
  会话，cookie 持久化所以不用重新登录）。
- `/etc/nginx` 是 git 仓，脚本不替你 commit：`cd /etc/nginx && sudo git diff` 看过再提交。

**第 1 档的坑（实测，别踩）**：`add_header Cache-Control ...` 只是**追加**，nginx 会把
上游的 `cache-control: no-cache` 一并透传。响应变成两行，浏览器按 `no-cache` 处理，
immutable 白加。用临时 nginx 实例验证过：

```text
# 只 add_header
cache-control: no-cache
Cache-Control: public, max-age=31536000, immutable
# 加一行 proxy_hide_header Cache-Control 之后
Cache-Control: public, max-age=31536000, immutable
```

所以块里必须先 `proxy_hide_header Cache-Control;` 再 `add_header`；另外 `add_header`
不跨 location 继承，复刻 cookie 门时要连 HSTS / nosniff / Referrer-Policy 一起写上。
判定标准就一条：`curl -I` 之后**只有一行** Cache-Control。

**第 3 档**的 systemd drop-in：

```bash
sudo systemctl edit dsh-www.service
# [Service]
# OOMScoreAdjust=500
# MemoryHigh=700M
```

`OOMScoreAdjust` 为正数 = 更易被杀（内核优先杀 dsh 而不是 sshd），`MemoryHigh` 触发
回收而不是直接 OOM。`MemoryMax` 是硬上限、到点直接杀 cgroup 里的进程——想硬隔离可以设，
但要配合 `Restart=always` 并留够余量（比如 800M），否则正常峰值也会被杀。

**第 4 档**的数据支撑：3.7 MB gzip 的 combo 由 80 个 client 模块组成，纯 UI 插件是
大头；每砍一个，`/plugins/??` 组合 URL 里就少一个 `client.js`。要按"我一周没用过"
来量，别一次砍一片。

最后一句实话：手机端"整页重载"的根因是**页面体积 + HyperOS 回收渲染进程**，
缓存头只能让重载变便宜，不能阻止重载。想阻止只有两条：瘦身（第 4 档），或者把页面
装成 PWA——`manifest.webmanifest` 里 `display: standalone`，Chrome 里"添加到主屏幕"
后是独立窗口，比标签页抗回收（小米浏览器对 PWA 支持一般，能换 Chrome 再试）。

## 版本记录

| 版本 | 日期 | 内容 | 使用模型 | 本次消耗 |
|---|---|---|---|---|
| v1 | 2026-11-12 | 首版：两种暴露拓扑、固定 token、cookie 门 + Basic、sha512crypt 坑位与排查表 | deepseek-flash | 输入 5.0 万 / 输出 4.4 万 token，cache 读 443 万，约 ¥0.63（cost-meter，写入时统计） |
| v2 | 2026-11-13 | 增：`--public-url` 与 `--trusted-host` 分工、裸跑 vs 反代逐项对比、有无 debug/release 模式、缓存/CPU/内存分档优化（含 nginx `add_header` 追加导致 immutable 失效的实测坑） | deepseek-flash | 输入 8.6 万 / 输出 6.4 万 token，cache 读 595 万（cost-meter 口径） |
| v3 | 2026-11-13 | 增：一键脚本 `~/dsh-www-tuneup.sh`（幂等、dry-run、自动回滚、`--revert`、自带验证） | deepseek-flash | 输入缓存读为主，本会话累计 610 万 token（cost-meter 口径） |
