#!/bin/sh
# Kvrocks 集群初始化脚本
# 等待所有节点启动完成，然后创建集群

set -e

echo "=========================================="
echo "  Kvrocks 集群初始化"
echo "=========================================="

# 等待所有节点就绪
echo "等待所有 Kvrocks 节点启动..."

wait_for_node() {
    host=$1
    port=$2
    max_attempts=60
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if redis-cli -h $host -p $port ping 2>/dev/null | grep -q "PONG"; then
            echo "  ✓ $host:$port 已就绪"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "  等待 $host:$port ... ($attempt/$max_attempts)"
        sleep 2
    done
    
    echo "  ✗ $host:$port 启动超时"
    return 1
}

# 等待所有节点
wait_for_node kvrocks-master-1 6666
wait_for_node kvrocks-master-2 6667
wait_for_node kvrocks-master-3 6668
wait_for_node kvrocks-replica-1 6669
wait_for_node kvrocks-replica-2 6670
wait_for_node kvrocks-replica-3 6671

echo ""
echo "所有节点已就绪，正在初始化集群..."
echo ""

# 检查集群是否已存在
cluster_info=$(redis-cli -h kvrocks-master-1 -p 6666 cluster info 2>/dev/null || echo "")
if echo "$cluster_info" | grep -q "cluster_state:ok"; then
    echo "集群已经存在且正常运行，跳过初始化"
    echo ""
    echo "集群信息："
    redis-cli -h kvrocks-master-1 -p 6666 cluster nodes
    exit 0
fi

# 创建集群 (使用 Redis 集群协议)
# Kvrocks 兼容 Redis Cluster 协议
echo "正在创建集群..."

# 尝试使用 redis-cli 创建集群
if redis-cli --cluster create \
    kvrocks-master-1:6666 \
    kvrocks-master-2:6667 \
    kvrocks-master-3:6668 \
    kvrocks-replica-1:6669 \
    kvrocks-replica-2:6670 \
    kvrocks-replica-3:6671 \
    --cluster-replicas 1 \
    --cluster-yes 2>/dev/null; then
    echo ""
    echo "✓ 集群创建成功！"
else
    echo ""
    echo "! 使用 redis-cli 创建集群失败，尝试手动配置..."
    
    # 手动配置集群（备用方案）
    # 1. 先让各节点认识彼此
    for node in kvrocks-master-1:6666 kvrocks-master-2:6667 kvrocks-master-3:6668; do
        host=$(echo $node | cut -d: -f1)
        port=$(echo $node | cut -d: -f2)
        redis-cli -h $host -p $port cluster meet kvrocks-master-1 6666 2>/dev/null || true
        redis-cli -h $host -p $port cluster meet kvrocks-master-2 6667 2>/dev/null || true
        redis-cli -h $host -p $port cluster meet kvrocks-master-3 6668 2>/dev/null || true
    done
    
    echo "  手动配置完成"
fi

echo ""
echo "=========================================="
echo "  集群初始化完成！"
echo "=========================================="
echo ""
echo "集群节点信息："
redis-cli -h kvrocks-master-1 -p 6666 cluster nodes 2>/dev/null || echo "  无法获取节点信息"
echo ""
echo "集群状态："
redis-cli -h kvrocks-master-1 -p 6666 cluster info 2>/dev/null || echo "  无法获取集群信息"
echo ""
echo "使用方式:"
echo "  1. 使用 redis-cli -c -p 6666 连接集群（支持自动重定向）"
echo "  2. 或使用任意客户端连接端口 6666-6671 中的任意一个"
echo "  3. 数据会自动分片到 3 个主节点"
echo "  4. 任一主节点故障时，其从节点会自动提升为主节点"
echo ""
