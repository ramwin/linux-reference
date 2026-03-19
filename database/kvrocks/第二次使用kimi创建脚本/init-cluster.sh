#!/bin/bash
set -e

echo "等待所有节点就绪..."
sleep 5

# 检查节点是否全部上线
for i in {1..6}; do
  until docker exec kvrocks${i} redis-cli -p 6666 PING | grep -q "PONG"; do
    echo "等待 kvrocks${i}..."
    sleep 2
  done
done

echo "所有节点已就绪，开始创建集群..."
echo "架构：kvrocks1(主)->kvrocks4(备), kvrocks2(主)->kvrocks5(备), kvrocks3(主)->kvrocks6(备)"

# 定义节点 ID（40 字节十六进制字符串）
NODE1_ID="1111111111111111111111111111111111111111"
NODE2_ID="2222222222222222222222222222222222222222"
NODE3_ID="3333333333333333333333333333333333333333"
NODE4_ID="4444444444444444444444444444444444444444"
NODE5_ID="5555555555555555555555555555555555555555"
NODE6_ID="6666666666666666666666666666666666666666"

# 槽位分配：每个主节点 5461 个槽位
# 主节点 1: 0-5460
# 主节点 2: 5461-10921
# 主节点 3: 10922-16383

# 构建集群拓扑信息（注意：节点之间需要换行分隔）
# 格式：$node_id $ip $port $role $master_node_id $slot_range
CLUSTER_NODES="${NODE1_ID} 172.20.0.11 6666 master - 0-5460
${NODE2_ID} 172.20.0.12 6666 master - 5461-10921
${NODE3_ID} 172.20.0.13 6666 master - 10922-16383
${NODE4_ID} 172.20.0.14 6666 slave ${NODE1_ID}
${NODE5_ID} 172.20.0.15 6666 slave ${NODE2_ID}
${NODE6_ID} 172.20.0.16 6666 slave ${NODE3_ID}"

echo "设置节点 ID..."
docker exec kvrocks1 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE1_ID}
docker exec kvrocks2 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE2_ID}
docker exec kvrocks3 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE3_ID}
docker exec kvrocks4 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE4_ID}
docker exec kvrocks5 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE5_ID}
docker exec kvrocks6 redis-cli -p 6666 CLUSTERX SETNODEID ${NODE6_ID}

echo "应用集群拓扑到所有节点..."
# 将拓扑信息应用到所有节点，版本号为 1，强制更新
for i in {1..6}; do
  echo "应用拓扑到 kvrocks${i}..."
  docker exec kvrocks${i} redis-cli -p 6666 CLUSTERX SETNODES "${CLUSTER_NODES}" 1 force
done

echo ""
echo "=== 集群创建完成 ==="
echo "查看集群状态："
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES
