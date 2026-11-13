# DSH Web 在手机浏览器里「频繁强制刷新」的排查

> 现象：用小米浏览器打开 `https://dsh.www.ramwin.com`（家里这台 aliyun 上的
> `dsh web` 实例），用着用着**整页闪一下回到加载态**——是整页重载（重新下发
> index.html、重新下载并解析全部 JS），不是前端局部重渲染。

结论先说：**重载是浏览器发起的，DSH 前端自己不会刷新**；而之所以偏偏是这个
页面被反复重载，是因为它一次首屏要吃掉约 7 MB 网络传输 / 约 15 MB 未压缩 JS，
且空闲时仍以 ~2 req/s 空转——在 HyperOS 的 MIUI 浏览器里，这种重页面很容易被
系统回收，恢复标签页等于再整页加载一次，于是「越用越刷」。

## 一、先证明：不是 DSH 自己刷的

排查手段：对 `node_modules/@deepseek-ai/*/lib/client.js`（71 个官方客户端包）
和 `~/.dsh/profiles/web/node_modules/*`（56 个已装插件的客户端 bundle）全量 grep：

```bash
grep -rIn "location\.reload\|location\.replace\|location\.assign\|location\.href *=" \
  --include=*.js ~/node_modules/@deepseek-ai ~/.dsh/profiles/web/node_modules
```

结果：

| 命中 | 说明 |
|---|---|
| `dshmarket/client/client.js` 7 处 `location.reload()` | 插件市场「安装后/换主题/应用恢复」的**用户点击**触发，无自动调用 |
| `dshmarket/lib/recovery.js` 1 处 | 恢复页里点「应用」后的轮询，等宿主重启完才 reload |
| xterm 里 2 处 `location.href=` | 终端里点链接，和页面刷新无关 |

另外：**没有 service worker**（全仓无 `navigator.serviceWorker` 命中），
所以也不存在「SW 更新导致 reload」。DSH 是纯 SPA + WebSocket/SSE，
重载只能来自浏览器。

## 二、nginx 访问日志里的事实

日志：`/var/log/nginx/dsh-www-access.log`（站点 `dsh.www.ramwin.com`，
反代 `127.0.0.1:3081`，`dsh-www.service`）。统计窗口 11/11 00:52 → 12/11 09:27。

手机 UA：`XiaoMi/MiuiBrowser/20.30.1041104`，Android 16，机型 2410DPN6CC。

| 指标 | 实测值 |
|---|---|
| 整页重载（`GET /` 200 + 全套 assets） | 手机 UA **32 次**，桌面模式 UA 5 次 |
| 11/11 14:27–14:30 三分半内 | **6 次**（14:27:42 / 14:28:14 / 14:28:53 / **14:28:59** / 14:29:54 / 14:30:30），最短间隔 6 秒 |
| 12/11 07:31–09:26 约两小时 | **10 次** |
| 每次重载前的空闲间隔 | 0–7 秒（前一刻仍在正常轮询） |
| 重载前是否有 4xx/5xx | 没有；18 个 502 全部落在 11/11 10:13–10:14，对应服务 10:21 重启，与重载无关 |
| 最近 12 次重载里伴随出口 IP 变化的 | 只有 2 次（58.247→223.160、223.160→124.70） |

两条读法：

1. **不是「切后台回来被恢复」**。手机浏览器切后台会把定时器节流，轮询会先停，
   恢复时重载前面应该有几十秒到几分钟的空窗；实测是「0–7 秒前还在正常打请求」，
   说明是在**前台用着的时候被重载的**。
2. **网络/VPN 切换不是主因**。出口 IP 变来变去（58.247 / 223.160 / 116.229 /
   124.70，看得出手机在走代理），但 12 次里只有 2 次重载正好卡在切网那一刻。

## 三、这个页面到底有多重

一次首屏的实际字节（nginx `$body_bytes_sent`）：

| 资源 | 线上字节 |
|---|---|
| `/assets/index-*.js` | 237,502 |
| `/assets/vendor-*.js` | 209,631 |
| 两个 CSS | 27,275 |
| 插件组合包 combo A（57 个 client 模块） | **5,631,998** |
| 插件组合包 combo B（17 个，含音乐播放器） | **1,081,803** |
| 合计 | **≈ 7.0 MB** |

而当前 graph 里 74 个 client 模块的**未压缩**源码合计 **14.8 MB**
（`dsh-client-ui-chat/lib/client.js` 单文件 565 KB，
`dsh-better-sidebar/lib/client-mermaid.js` 更大，好在它是懒加载的 chunk）。
也就是说手机每次重载都要解析十几 MB 的 JS——V8 在手机上很容易顶到几百 MB 堆。

再加上另外两笔：

