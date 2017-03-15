#### Xiang Wang @ 2017-03-13 15:06:08

# 启动服务
```
    # 直接启动
    docker run --name mongoserver -p 27017:27017 -d mongo
    # 暴露端口
```

# 连接mongodb
```
    docker run -ti --link mongoserver:mongo --rm mongo sh -c 'exec mongo "$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT/test"'
```
