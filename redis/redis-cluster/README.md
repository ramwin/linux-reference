# 搭建文档
[redis.io](https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/#create-and-use-a-redis-cluster)

## 安装cluster
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

## 添加一个节点
添加新节点 127.0.0.1:7005 到集群 localhost:7000
```
redis-cli --cluster add-node 127.0.0.1:7005 localhost:7000 --cluster-slave  # 新增节点变成slave
redis-cli --cluster add-node 127.0.0.1:7005 localhost:7000  # 新增节点变成master, 但是没有slot
# 此时执行check还看不到7005, 需要果断时间
```


## 删除一个节点  
1. 查看节点ip, 并且持续
```
redis-cli --cluster check localhost:7000  # 比如7002是master, 7005是slave
redis-cli -r 1000000 -i 0.1 -p 7002 rpush <key> 1  # 这里的key要保证是要删除的master上的, 后面的操作都不会终端当前的执行
```
2. 用slave节点替换master节点
```
redis-cli -c -p 7005 cluster failover takeover  # 7002变成slave, 7005变成master
```

3. 删除7005
```
# 会通知所有的cluster都删除, 并且尝试连接所有的node
redis-cli --cluster del-node 127.0.0.1:7000 `<node-id>`

# 因为特殊原因断开了,强制删除
redis-cli --cluster call 127.0.0.1:7000 cluster forget `<node-id>`
```

## 遇到问题
[ERR] Nodes don't agree about configuration!  
直接把报错的那个node删除, 然后清理nodes.conf后重新add
