# Kvrocks 高可用集群部署项目

## 项目概述

本项目是一个基于 Docker Compose 的 Apache Kvrocks 高可用集群部署方案。Kvrocks 是一个兼容 Redis 协议的键值存储系统，使用 RocksDB 作为底层存储引擎。

项目实现了 6 节点集群架构（3 主 3 从），支持自动故障转移（Automatic Failover），当主节点宕机时，从节点会自动提升为主节点继续提供服务。

## 技术栈

- **容器化**: Docker & Docker Compose
- **数据库**: Apache Kvrocks (Redis 兼容)
- **集群协议**: Redis Cluster Protocol
- **基础镜像**: `apache/kvrocks:latest`
- **辅助工具**: `redis:7-alpine` (用于集群初始化)
- **测试脚本**: Python 3 + redis-py 库

## 架构设计

### 节点拓扑

```
                    +---------------+
                    |   Cluster     |
                    |   Bus         |
                    +-------+-------+
                            |
        +-------------------+-------------------+
        |                   |                   |
   +----+----+         +----+----+         +----+----+
   |Master 1 |         |Master 2 |         |Master 3 |
   |kvrocks1 |         |kvrocks2 |         |kvrocks3 |
   |172.20.0.11       |172.20.0.12       |172.20.0.13
   |:6666/:16666      |:6667/:16667      |:6668/:16668
   +----+----+         +----+----+         +----+----+
        |                   |                   |
   +----+----+         +----+----+         +----+----+
   |Slave 1  |         |Slave 2  |         |Slave 3  |
   |kvrocks4 |         |kvrocks5 |         |kvrocks6 |
   |172.20.0.14       |172.20.0.15       |172.20.0.16
   |:6669/:16669      |:6670/:16670      |:6671/:16671
   +---------+         +---------+         +---------+
```

### 网络配置

- **网络类型**: Bridge
- **子网**: `172.20.0.0/24`
- **端口映射**:
  - 主节点 1-3: 6666-6668 (客户端), 16666-16668 (集群总线)
  - 从节点 4-6: 6669-6671 (客户端), 16669-16671 (集群总线)

### 故障转移机制

1. **检测**: 集群通过 Gossip 协议检测节点状态，`cluster-node-timeout` 设置为 5000ms
2. **选举**: 当主节点失效，其从节点会发起选举
3. **提升**: 获得足够投票的从节点提升为新主节点
4. **恢复**: 原主节点恢复后，可作为从节点重新加入集群

## 项目结构

```
.
├── docker-compose.yml          # Docker Compose 配置（6 节点定义）
├── config/
│   └── kvrocks-cluster.conf.template  # Kvrocks 配置模板
├── data/                       # 数据持久化目录（1-6 子目录对应各节点）
├── start-all.sh               # 启动并初始化集群
├── init-cluster.sh            # 集群拓扑初始化脚本
├── monitor-cluster.sh         # 集群状态监控脚本
├── test-failover.sh           # 故障转移测试脚本
├── test-ha-failover.py        # Python 持续写入测试脚本
├── stop-all.sh                # 停止集群
├── destroy-all.sh             # 销毁集群（含数据）
└── README.md                  # 使用说明
```

## 核心配置文件说明

### docker-compose.yml

- 定义 6 个 Kvrocks 服务 (kvrocks1-6)
- 每个服务挂载配置模板和数据目录
- 通过 `command` 动态注入节点特定的集群宣告配置
- 配置了健康检查和服务依赖关系

### config/kvrocks-cluster.conf.template

关键配置项：
- `cluster-enabled yes`: 启用集群模式
- `cluster-node-timeout 5000`: 节点超时 5 秒
- `cluster-slave-no-failover no`: 允许从节点故障转移
- `cluster-require-full-coverage no`: 不需要全槽覆盖即可服务
- 持久化: AOF (每秒刷盘) + RDB
- RocksDB 性能优化参数

## 常用命令

### 集群生命周期管理

```bash
# 启动并初始化集群
./start-all.sh

# 查看集群状态
./monitor-cluster.sh

# 停止集群（保留数据）
./stop-all.sh

# 彻底销毁集群（删除数据）
./destroy-all.sh
```

### 故障转移测试

```bash
# 测试节点 1 的故障转移（kvrocks1 宕机，kvrocks4 接管）
./test-failover.sh 1

# Python 持续写入测试（在故障期间验证可用性）
python3 test-ha-failover.py
```

### 手动连接集群

```bash
# 使用 redis-cli 连接（集群模式）
redis-cli -p 6666 -c

# 查看集群节点
CLUSTER NODES

# 查看槽位分配
CLUSTER SLOTS
```

## 开发约定

### 脚本规范

- 所有脚本以 `#!/bin/bash` 开头
- 使用 `set -e` 确保错误时退出（init-cluster.sh）
- 使用 `cd "$(dirname "$0")"` 确保在脚本所在目录执行

### 端口分配约定

- 主节点编号 1-3，从节点编号 = 主节点编号 + 3
- 客户端端口: 6666 + (节点编号 - 1)
- 集群总线端口: 16666 + (节点编号 - 1)

### 数据持久化

- 数据存储在 `./data/{节点编号}/` 目录
- 包含 RDB 文件、AOF 文件、节点配置文件
- 删除容器后数据保留，可通过 `destroy-all.sh` 清理

## 测试策略

### 1. 故障转移测试 (test-failover.sh)

- 模拟指定主节点宕机
- 验证从节点是否自动提升为主节点
- 恢复原始主节点并重新加入集群

### 2. 高可用写入测试 (test-ha-failover.py)

- 使用 redis-py 的 RedisCluster 客户端
- 配置重试策略: 指数退避，最多 20 次重试
- 在写入过程中手动触发故障转移
- 验证：允许短暂卡顿，不允许写入失败

## 安全注意事项

1. **容器运行用户**: 当前配置使用 `user: "0:0"` (root) 运行，生产环境建议调整为特定 UID
2. **网络暴露**: 所有节点端口映射到主机，确保防火墙正确配置
3. **数据权限**: 数据目录权限设置为 755，确保容器内进程可访问
4. **无认证**: 默认配置无密码认证，生产环境应启用 `requirepass` 和 `masterauth`

## 故障排查

### 查看节点日志

```bash
docker logs kvrocks1
docker exec kvrocks1 cat /data/kvrocks.log
```

### 检查集群健康状态

```bash
# 检查所有节点是否响应 PONG
for i in {1..6}; do
  docker exec kvrocks${i} redis-cli -p 6666 PING
done

# 查看详细节点信息
docker exec kvrocks1 redis-cli -p 6666 CLUSTER NODES
```

### 常见问题

1. **节点无法加入集群**: 检查网络连通性和 `cluster-announce-ip` 配置
2. **故障转移未触发**: 检查 `cluster-node-timeout` 和 `cluster-slave-no-failover` 设置
3. **数据不一致**: 检查 AOF 和 RDB 持久化配置

## 扩展指南

### 添加新节点

1. 在 `docker-compose.yml` 中添加新服务定义
2. 分配新的 IP 和端口
3. 使用 `redis-cli --cluster add-node` 添加节点
4. 使用 `redis-cli --cluster reshard` 重新分配槽位

### 调整副本数

修改 `init-cluster.sh` 中的 `--cluster-replicas` 参数（当前为 1，即 1 主 1 从）

## 相关资源

- [Apache Kvrocks 官方文档](https://kvrocks.apache.org/)
- [Redis Cluster 规范](https://redis.io/docs/reference/cluster-spec/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
