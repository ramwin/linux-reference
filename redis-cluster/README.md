# 搭建文档
https://redis.io/docs/management/scaling/#create-and-use-a-redis-cluster

1. 进入每个cluster-test/700* 目录，执行
```
redis-server ./redis.conf
```

2. 执行
```
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 \
127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
--cluster-replicas 1
```