- **空转轮询**：手机 UA 的每分钟请求数中位数是 **2 req/s**（单分钟峰值 38）。
  主力是 `POST /sidebar/api/session.phase`（1/s）、`GET /dsh-music/intent`（1/s）、
  `/plugins/dsh-agent-teams/state`、`/api/costMeter/getState`。
- **SPA 外壳完全不可缓存**：`/assets/*` 的响应头只有 `content-type`
  （`dsh-host-frontend-static` 的 `writeHead` 只写了这一个头），没有
  `cache-control`、没有 `ETag`/`Last-Modified`；日志里 `/assets/*` 是
  **158 次 200、0 次 304**。文档本身是 `cache-control: no-store`，进不了
  bfcache。所以每次重载都要重下 470 KB 外壳、重新解析全部 JS。
  （插件 combo 反而是对的：响应带 `public, max-age=31536000, immutable`。）

这三条叠起来就是那段恶性循环：

```
重载 → 解析 ~15 MB JS + 每秒两个轮询 → 渲染进程内存/CPU 顶满
     → HyperOS 回收标签页 → 用户切回时浏览器恢复 = 又一次整页重载 → ...
```

## 四、排除掉的其它解释

| 假设 | 为什么不成立 |
|---|---|
| DSH/插件自动 `location.reload()` | 全量 grep，只出现在插件市场的用户点击路径 |
| service worker 更新 | 没有 SW |
| 服务端重启/升级 | 服务连续运行 23 h（`systemctl status dsh-www`），重启只在 11/11 10:21 |
| token / cookie 失效导致重定向 | 每次 `GET /` 都是 200；401 只出现在扫描器（146.70.134.158 打 `/assets/js/auth.js`）和自己 curl |
| 网关 502 / 超时 | `proxy_read_timeout 3600s`、`proxy_buffering off` 都正常；502 只在那次重启窗口 |
| 下拉刷新误触 | 需要手指下拉到顶才触发，与「用着用着闪一下」不符；不过主文档确实**没**设 `overscroll-behavior-y: contain`（只有 JSON 树/表格组件设了），顺手值得加 |

## 五、怎么确认 + 怎么缓解

**1 分钟确认（区分「浏览器/系统」还是「页面」）**

- 用 Chrome 打开同一 URL 对比：若明显好转 → MIUI 浏览器的标签管理/省电策略；
- 小米浏览器里关掉省电模式、清掉其它标签页再试；
- 观察是否在手机发热、内存紧张、开了很多 App 时更容易触发。

**缓解（按收益排序，前两条需要改服务端配置）**

1. **给 `/assets/` 加 immutable 缓存**（文件名本身带内容 hash，安全）。
   nginx 站点里加：
   ```nginx
   location ^~ /assets/ {
       proxy_hide_header Cache-Control;   # 必须：nginx 的 add_header 是追加
       add_header Cache-Control "public, max-age=31536000, immutable" always;
       proxy_pass http://127.0.0.1:3081;
       include /etc/nginx/snippets/dsh-www-proxy.inc;
   }
   ```
   每次重载少 4 个条件请求（移动端约 1–4 个 RTT）；缓存被系统清掉时省 470 KB 重下。
   **只加 `add_header` 不 `proxy_hide_header` 等于白加**：上游的 `cache-control: no-cache`
   会被原样透传，浏览器看到两行后按 no-cache 处理（2026-11-13 用临时 nginx 实例实测）。
2. **上游修 `dsh-host-frontend-static`**：给静态资源写 `cache-control`/`ETag`，
   别只写 `content-type`。
3. **轮询接事件驱动**：`session.phase`、`dsh-music/intent` 这些 1/s 的轮询
   本来就能走已有的 `/api/remote.mux` WebSocket 或 SSE 推送；退一步也应降到
   5–10 s。这是降低「被系统盯上」概率最直接的一招。
4. **主文档补 `overscroll-behavior-y: contain`**（或 `none`），防下拉刷新误触。
5. 临时手段：改用 Chrome / 少开标签 / 关省电模式。

## 六、已落地的改动（2026-11-12）

### 1) 两个插件的轮询节流（已生效，改的是 profile 里的客户端 bundle）

插件 bundle 由宿主 `dsh-client-hmr` 每 500 ms stat 轮询，改动会被识别成新 rev
并通过 `/plugins/events` 推给浏览器热替换——**不需要重启 dsh**。

| 文件 | 改动 |
|---|---|
| `~/.dsh/profiles/web/node_modules/dsh-music-player/lib/client.js` | `/dsh-music/intent` 轮询 `2000 ms → 5000 ms`；页面隐藏且没在放音（`!store.playing && !store.radioPlaying`）时直接跳过 |
| `~/.dsh/profiles/web/node_modules/dsh-better-sidebar/lib/client.js` | `session.phase` 轮询 `POLL_MS$1 = 1e3 → 5e3`；`document.hidden` 时跳过 |

