# DSH 启动失败：一个 0 字节锁文件把服务锁死

> 现场：一台 899 MB 的云服务器上常驻 `dsh web`，某次重启后服务无限重启，
> 日志里每 45 秒一轮 `startup failed`。根因不是配置、不是插件，而是一个
> **0 字节的 `<file>.lock` 文件**。这篇记下完整的因果链、最小复现和两种修法。

## 一、症状

`systemctl status dsh-web` 一直停在 `activating`，`journalctl` 里稳定循环：

```
dsh: startup failed: 1 required plugin did not activate
Failed plugins (1):
  connection (required)
    Package: @deepseek-ai/dsh-client-connection
    Error: atomic-write: timed out waiting for the writer lock at
           /home/<user>/.dsh/.credentials.yaml.lock
Plugins waiting for services (6):
  session-log-download  connection
  open-in-app           connection
  ...
```

几个容易带偏的观察：

- 报错插件是 `connection`，但 `connection` 自己没问题——它只是第一个需要
  **写** `.credentials.yaml` 的插件（登录时写 `client-connection/browser-session`
  的 grant 记录），也是第一个倒下的。
- 后面那 6 个 `waiting for services` 是**连锁反应**，别去修它们。
- `systemd` 的 `Restart=always` 会每 5 秒拉起一次，于是看起来像"忙碌重启"，
  实际每轮都死在同一个地方。

## 二、根因：锁协议只认「完整的 PID 记录」

`@deepseek-ai/dsh-atomic-write`（0.2.2 起）用 `<file>.lock` 兄弟文件做跨进程写锁：

- 锁文件内容 = 持有者 PID，写入方式是 `open(path, "wx")` + `write("<pid>\n")`；
- 拿不到锁时先看**记录**：记录是 `<pid>\n` 且 `kill(pid, 0)` 返回 `ESRCH`
  （进程已不存在）→ 用 claim 文件协议接管，删锁重试；
- 其余情况一律**等待**，超时后抛 `timed out waiting for the writer lock`。

关键在最后一条：**记录不完整**（空文件、写了半截、被截断）时，
`holderExited()` 解析不出 PID，永远返回 `false`，于是"等待"变成"死等"。
上游的注释写得很明确：

> any other lock, including one whose holder exists under another user (`EPERM`)
> or whose record is incomplete, is waited for.

这个保守选择本身有道理（保护"刚 `wx` 创建、还没写 PID"的微秒级窗口），
但没考虑**进程在窗口里被 SIGKILL** 的情况。

## 三、空锁是怎么来的

`open("wx")` 成功、`write(pid)` 还没落地时进程被杀 → 留下 0 字节锁文件。
在内存紧张的机器上这并不罕见：OOM killer 会挑占用最大的进程杀，常驻的
`dsh web` 正在其中（实测峰值 RSS 560 MB / 整机 899 MB，另有 1 GB swap），
而且 `systemd` 的 `Restart=always` 会立刻把新进程拉起来——新进程第一件事
就是写凭据文件，正好撞上那个空锁。

本案的时间线（教训：**空锁是升级冒烟时留下的**）：

| 时间 | 事件 |
|---|---|
| 11-12 11:47 | 跑升级脚本，冒烟实例（临时端口）启动后期被杀，留下 0 字节锁；冒烟日志为空 |
| 11-12 ~ 11-50 | 生产实例一直在跑，从未重启 → 没人需要写那个文件 → 问题潜伏 |
| 11-13 10:44 | 因缓存/OOM 调优重启服务，第一次撞上空锁 → 进入 45 秒一轮的重启循环 |
| 11-13 10:53 | 删锁 + 重启，20 秒起来；随后打补丁防复发 |

## 四、最小复现（4 条用例，5 秒）

不用起整个 DSH，直接调用锁模块。四条用例覆盖"该接管"和"不该接管"两侧：

```js
import { withFileLock } from '<node_modules>/@deepseek-ai/dsh-atomic-write/lib/index.js';
import { writeFileSync, utimesSync } from 'node:fs';

const target = '/tmp/lock-demo/x.yaml';
writeFileSync(target + '.lock', '');                     // 模拟被杀留下的空锁
const old = Date.now() / 1000 - 120;
utimesSync(target + '.lock', old, old);                  // 两分钟没动过

await withFileLock(target, () => 'ok', { waitMs: 1000 }); // 补丁前：抛 timeout
```

