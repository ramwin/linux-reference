# rediscluster
## 常用命令
* [reshard and rebalance](https://severalnines.com/blog/hash-slot-resharding-and-rebalancing-redis-cluster/)
```
redis-cli --cluster check  localhost:7002
redis-cli --cluster add-node localhost:7004 localhost:7000
redis-cli --cluster rebalance localhost:7002
redis-cli --cluster reshard localhost:7000 (把某个节点删除干净)
redis-cli --cluster del-node localhost:7000 abcd
```
## 搭建文档
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

注意需要各个节点之间可以访问 17000/1/2/3/4/5 端口
```
