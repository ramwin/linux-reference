#!/bin/bash
set -e

echo "等待所有节点就绪..."
sleep 10

# 检查节点是否全部上线
for i in {1..6}; do
  until docker exec kvrocks${i} redis-cli -p 6666 PING | grep -q "PONG"; do
    echo "等待 kvrocks${i}..."
    sleep 2
  done
done

echo "所有节点已就绪，开始创建集群..."
echo "架构：kvrocks1(主)->kvrocks4(备), kvrocks2(主)->kvrocks5(备), kvrocks3(主)->kvrocks6(备)"

# 使用 redis-cli 创建集群，--cluster-replicas 1 表示每个主节点分配 1 个从节点
# 顺序很重要：前 3 个是主节点，后 3 个自动分配为从节点
docker run --rm --network kvrocks-ha-cluster_kvrocks_network redis:7-alpine \
  redis-cli --cluster create \
  172.20.0.11:6666 \
  172.20.0.12:6666 \
  172.20.0.13:6666 \
  172.20.0.14:6666 \
  172.20.0.15:6666 \
  172.20.0.16:6666 \
  --cluster-replicas 1 \
  --cluster-yes

echo ""
echo "=== 集群创建完成 ==="
echo "查看集群状态："
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES
