*Xiang Wang @ 2017-03-14 14:10:44*

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
