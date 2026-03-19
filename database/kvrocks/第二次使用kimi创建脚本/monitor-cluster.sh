#!/bin/bash
# 监控脚本：显示集群状态，并在必要时进行手动故障转移测试

echo "=== 当前集群节点状态 ==="
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES

echo ""
echo "=== 集群槽位分配 ==="
docker exec kvrocks1 redis-cli -p 6666 CLUSTER SLOTS

echo ""
echo "=== 主从对应关系 ==="
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES | grep -E "master|slave" | awk '
/master/ { 
    master_id=$1; 
    master_ip=$2; 
    gsub(/:.*/,"",master_ip);
    masters[master_id]=master_ip 
}
/slave/ { 
    slave_master=$4; 
    slave_ip=$2;
    gsub(/:.*/,"",slave_ip);
    print "主节点: " masters[slave_master] " -> 从节点: " slave_ip 
}'
