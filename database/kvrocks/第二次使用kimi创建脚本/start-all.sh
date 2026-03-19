#!/bin/bash
cd "$(dirname "$0")"
docker-compose up -d
echo "容器已启动，等待 15 秒后初始化集群..."
sleep 15
./init-cluster.sh
echo ""
echo "部署完成！连接命令："
echo "  redis-cli -p 6666 -c  # 连接到主节点1 (集群模式)"