| 用例 | 锁文件内容 | 修改时间 | 期望 |
|---|---|---|---|
| 空锁 + 陈旧 | 空 | 2 分钟前 | 接管（补丁前 **TIMEOUT**，即事故现场） |
| 空锁 + 新鲜 | 空 | 刚刚 | 继续等（保护 open→write 窗口） |
| 活着的 PID | `<pid>\n` | 2 分钟前 | 继续等 |
| 已退出的 PID | `<pid>\n` | 2 分钟前 | 接管（上游原有能力） |

补丁前后各跑一遍，第一条会从 `TIMEOUT` 变 `ACQUIRED`，其余三条不变——
这就是「一个能变红的回归测试」。

## 五、修复

### 5.1 当场：删锁重启

```bash
cp -p ~/.dsh/.credentials.yaml.lock /tmp/ 2>/dev/null || true
rm -f ~/.dsh/.credentials.yaml.lock
sudo systemctl restart dsh-web
```

判活看日志出现 `dsh web: http://127.0.0.1:<port>/?token=…`（约 20 秒）。
直连端口返回 401 是正常基线（认证门在外层 nginx）。

### 5.2 防复发：让"陈旧空锁"可被接管

给锁模块打一个小补丁：**记录不完整 + 锁文件静默 ≥60 秒** 时视为遗留锁，
沿用上游已有的 claim 文件协议接管。

```js
// 记录里是合法 PID 就完全按原语义走；只有解析不出 PID 时才看静默时长
async function holderGone(lockPath, record) {
	if (holderExited(record)) return true;            // 原能力：PID 已死
	if (/^\d+\n$/.test(record)) return false;         // PID 还活着 → 继续等
	const info = await stat(lockPath);                // 记录不完整 → 看静默时长
	return Date.now() - info.mtimeMs >= INCOMPLETE_LOCK_GRACE_MS; // 6e4
}
```

补丁点是 `takeOverExitedLock()` 里两处 `!holderExited(record)` → `!await holderGone(...)`。
60 秒这个数不是拍的：`open("wx")` 到 `write(pid)` 之间只有微秒级代码，
一个静默一分钟的锁不可能还属于"正在写 PID"的活进程；而真正在用锁的进程，
其记录是完整的，走的是原来那条"继续等"分支。

同理，这个补丁**不会**帮助"PID 被复用"的场景（上游也明确不处理），
那是另一个运维问题。

### 5.3 别让它再产生：内存与重启策略

SIGKILL 多来自 OOM。如果机器小，给 DSH 加 systemd drop-in：

```ini
[Service]
OOMScoreAdjust=500     # 内存吃紧时优先杀 dsh 而不是 sshd/nginx
MemoryHigh=700M        # 先触发回收，而不是直接 OOM
Restart=always         # 被杀后自动拉起
```

注意 `MemoryHigh` 通常低于整机可用内存，要给系统留余量；配完重启一次看
`systemctl status` 的 `Memory:` 行是否稳定在阈值以下。

### 5.4 补丁会被升级冲掉

`npm install @deepseek-ai/dsh@<ver>` 会覆盖 `lib/index.js`，所以：

- 把打补丁写成**幂等脚本**（marker 检查 + `--check` 只查 + `*.bak` 备份）；
- 装进升级流程（一条命令升级脚本里加一步"重打补丁"），别靠记忆；
- 升级后跑一次自测脚本，`ALL PASS` 才算过。

## 六、可迁移的检查清单

遇到"服务起不来 + 某个 lock 文件超时"这类症状时，按这个顺序走：

1. `stat <lock>`：**0 字节**就是拿到线索了；有数字 × 1000 万以上的 PID 说明是历史遗留；
2. `lsof`/`fuser` 确认没有任何进程持有它（排除"真有人在用"）；
3. 看锁文件里的 PID 是否还存在（`kill -0 <pid>`），在别的 PID namespace 里也可能误判；
4. 别急着删业务数据文件——先删锁、重启、看是否恢复，**先恢复再定位**；
5. 定位到"进程被杀留下空锁"后，补的不是锁文件，而是**产生锁的那条路径**：
   OOM 调优 + 升级流程自动化 + 回归测试。

## 参考

- 锁协议实现：`@deepseek-ai/dsh-atomic-write` 的 `withFileLock` / `takeOverExitedLock`
  （`lib/index.js`，注释里写明了"记录不完整一律等待"的设计取舍）
- 相关笔记：[DSH 安装指南](./dsh-install-guide.md)、[DSH 内网部署实践](./dsh-intranet/README.md)

## 版本记录

- v1（2026-11-13）：初版。使用模型：DeepSeek Harness（deepseek-flash）。
  本次消耗：input 6.1 万 tokens、output 4.7 万 tokens、cache 读 527.2 万 tokens，
  合计约 538 万 tokens。
