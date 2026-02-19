# Kvrocks 高可用集群部署方案

基于 Docker Compose 的 Kvrocks 三主三从高可用集群部署方案，支持大数据量存储和故障自动切换。

## 数据持久化特性

Kvrocks 基于 RocksDB 构建，**所有数据默认持久化到磁盘**，内存仅用作缓存：

```
┌─────────────────────────────────────────┐
│              客户端请求                  │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  内存: Write Buffer + Block Cache       │  ← 临时缓存，可配置大小
│  (write-buffer-size + block_cache_size) │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  磁盘: SST 文件 + WAL 日志               │  ← 持久化存储
│  (.sst 数据文件 + .log 写前日志)          │
└─────────────────────────────────────────┘
```

**关键特性**:
- ✅ **持久化优先**: 数据先写 WAL 日志，再写内存，定期刷盘
- ✅ **内存可配置**: 通过 `block_cache_size` 控制内存使用，不影响持久化
- ✅ **大内存友好**: 即使内存很大，数据仍会写入磁盘（只是缓存更多）
- ✅ **重启不丢数据**: 容器重启后，数据从磁盘加载

## 架构概览

```
                    ┌─────────────────┐
                    │   客户端连接    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │ Master-1  │  │ Master-2  │  │ Master-3  │
        │ :6666     │  │ :6667     │  │ :6668     │
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
        │ Replica-1 │  │ Replica-2 │  │ Replica-3 │
        │ :6669     │  │ :6670     │  │ :6671     │
        └───────────┘  └───────────┘  └───────────┘
```

## 特性

- **高可用性**：3主3从架构，任一节点故障不影响服务
- **自动故障转移**：主节点故障时，从节点自动提升为主节点
- **数据分片**：数据自动分布到3个主节点
- **大数据量优化**：RocksDB 存储引擎，支持TB级数据
- **持久化存储**：数据保存在本地磁盘，容器重启不丢失
- **健康检查**：自动检测节点健康状态
- **自动重启**：容器异常退出后自动重启

## 快速开始

### 1. 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- Redis 客户端 (redis-cli)

### 2. 启动集群

```bash
./deploy.sh start
```

### 3. 连接集群

```bash
# 使用 redis-cli 连接（支持集群模式）
redis-cli -c -p 6666

# 或者连接任意节点
redis-cli -p 6667
redis-cli -p 6668
```

### 4. 测试数据

```bash
# 写入数据（自动路由到正确分片）
redis-cli -c -p 6666 SET user:1000 "Alice"
redis-cli -c -p 6666 SET user:1001 "Bob"
redis-cli -c -p 6666 HSET order:2000 item "Book" price 29.99

# 读取数据
redis-cli -c -p 6666 GET user:1000
redis-cli -c -p 6666 HGETALL order:2000
```

## 部署脚本命令

```bash
./deploy.sh <命令>

命令:
    start       启动集群
    stop        停止集群
    restart     重启集群
    status      查看集群状态
    logs        查看日志
    backup      备份所有节点数据
    cleanup     清理所有数据 (⚠️ 危险)
    benchmark   性能测试
    help        显示帮助
```

## 端口映射

| 节点 | 服务端口 | 集群总线端口 | 用途 |
|------|---------|-------------|------|
| Master-1 | 6666 | 16666 | 数据分片1 |
| Master-2 | 6667 | 16667 | 数据分片2 |
| Master-3 | 6668 | 16668 | 数据分片3 |
| Replica-1 | 6669 | 16669 | Master-1 备份 |
| Replica-2 | 6670 | 16670 | Master-2 备份 |
| Replica-3 | 6671 | 16671 | Master-3 备份 |

## 目录结构

