# nginx

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
### [多个服务代理](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/#choosing-a-load-balancing-method)
```
http {
    upstream backend {
        server backend1.example.com;
        server backend2.example.com;
        server 192.0.0.1 backup;
    }

    server {
        location / {
            proxy_pass http://backend;
        }
    }
}
```
### server配置
* 常用配置
```
server {
    client_max_body_size 1G; // 最大上传尺寸
}
```

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