验证方式（宿主视角）：

```bash
# 拿一张新 graph，看这两个模块的 rev 是否变了（其余应不变）
curl -sN -b cookies.txt http://127.0.0.1:3081/plugins/events | head -c 2000
```

实测：`graph rev 5f125b27783c → 4bb8258d9562`，只有 `dsh-music-player`、
`dsh-better-sidebar` 两个 rev 变化，且把新 URL 抓下来能搜到补丁标记
（`本地节流补丁`）—— 说明宿主读的是改后的文件、浏览器拿到的也是改后的 bundle。

原文备份在 `~/.dsh/backup-poll-patch/*.orig`，回滚就是拷回去。
**注意：插件升级/重装会覆盖这两个文件**（它们是 pnpm 硬链接，升级后是全新文件），
届时需要重新打。

### 2) nginx 给 `/assets/` 加 immutable（脚本已备好，需 root 执行一次）

本会话的 sudo 被沙箱 `no_new_privs` 挡死，所以落成一个可直接跑的脚本：

```bash
bash ~/dsh-www-assets-cache.sh --dry-run   # 先看一眼插入的块
sudo bash ~/dsh-www-assets-cache.sh        # 应用：备份 → 插入 → nginx -t（失败自动回滚）→ reload → 验证
```

脚本做的事：在 `dsh.www.ramwin.com` 的 443 server 里、`location /` 之前插入
`location ^~ /assets/`，带 `proxy_hide_header Cache-Control` + `Cache-Control: public,
max-age=31536000, immutable`，并复刻原有的 cookie 门（`error_page 418 = @dsh_www_gate`）
和 HSTS 等 `add_header` —— 因为 nginx 的 `add_header` 不跨 location 继承，漏写会把这些头弄丢。
文件名带内容 hash，所以 immutable 安全；文档本身仍不带缓存头（它的地址不带 hash，
必须继续走协商）。

2026-11-13 修正了两处：① 原脚本只有 `add_header`，会被上游 `no-cache` 顶掉，已补
`proxy_hide_header`；② 原来写"未登录的 401 也会带"，实际 401 来自 `@dsh_www_gate`
那个 location，不带这条头，验证必须先过 cookie 门（脚本现在从 nginx 的 map 里取
cookie 值再 curl）。

验证：`curl -sI -H "Cookie: dsh_www_pass=<map 里的值>" https://dsh.www.ramwin.com/assets/<真实文件名>.js | grep -i cache-control`
——**只有一行** Cache-Control 才算过；同时出现 `no-cache` 说明 `proxy_hide_header` 没生效。

## 附：这次用到的几个取证命令

```bash
# 每台设备整页重载了多少次
grep -E '"GET / HTTP' /var/log/nginx/dsh-www-access.log | awk '{print $9}' | sort | uniq -c

# 每次重载前是不是还在正常轮询（看相邻请求的时间差）
grep ' 2410DPN6CC' /var/log/nginx/dsh-www-access.log | grep 'GET / HTTP' | awk '{print $4}'

# 一次首屏到底传了多少字节
grep 'GET / HTTP' -A6 /var/log/nginx/dsh-www-access.log | awk '{s+=$10} END {print s}'

# 静态资源有没有被缓存（0 个 304 就是没缓存）
grep 'GET /assets/' /var/log/nginx/dsh-www-access.log | awk '{print $9}' | sort | uniq -c

# 插件 graph 与 client bundle 体积
curl -sN -b cookies.txt http://127.0.0.1:3081/plugins/events | head -c 2000

# 服务端有没有自己 reload（应为空）
grep -rIn "location.reload" --include=*.js ~/node_modules/@deepseek-ai
```

## 版本记录

- v3（2026-11-13）：修正 `/assets/` 长缓存方案的两处硬伤——`add_header` 只是追加，
  不 `proxy_hide_header Cache-Control` 会被上游 `no-cache` 顶掉（临时 nginx 实例实测）；
  未登录的 401 来自 gate location，不带该头，验证必须先过 cookie 门。同步更新脚本
  `~/dsh-www-assets-cache.sh`，并补实测基线（冷加载 4.3 MB / 重载 4×304 / RSS 386–399 MB）。
- v2（2026-11-12）：补「已落地的改动」——两个插件的轮询节流（实测 rev 变化 +
  bundle 校验）与 nginx `/assets/` 长缓存脚本（sudo 被沙箱挡住，留待 root 执行）。
- v1（2026-11-12）：初版。实测数据来自 11/11 00:52 → 12/11 09:27 的
  `dsh-www-access.log` 与当前 74 模块的 client graph。
  使用模型：DeepSeek Harness（deepseek-flash）。
  本次消耗 token：本会话累计 input 8.5 万 / output 5.9 万 / cacheRead 892 万，
  合计约 907 万 token。