```
.
├── docker-compose.yml      # Docker Compose 配置
├── deploy.sh               # 部署管理脚本
├── config/                 # 节点配置文件
│   ├── base.conf          # 基础配置（通用配置）⭐
│   ├── master-1.conf      # Master-1 特定配置
│   ├── master-2.conf      # Master-2 特定配置
│   ├── master-3.conf      # Master-3 特定配置
│   ├── replica-1.conf     # Replica-1 特定配置
│   ├── replica-2.conf     # Replica-2 特定配置
│   └── replica-3.conf     # Replica-3 特定配置
├── data/                   # 数据持久化目录
│   ├── master-1/
│   ├── master-2/
│   ├── master-3/
│   ├── replica-1/
│   ├── replica-2/
│   └── replica-3/
├── scripts/                # 初始化脚本
│   └── init-cluster.sh
└── backup/                 # 备份目录
```

### 配置继承机制

使用 `include` 指令共享基础配置，避免重复：

- **`base.conf`** - 包含所有节点通用的配置（RocksDB 优化、日志、性能参数等）
- **节点配置** - 仅包含差异化配置（端口、节点ID、主从关系）

**示例** - `master-1.conf`:
```conf
# 引用基础配置
include /etc/kvrocks/base.conf

# 仅配置差异化参数
port 6666
cluster-node-id kvrocks-master-1
```

**优势**:
- ✅ 修改一处，全局生效
- ✅ 配置清晰，易于维护
- ✅ 新增节点只需复制模板，修改端口和ID即可

## 高可用测试

### 模拟主节点故障

```bash
# 1. 查看当前集群状态
./deploy.sh status

# 2. 停止一个主节点
docker stop kvrocks-master-1

# 3. 再次查看状态，观察 Replica-1 是否提升为主节点
./deploy.sh status

# 4. 恢复节点
docker start kvrocks-master-1

# 5. 查看状态，Master-1 将作为从节点重新加入
./deploy.sh status
```

### 验证数据一致性

```bash
# 写入测试数据
for i in {1..1000}; do
    redis-cli -c -p 6666 SET test:key:$i "value-$i"
done

# 模拟故障后验证数据
docker stop kvrocks-master-1
sleep 5

# 仍然可以读取数据
redis-cli -c -p 6667 GET test:key:100

# 恢复节点
docker start kvrocks-master-1
```

## 大数据量优化配置

配置文件针对大数据量场景做了以下优化：

| 配置项 | 值 | 说明 |
|-------|-----|------|
| write-buffer-size | 256MB | 写缓冲区大小 |
| max-write-buffer-number | 6 | 最大写缓冲区数 |
| block_cache_size | 2GB | 块缓存大小 |
| compression | lz4 | 压缩算法 |
| bottommost_compression | zstd | 底层压缩算法 |
| max_open_files | 65535 | 最大打开文件数 |
| max_bytes_for_level_base | 1GB | L1层大小 |

## 备份与恢复

### 自动备份

```bash
# 备份所有节点数据
./deploy.sh backup
```

备份文件保存在 `backup/YYYYMMDD_HHMMSS/` 目录下。

### 手动备份

```bash
# 触发 Kvrocks 备份命令
redis-cli -p 6666 BGSAVE

# 备份文件在 data/master-1/backup/ 目录下
```

### 数据恢复

```bash
# 1. 停止集群
./deploy.sh stop

# 2. 恢复数据（将备份文件解压到 data/ 目录）
tar xzf backup/20240115_120000/master-1.tar.gz -C data/

# 3. 启动集群
./deploy.sh start
```

## 性能调优建议

### 1. 宿主机优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 禁用透明大页
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# 调整 swappiness
echo "vm.swappiness = 1" >> /etc/sysctl.conf
sysctl -p
```

### 2. 存储优化

- 使用 SSD 存储数据目录
- 将数据目录挂载到单独的磁盘
- 使用 XFS 或 ext4 文件系统

### 3. 内存优化

根据数据量调整 block_cache_size：
- 数据量 < 100GB: 2GB
- 数据量 100GB-500GB: 4GB
- 数据量 > 500GB: 8GB+

## 监控与告警

### 查看节点统计

```bash
# 查看 RocksDB 统计
redis-cli -p 6666 INFO rocksdb

