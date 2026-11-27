# nginx

```{contents}
```

* [download](http://nginx.org/)
* [tutorial in didital ocean](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-18-04)
* [compile and configure](http://nginx.org/en/docs/configure.html)

## 设置账号密码
[参考](https://medium.com/@terawattled/protecting-ethereum-json-rpc-api-with-password-887f3591d221)

```
server
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    server_name demo.example.com;


    # Geth proxy that password protects the public Internet endpoint
    location /eth
        auth_basic "Restricted access to this site";
        auth_basic_user_file /etc/nginx/protected.htpasswd;

        # Proxy to geth note that is bind to localhost port
        proxy_pass http://localhost:8545;


    # Server DApp static files
    location /
        root /usr/share/nginx/html;
        index index.html

        auth_basic "Restricted access to this site";
        auth_basic_user_file /etc/nginx/protected.htpasswd;
```

生成密码

```
sudo htpasswd -c /etc/nginx/protected.htpasswd demo
```

## 安装
* [下载](http://nginx.org/)
* [编译](http://nginx.org/en/docs/configure.html)
```
./configure --prefix=/home/wangx/nginx/
make
make install
```

## 为什么这么快
为什么快，我觉得nginx可以什么都不处理啊。仅仅是一个路由器，能不快吗
* [多进程+异步非阻塞IO事件模型](https://www.jianshu.com/p/6215e5d24553)
* [一个请求只由一个worker进程来处理](https://zhuanlan.zhihu.com/p/108031600)
* 每个worker又都是异步的, IO 多路复用

## 配置
* 配置socket
```
location /ws {
    proxy_pass http://socket.ramwin.com/ws;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
}
```
* 配置路径
```
location /media_url/ {
    # internal;  # 这个可以让这个url必须内部django返回才处理
    alias /var/www/media/;
}
```
* 使用变量
```
set ROOT=/home/web/djangoproject
location /django_media {
    alias ${ROOT}/django_media
}
```
* 代理到socks
```
upstream site {
    server unix:<file.sock>
}
server {
    location /api {
        proxy_pass http://site;
        proxy_set_header Host $host;
        proxy_set_header X_FORWARDED_PROTO $schema;
        # 把 https 传给proxy 这样django可以通过设置
        # SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https') 来知道是否用了https
    }
}
```
* gzip压缩
```
server {
    gzip on;
    gzip_comp_level 6;
    gzip_types text/markdown text/css text/plain text/javascript application/javascript;
}
```
* 目录访问
```
server {
    location / {
        try_files $uri $uri/ =404;
        autoindex on;
    }
}
```

* [代理http到https](https://serversforhackers.com/c/redirect-http-to-https-nginx)
```
server {
    listen 80 default_server;

    server_name ramwin.com;

    return 301 https://$host$request_uri;
}
```

## HTTPS 证书与自动续期(certbot)

要点: **让续期只动证书文件、不动 nginx 配置**,并且**续期后必须 reload**,否则 nginx
还在用内存里的旧证书——certbot 报"续期成功",浏览器却照样看到过期证书。

### 1. 用 webroot,不要用 `--nginx` installer

`--nginx` 会改写 nginx 配置(加 `listen 443 ssl`、`ssl_certificate` 等)。配置如果
放在 git 仓里(软链进 `sites-enabled/`),续期就把仓弄脏,自动部署的
`git merge --ff-only` 直接失败。推荐:

```bash
# 首次签发
sudo certbot certonly --webroot -w /var/www/letsencrypt \
     -d example.com -d www.example.com
# 已有证书改续期方式(内部先跑一次 staging 验证,失败不落盘)
sudo certbot reconfigure --cert-name example.com --webroot -w /var/www/letsencrypt
# 清掉 nginx installer,避免续期改配置
sudo certbot reconfigure --cert-name example.com --installer none
```

对应 80 端口要有 ACME 校验入口(注意放在 server 级 `return 301` **之前**,否则
先被重定向掉):

```nginx
location ^~ /.well-known/acme-challenge/ {
    root         /var/www/letsencrypt;
    default_type "text/plain";
    access_log   off;
}
```

443 块里固定引用 `live/` 路径,续期后 reload 即可生效(软链指向新文件):

```nginx
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

### 2. 续期后自动 reload + 校验

`/etc/letsencrypt/renewal-hooks/deploy/50-reload-nginx.sh`
(脚本见 `script/certbot-reload-nginx.sh`):先 `nginx -t`,再
`systemctl reload nginx`,然后按 SNI 连本地 443,比对**线上证书指纹 == live/ 下的
新证书**;不一致就退非 0(旧 worker 还会收尾,所以要重试几秒)。这样"续期成功但
线上没生效"会立刻在日志里暴露:

```bash
tail -f /var/log/certbot-deploy-nginx.log
```

### 3. 每天体检

`script/cert-health.sh` + `script/cert-health.{service,timer}`:检查每张证书剩余
天数(<20 天报警)、每个域名 443 上服务的证书是否是 `live/` 下那张、`nginx -t`
是否通过。失败时 systemd 单元为 failed,日志在 `/var/log/cert-health.log`:

```bash
systemctl list-timers cert-health.timer
journalctl -u cert-health.service -n 20
```

### 4. 踩坑:只有 80 配置的域名

某个域名只写了 `listen 80`,访问 `https://` 时会落到 443 的**默认 server**
(第一个 443 server 块),于是拿到别的站点的证书,浏览器报
`ERR_CERT_COMMON_NAME_INVALID`。诊断:

```bash
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
    | openssl x509 -noout -subject -dates
```

证书 CN 不是自己域名 => 这个站没有 443 server 块。给每个要 HTTPS 的域名都补
443 块即可。
