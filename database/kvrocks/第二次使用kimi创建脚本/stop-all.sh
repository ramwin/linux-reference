#!/bin/bash
cd "$(dirname "$0")"
docker-compose down
echo "集群已停止"