# 查看复制状态
redis-cli -p 6666 INFO replication

# 查看内存使用
redis-cli -p 6666 INFO memory
```

### 常用监控指标

```bash
# 每秒查询数
redis-cli -p 6666 INFO stats | grep instantaneous_ops_per_sec

# 磁盘使用量
du -sh data/*

# 容器资源使用
docker stats --no-stream
```

## 验证数据落盘

Kvrocks 使用 RocksDB 存储引擎，数据默认会持久化到磁盘。即使内存充足，也可通过以下方式验证：

### 快速验证

```bash
# 运行验证脚本
./deploy.sh verify
```

### 验证方法说明

#### 方法1: 查看磁盘占用
```bash
# 观察数据目录大小
du -sh data/master-1/

# 查看 SST 文件数量（RocksDB 的数据文件）
find data/master-1/ -name "*.sst" | wc -l
```

#### 方法2: 查看 RocksDB 统计
```bash
# 连接节点查看内存 vs 磁盘数据量
redis-cli -p 6666 INFO rocksdb

# 关键指标:
# - rocksdb.estimate-live-data-size: 磁盘上的数据大小
# - rocksdb.size-all-mem-tables: 内存表大小
# - rocksdb.block_cache_usage: 块缓存使用
```

#### 方法3: 强制小内存配置（强制落盘）

创建临时配置强制数据频繁落盘：

```bash
# 1. 备份原配置
cp config/base.conf config/base.conf.bak

# 2. 使用小内存配置
cp config/base-small-memory.conf config/base.conf

# 3. 重启集群
./deploy.sh restart

# 4. 写入数据并观察
redis-cli -p 6666
> SET key1 "value1"
> SET key2 "value2"
# ... 大量写入

# 5. 观察磁盘变化
du -sh data/master-1/
ls -lh data/master-1/*.sst

# 6. 恢复配置
cp config/base.conf.bak config/base.conf
./deploy.sh restart
```

小内存配置关键参数：
```conf
write-buffer-size 4mb          # 极小的写缓冲区
max-write-buffer-number 2       # 最多2个缓冲区
rocksdb.block_cache_size 8mb    # 极小的块缓存
```

#### 方法4: 使用 iostat 监控磁盘IO

```bash
# 终端1: 监控磁盘IO
iostat -x 1

# 终端2: 写入数据
for i in {1..100000}; do
    redis-cli -p 6666 SET "test:$i" "value-$i"
done
```

如果观察到磁盘写入活动，说明数据正在写入磁盘。

### 数据文件说明

| 文件类型 | 扩展名 | 说明 |
|---------|-------|------|
| SST 文件 | `.sst` | 已排序字符串表，实际数据文件 |
| WAL 日志 | `.log` | 写前日志，崩溃恢复用 |
| 元数据 | `MANIFEST` | SST 文件组织结构 |
| 配置 | `OPTIONS-*` | RocksDB 配置快照 |

## 常见问题

### Q: 集群启动失败？

检查日志：
```bash
./deploy.sh logs
# 或查看特定节点
docker logs kvrocks-master-1
```

### Q: 如何扩容？

目前方案为固定 3 主 3 从。如需更多节点：
1. 修改 `docker-compose.yml` 添加新节点
2. 创建对应的配置文件
3. 使用 `redis-cli --cluster add-node` 添加节点

### Q: 如何升级版本？

```bash
# 1. 备份数据
./deploy.sh backup

# 2. 停止集群
./deploy.sh stop

# 3. 修改 docker-compose.yml 中的镜像版本

# 4. 拉取新镜像并启动
docker-compose pull
./deploy.sh start
```

## 参考资料

- [Kvrocks 官方文档](https://kvrocks.apache.org/)
- [Apache Kvrocks GitHub](https://github.com/apache/kvrocks)
- [Redis Cluster 规范](https://redis.io/topics/cluster-spec)
