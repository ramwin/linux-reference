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

## 版本记录

| 版本 | 日期 | 内容 | 使用模型 | 本次消耗 |
|---|---|---|---|---|
| v1 | 2026-11-12 | 首版：两种暴露拓扑、固定 token、cookie 门 + Basic、sha512crypt 坑位与排查表 | deepseek-flash | 输入 5.0 万 / 输出 4.4 万 token，cache 读 443 万，约 ¥0.63（cost-meter，写入时统计） |
