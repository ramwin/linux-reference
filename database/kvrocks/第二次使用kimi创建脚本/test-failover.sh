#!/bin/bash

if [ -z "$1" ]; then
  echo "用法: ./test-failover.sh <主节点编号 1|2|3>"
  echo "例如: ./test-failover.sh 1  # 模拟 kvrocks1 崩溃，观察 kvrocks4 是否接管"
  exit 1
fi

MASTER_NUM=$1
BACKUP_NUM=$((MASTER_NUM + 3))

echo "=== 模拟故障：停止 kvrocks${MASTER_NUM} (主节点) ==="
docker stop kvrocks${MASTER_NUM}

echo ""
echo "等待 10 秒让集群检测到故障..."
sleep 10

echo ""
echo "=== 当前集群状态（应看到 kvrocks${BACKUP_NUM} 已提升为主节点） ==="
docker exec kvrocks$((MASTER_NUM==1?2:1)) redis-cli -p 6666 CLUSTER NODES

echo ""
echo "=== 恢复原始主节点 ==="
echo "启动 kvrocks${MASTER_NUM}..."
docker start kvrocks${MASTER_NUM}
sleep 5

echo ""
echo "将 kvrocks${MASTER_NUM} 重新加入集群作为从节点..."
# 获取当前主节点 ID
MASTER_ID=$(docker exec kvrocks${BACKUP_NUM} redis-cli -p 6666 CLUSTER MYID)
docker exec kvrocks${MASTER_NUM} redis-cli -p 6666 CLUSTER REPLICATE ${MASTER_ID}

echo ""
echo "=== 最终集群状态 ==="
sleep 3
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES
