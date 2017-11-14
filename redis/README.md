

# 基础
* docker版本的启动
    docker run --restart=always --name redis -d -p 6379:6379 redis
    docker exec -it redis-server redis-cli
* 安装
    * [官方教程](https://redis.io/download)
```
    wget http://download.redis.io/releases/redis-3.2.8.tar.gz
    tar xzf redis-3.2.8.tar.gz
    cd redis-3.2.8
    make
    src/redis-server
```

* [命令](./commands.md)
* [数据库]
    * 切换数据库 `select 1`
