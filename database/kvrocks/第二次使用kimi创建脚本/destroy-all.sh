#!/bin/bash
cd "$(dirname "$0")"
read -p "确定要删除所有数据和容器吗？(y/N) " confirm
if [ "$confirm" = "y" ]; then
  docker-compose down -v
  rm -rf data/*
  echo "已清理所有数据"
fi
