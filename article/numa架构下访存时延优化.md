# NUMA 架构下访存时延优化

```{contents}
```

NUMA（Non-Uniform Memory Access，非一致性内存访问）是多路服务器的主流内存架构。简单来说，NUMA 的核心矛盾是：**每个 CPU 访问自己"本地"内存很快，但跨节点访问"远程"内存会慢得多**。理解并优化这个时延差，是高性能服务端编程的必修课。

```{toctree}
:maxdepth: 2
```

## 概念

### 为什么需要 NUMA

在传统的 SMP（Symmetric Multi-Processing，对称多处理）架构中，所有 CPU 通过同一条总线访问同一块物理内存：

```
+--------+  +--------+  +--------+  +--------+
| CPU 0  |  | CPU 1  |  | CPU 2  |  | CPU 3  |
+----+---+  +----+---+  +----+---+  +----+---+
     |           |           |           |
     +-----+-----+-----+-----+-----+-----+
                 |
          +------v------+
          |  内存控制器   |
          +------+------+
                 |
          +------v------+
          |   物理内存    |
          +-------------+
```

这个架构的问题是：**所有 CPU 共享一条内存总线**。CPU 核数越多，总线竞争越激烈——这就是 SMP 的"内存墙"。

NUMA 的解法是：**把内存拆开，每个 CPU 配一块"本地内存"**:

```
+---------------------------+    +---------------------------+
|         Node 0            |    |         Node 1            |
| +--------+  +----------+  |    | +--------+  +----------+  |
| | CPU 0  |  | CPU 1    |  |    | | CPU 2  |  | CPU 3    |  |
| +---+----+  +-----+----+  |    | +---+----+  +-----+----+  |
|     |             |        |    |     |             |        |
| +---v-------------v----+  |    | +---v-------------v----+  |
| |     内存控制器        |  |    | |     内存控制器        |  |
| +----------+-----------+  |    | +----------+-----------+  |
|            |              |    |            |              |
| +----------v-----------+  |    | +----------v-----------+  |
| |   本地内存 (16GB)     |  |    | |   本地内存 (16GB)     |  |
| +----------------------+  |    | +----------------------+  |
|                           |    |                           |
|        +------+  interconnect (QPI/UPI)  +------+          |
|        +---------------------------------------+          |
+---------------------------+    +---------------------------+
```

CPU 0 和 CPU 1 访问 Node 0 的内存是**本地访问**（local access），速度快。但它们访问 Node 1 的内存则需要通过 CPU 间的互联总线（QPI/UPI），这就是**远程访问**（remote access），速度慢。

```{note}
Intel 平台用 QPI（QuickPath Interconnect）或 UPI（Ultra Path Interconnect），AMD 平台用 Infinity Fabric。虽然名字不同，但本质一样：CPU 之间的点对点高速互联。
```

### 本地 vs 远程：到底差多少？

典型的两路 Xeon 服务器上：

| 访问类型 | 时延 | 带宽 | 相对代价 |
|---------|------|------|---------|
| 本地内存访问 | ~100 ns | ~100 GB/s | 1x |
| 远程内存访问 | ~150-200 ns | ~40 GB/s | 1.5-2x |
| L3 Cache | ~10-20 ns | ~200+ GB/s | 0.1x |
| 本地访问/远程交叉 | - | - | 带宽可能对半砍 |

```{note}
1.5-2x 的时延差异看起来不大，但在内存密集型应用中——比如数据库的 Buffer Pool 扫描——远程访问比例高时吞吐量可能下降 30%-50%。因为不仅单次访问更慢，远程互联链路的并发能力也有限。
```

## 工作原理

### NUMA 拓扑结构

Linux 将 NUMA 系统中的资源组织为"节点"（node），每个节点包含一组 CPU 和一段本地内存。

#### 查看拓扑

```bash
# 查看 NUMA 节点概况
numactl --hardware
# 输出示例:
# available: 2 nodes (0-1)
# node 0 cpus: 0 1 2 3 8 9 10 11
# node 0 size: 16000 MB
# node 0 free: 12000 MB
# node 1 cpus: 4 5 6 7 12 13 14 15
# node 1 size: 16000 MB
# node 1 free: 11000 MB
# node distances:
# node   0   1
#   0:  10  21
#   1:  21  10
```

输出中最关键的是 **node distances（节点距离矩阵）**：

```
node   0   1
  0:  10  21
  1:  21  10
```

- 对角线（10）是本地访问的相对代价（基准值，不是真实纳秒数）
- 非对角线（21）是远程访问的相对代价
- 21 / 10 = 2.1，意味着远程访问代价是本地的 **2.1 倍**

```{mermaid}
flowchart LR
    subgraph "Node 0"
        CPU0[CPU 0-3]
        MEM0[本地内存 16GB]
    end
    subgraph "Node 1"
        CPU1[CPU 4-7]
        MEM1[本地内存 16GB]
    end
    CPU0 -- "距离 10<br/>本地访问" --> MEM0
    CPU1 -- "距离 10<br/>本地访问" --> MEM1
    CPU0 -- "距离 21<br/>远程访问" --> MEM1
    CPU1 -- "距离 21<br/>远程访问" --> MEM0
```

#### 多级 NUMA 距离

更大的系统可能有更复杂的距离矩阵，比如四路 AMD EPYC：

| node | 0 | 1 | 2 | 3 |
|------|---|---|---|---|
| 0 | 10 | 16 | 32 | 32 |
| 1 | 16 | 10 | 32 | 32 |
| 2 | 32 | 32 | 10 | 16 |
| 3 | 32 | 32 | 16 | 10 |

AMD EPYC 采用多芯片封装，同一 Package 内的两个 die 互访代价（距离 16）小于跨 Package 访问（距离 32）。

```{note}
在 AMD EPYC 上，"同一 socket" 不等于 "同一 NUMA node"。一个物理 CPU 封装内可能有多个 NUMA 节点，可以通过 BIOS 配置为"每 socket 一个 NUMA 节点"（NPS=1）或"每 socket 多个 NUMA 节点"（NPS=2/4）。
```

### 内存分配策略

Linux 提供了多种 NUMA 内存分配策略，这是优化的核心工具：

| 策略 | 常量 | 行为 |
|------|------|------|
| 本地分配（默认） | `MPOL_DEFAULT` | 优先在当前 CPU 所在节点分配；内存不足时允许溢出到其他节点 |
| 绑定 | `MPOL_BIND` | 严格只在指定节点上分配；如果指定节点内存不足，**OOM 或触发 swap** |
| 交错 | `MPOL_INTERLEAVE` | 在所有指定节点间轮转分配，确保数据均匀分布 |
| 优先 | `MPOL_PREFERRED` | 优先在指定节点分配；不够时才从其他节点分配 |

```{mermaid}
flowchart TB
    subgraph "MPOL_BIND: 严格绑定到 Node 0"
        BIND[分配请求] --> N0[Node 0]
        N0 -- "内存足够" --> OK[分配成功]
        N0 -- "内存不足" --> FAIL[OOM 或 Swap<br/>绝不碰 Node 1]
    end
    subgraph "MPOL_INTERLEAVE: 轮转分配"
        INT[分配请求] --> ROUND{轮转}
        ROUND --> N0_I[Node 0 分配一页]
        ROUND --> N1_I[Node 1 分配一页]
        N0_I --> ROUND
        N1_I --> ROUND
    end
    subgraph "MPOL_PREFERRED: 优先 Node 0"
        PREF[分配请求] --> P0[Node 0]
        P0 -- "足够" --> OK_P[成功]
        P0 -- "不足" --> FALLBACK[回退到 Node 1]
    end
```

#### 策略的使用场景

| 策略 | 适合场景 | 不适合场景 |
|------|---------|-----------|
| bind | 单进程固定在某个 node，数据量和内存大小匹配 | 多条工作线程跨 node 访问绑定内存（远程访问代价高） |
| interleave | 多线程共享一块大内存且各线程分布在不同 node | 单线程访问——反而制造了大量远程访问 |
| preferred | 主工作线程固定 node，偶尔溢出可以接受 | 严格要求内存不跨 node |

**核心原则**：让数据尽可能靠近访问它的 CPU。策略只是工具，前提是你要知道"谁在哪个 CPU 上访问哪些数据"。

### 自动 NUMA 平衡（AutoNUMA）

手动设置策略很精细，但成本高。Linux 内核从 3.13 开始引入了**自动 NUMA 平衡**（AutoNUMA balancing），让内核自动做这件事。

#### 工作原理

```{mermaid}
flowchart TB
    SCAN[内核线程定期扫描] --> MARK[标记哪些页被远程访问]
    MARK --> DECIDE{迁移决策}
    DECIDE -- "远程访问频繁" --> MIGRATE[将页迁到访问者所在节点]
    DECIDE -- "本地访问为主" --> KEEP[保持不动]
    DECIDE -- "多节点同时频繁访问" --> SHARE[保持远程 + 不做迁移<br/>避免 ping-pong]
    MIGRATE --> UPDATE[更新进程页表]
    UPDATE --> SCAN
```

具体机制：

1. **扫描线程**：内核周期性遍历进程的页表，清除 PTE（Page Table Entry）的 present 位，制造一个"缺页"
2. **触发缺页**：当进程下次访问该页时，触发 minor page fault
3. **记录信息**：缺页处理函数记录"哪个 CPU、哪个节点访问了这页"
4. **判断迁移**：如果发现一个页被远程节点频繁访问，后台线程将其迁移到访问者所在的节点
5. **防抖**：如果多个节点都在频繁访问同一页（共享数据），不做迁移——避免页面在两个节点间 ping-pong

#### 关键内核参数

```bash
# 查看当前设置
cat /proc/sys/kernel/numa_balancing
# 0 = 关闭, 1 = 开启

# 扫描延迟（毫秒），内核在这个周期内扫描进程页表
cat /proc/sys/kernel/numa_balancing_scan_delay_ms
# 默认 1000ms

# 每次扫描的页数
cat /proc/sys/kernel/numa_balancing_scan_size_mb
# 默认 256MB
```

```{note}
自动 NUMA 平衡有开销：扫描页表和制造缺页本身消耗 CPU。对于延迟敏感的 OLTP 数据库，有时关闭 AutoNUMA 并用 `numactl` 手动绑定反而更好——因为你比内核更了解自己的访问模式。
```

### 页迁移机制

无论是 AutoNUMA 自动迁移还是 `migrate_pages()` 手动迁移，底层都依赖内核的页迁移框架：

```
源节点                              目标节点
+----------------+                 +----------------+
| 物理页 A       |  ── 分配新页 ──> | 物理页 A'     |
| (数据)         |                 | (空)          |
+-------+--------+                 +-------+--------+
        |                                   |
        |  1. 锁住页 A（阻止写入）            |
        |  2. 拷贝数据 A → A'               |
        |  3. 更新页表指向 A'                |
        |  4. 释放页 A                      |
        |                                   |
        v                                   v
+----------------+                 +----------------+
| 空闲            |                 | 物理页 A'     |
|                |                 | (数据)        |
+----------------+                 +----------------+
```

关键是第 1-3 步：内核保证在迁移过程中，进程仍然可以读取旧页（直到页表更新生效），写入则在持有锁期间被阻塞。这个过程对用户态进程是**透明的**——进程只会感觉那一次访问"稍微慢了一点点"。

```{mermaid}
flowchart LR
    TASK[进程访问] --> FAULT[触发缺页]
    FAULT --> OLD[读到旧 NUMA 节点数据]
    OLD --> MIGRATE_THREAD[迁移线程]
    MIGRATE_THREAD --> ALLOC[在目标 NUMA 节点分配新页]
    ALLOC --> COPY[memcpy 旧页到新页]
    COPY --> UPDATE_PTE[更新页表指向新页]
    UPDATE_PTE --> FREE[释放旧页]
```

## 典型用途

### 数据库优化

数据库是 NUMA 优化的经典场景。问题模式：

**场景**：MySQL/PostgreSQL 在双路服务器上，Buffer Pool 分配在 Node 0 上，但连接线程可能被调度到 Node 1 的 CPU 上执行。

```
+----------------------------+    +----------------------------+
|        Node 0              |    |        Node 1              |
|  +----------+              |    |  +----------+              |
|  | Buffer   |              |    |  | 查询线程  |              |
|  | Pool     |<--远程访问----+----+--| (被调度到 |              |
|  | (32GB)   |              |    |  |  Node 1)  |              |
|  +----------+              |    |  +----------+              |
+----------------------------+    +----------------------------+
```

优化方案：

**方案一：绑定内存 + 绑定 CPU**

```bash
# MySQL 进程的 NUMA 绑定
numactl --cpunodebind=0 --membind=0 mysqld

# 这样 MySQL 的所有内存分配和线程运行都在 Node 0
```

**方案二：交错分配 + 不绑定 CPU**

```bash
# 跨所有节点交错分配 Buffer Pool
numactl --interleave=all mysqld

# 好处：无论线程被调度到哪个节点，至少有一部分数据在本地
# 坏处：必然有一部分数据在远程
```

**方案三：MySQL 8.0 的 innodb_numa_interleave**

MySQL 8.0 内置了 NUMA 支持：

```sql
-- 让 InnoDB Buffer Pool 跨 NUMA 节点交错分配
SET GLOBAL innodb_numa_interleave = ON;
```

```{note}
方案一通常效果最好——如果你能确保数据库进程的 CPU 都在同一节点。方案二适用于 "进程 CPU 绑定不固定" 的场景。方案三是方案二的 MySQL 内置版本，但只影响 Buffer Pool，不影响其他内存分配。
```

### HPC 与大规模并行计算

HPC 场景中典型的做法是将 MPI 进程与 NUMA 节点一一绑定：

```bash
# 在 4 节点系统上，每个 MPI rank 绑定到一个节点
mpirun -np 4 numactl --cpunodebind=0 --membind=0 ./app : \
       -np 4 numactl --cpunodebind=1 --membind=1 ./app
```

OpenMP 线程也可以精细绑定：

```bash
# 设置线程亲和性：线程 0-3 在 node 0，线程 4-7 在 node 1
export OMP_PLACES="{0:4},{1:4}"
export OMP_PROC_BIND=close
```

### 虚拟化场景

QEMU/KVM 可以指定虚拟机的 NUMA 拓扑：

```bash
# 创建虚拟机，分配两个虚拟 NUMA 节点
qemu-system-x86_64 \
  -numa node,nodeid=0,cpus=0-3,memdev=ram0 \
  -numa node,nodeid=1,cpus=4-7,memdev=ram1 \
  -object memory-backend-ram,id=ram0,size=8G,host-nodes=0,policy=bind \
  -object memory-backend-ram,id=ram1,size=8G,host-nodes=1,policy=bind
```

这样 Guest 内部的 NUMA 拓扑与 Host 物理拓扑对齐，Guest 内的 NUMA 感知应用可以做出正确的优化。

### 对比：NUMA 感知应用 vs 传统应用

| 类型 | 行为 | 性能影响 |
|------|------|---------|
| NUMA 感知（numa-aware）| 查询拓扑，按节点分配内存和线程 | 最优 |
| AutoNUMA 自动平衡 | 内核帮忙迁移 | 中等，有扫描开销和迁移延迟 |
| 完全不管 NUMA | 随机分配 | 最差，可能有 30%+ 远程访问 |

## 配置

### numactl 命令

`numactl` 是配置 NUMA 策略的主要用户态工具：

```bash
# 查看系统 NUMA 拓扑
numactl --hardware

# 查看当前进程的 NUMA 策略
numactl --show

# 查看某个进程的内存在各节点的分布
numastat -p <pid>

# 将进程绑定到 Node 0 的 CPU 和内存
numactl --cpunodebind=0 --membind=0 ./myapp

# 在所有节点间交错分配内存（CPU 不做限制）
numactl --interleave=all ./myapp

# 优先在 Node 0 分配，不够时溢出
numactl --preferred=0 ./myapp
```

#### 查看系统级 NUMA 统计

```bash
# 全局 NUMA 统计（按节点汇总）
numastat
# 输出示例:
#                            node0           node1
# numa_hit               120045678        95003456
# numa_miss                1023456         2034567
# numa_foreign             2034567         1023456
# interleave_hit              1234            1230
# local_node             118000000        92000000
# other_node               3056789         4034567
```

| 指标 | 含义 |
|------|------|
| `numa_hit` | 在预期节点分配成功 |
| `numa_miss` | 在预期节点分配失败，溢出到其他节点 |
| `numa_foreign` | 本节点的内存被其他节点分配走（本质是"被远程"） |
| `local_node` | 进程访问本节点内存的次数 |
| `other_node` | 进程访问远程节点内存的次数 |

**监控公式**：`other_node / (local_node + other_node)` 就是**远程访问比例**。如果这个值超过 20%，值得排查优化。

#### 进程级明细

```bash
# 按进程统计 NUMA 内存分布
numastat -p $(pidof mysqld)

# 或者
cat /proc/<pid>/numa_maps | head -20
```

### 内核启动参数

```bash
# 关闭 NUMA（降级为 UMA/SMP 模式）
numa=off

# 关闭自动 NUMA 平衡
numa_balancing=disable

# 在 /etc/default/grub 中:
GRUB_CMDLINE_LINUX="numa_balancing=disable"
```

```{note}
关闭 NUMA 不等于"解决 NUMA 问题"，只是把所有内存视为一个平坦空间。在硬件确实是 NUMA 架构时，关闭 NUMA 可能更糟——OS 不再感知节点边界，远程访问反而更多。只在极少场景下有收益（如整个系统内存刚好在一个 NUMA 节点的容量范围内）。
```

### numad 守护进程

`numad` 是一个用户态的 NUMA 守护进程，作为 AutoNUMA 的替代方案：

```bash
# 安装
yum install numad     # RHEL/CentOS
apt install numad     # Debian/Ubuntu

# 启动
systemctl enable --now numad

# 手动运行（不依赖 systemd）
numad -d
```

numad 的思路与 AutoNUMA 类似但有区别：

| 特性 | AutoNUMA（内核） | numad（用户态） |
|------|-----------------|----------------|
| 实现层 | 内核页表层，基于缺页 | 用户态，基于 `/proc/pid/numa_maps` |
| 粒度 | 页面级 | 进程级（将整个进程绑到某个节点） |
| 开销 | 持续的缺页制造和扫描 | 间歇性扫描，开销更低 |
| 适合场景 | 单进程的大内存应用 | 多进程混合负载 |

### systemd 的 NUMA 策略

systemd 可以在服务单元中直接设置 NUMA 策略：

```ini
# /etc/systemd/system/myapp.service
[Service]
ExecStart=/usr/bin/myapp

# 在所有节点间交错分配内存
NUMAPolicy=interleave
NUMAMask=all

# 或绑定到特定节点
# NUMAPolicy=bind
# NUMAMask=0-1
```

### 如何选择和验证 NUMA 优化策略

**诊断流程**：

```{mermaid}
flowchart TB
    START[发现应用性能瓶颈] --> CHECK{远程访问比例高?}
    CHECK -- 否 --> OTHER[排查其他性能问题]
    CHECK -- 是 --> APP_TYPE{应用类型?}
    APP_TYPE -- 单进程大内存<br/>数据库/缓存 --> BIND[方案A:<br/>numactl cpunodebind+membind<br/>将进程固定在一个节点]
    APP_TYPE -- 多线程共享<br/>大块内存 --> INTERLEAVE[方案B:<br/>numactl interleave=all<br/>交错分配消除热点]
    APP_TYPE -- 多独立进程 --> ONEPERNODE[方案C:<br/>每个进程绑定到不同节点<br/>配合进程级调度]
    BIND --> VERIFY[验证:<br/>numastat -p 查看<br/>other_node 是否下降]
    INTERLEAVE --> VERIFY
    ONEPERNODE --> VERIFY
    VERIFY --> BENCH[压测确认吞吐/时延改善]
```

**快速诊断命令**：

```bash
# 1. 查看当前远程访问状况
numastat

# 2. 查看关键进程内存分布
numastat -p $(pidof mysqld)

# 3. 查看每个 NUMA 节点的内存剩余量
numactl --hardware | grep "free"

# 4. 如果 Node 0 空闲内存很少但 Node 1 很多，
#    说明分配不均衡，可能需要 interleave
```

## 技术细节

### NUMA 距离的含义

`numactl --hardware` 输出的距离不是纳秒，是 ACPI SLIT（System Locality Information Table）表中的相对值，基准是 10（即本地访问代价为 10）。

Intel 通常的映射：

| 距离值 | 含义 |
|-------|------|
| 10 | 同一 NUMA 节点 |
| 11 | 同一 socket 内不同 NUMA 节点 |
| 12-14 | 同一 socket 内更远的 NUMA 节点 |
| 21 | 不同 socket（跨 QPI/UPI） |
| 32+ | 更复杂的多跳拓扑 |

```{note}
AMD EPYC 上距离 32 等同于走了"两跳"——先在本地 Infinity Fabric 上走一跳，再跨 Package。距离值直接反映硬件拓扑层次。
```

### 为什么大页（Huge Pages）与 NUMA 的关系很微妙

THP（Transparent Huge Pages）将一个 2MB 的大页视为一个整体：

1. 一个大页在 NUMA 上**只能位于一个节点**——2MB 数据全部在同一节点
2. AutoNUMA 迁移大页的成本更高——2MB 拷贝 vs 4KB 拷贝
3. 如果大页内的数据被不同节点的 CPU 各自访问一半，必有一半是远程访问

**影响**：如果你的应用有跨 NUMA 节点的多线程访问模式，THP 可能放大了 NUMA 远程访问的代价。

```bash
# 查看每个 NUMA 节点上的大页分配情况
cat /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
cat /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages

# 查看进程的大页使用
grep -E "anon_hugepage|kernel_hugepage" /proc/<pid>/smaps
```

### CPU 亲和性 vs 内存亲和性

很多同学只绑定内存、不绑定 CPU，这是不完整的：

```bash
# 只绑定内存（不完整）
numactl --membind=0 ./app
# 问题：内存固定在 Node 0，但进程线程可能被调度到 Node 1 的 CPU
# → 所有内存访问都变成远程访问！

# 完整绑定（推荐）
numactl --cpunodebind=0 --membind=0 ./app
# CPU 和内存都在 Node 0 → 全部是本地访问
```

`taskset` 可以绑定 CPU，但它绑的是**逻辑 CPU**，不关心 NUMA 节点边界：

```bash
# 绑定了 CPU 0-3，但如果 0-1 在 Node 0、2-3 在 Node 1...
taskset -c 0-3 ./app
# ...那么线程可能跨节点运行，内存访问模式变得不确定

# 更好的做法：用 numactl
numactl --cpunodebind=0 --membind=0 ./app
```

### 调度器的 NUMA 感知

Linux CFS 调度器有 NUMA 感知能力——它会尽量让一个进程的线程在同一个 NUMA 节点的 CPU 上运行，减少跨节点迁移。这正是 `/proc/sys/kernel/sched_*` 系列参数控制的。

关键参数：

```bash
# 调度域中 NUMA 拓扑感知的级别
cat /proc/sys/kernel/sched_domain/cpu*/domain*/flags | grep NUMA

# 调度器迁移的 NUMA 成本权重（数字越大，越不愿意跨 NUMA 迁移）
cat /sys/kernel/debug/sched/domains/cpu*/domain*/numa
```

这些参数通常不需要手动调整——除非你在做极端的高性能优化。

### 内存回收与 NUMA

当系统内存紧张时，内核的 kswapd 是**每个 NUMA 节点独立运行的**：

```
+-----------------+       +-----------------+
| kswapd0         |       | kswapd1         |
| (Node 0 回收)   |       | (Node 1 回收)   |
+--------+--------+       +--------+--------+
         |                         |
    Node 0 内存不足            Node 0 内存充足
    Node 1 内存充足            Node 1 内存不足
    → kswapd0 工作            → kswapd1 工作
    → kswapd1 空闲            → kswapd0 空闲
```

这意味着：**即使系统整体有空闲内存，单个 NUMA 节点内存不足时仍会触发本节点的内存回收**。这也是为什么：

1. 用 `numactl --interleave=all` 可以让内存压力均匀分布
2. 用 `numactl --membind=0` 可能让 Node 0 频繁回收而 Node 1 大量空闲

```{note}
`/proc/zoneinfo` 可以看到每个 NUMA 节点每个 zone 的详细信息，包括回收压力。如果发现某个节点的 `pages_scanned` 很高而其他节点很低，说明内存分布不均衡。
```

### NUMA 下的内存带宽

远程节点不仅时延高，**带宽也受限**。以典型双路 Xeon 为例：

```
Node 0 本地带宽:   ~120 GB/s
Node 0 → 1 带宽:   ~40 GB/s  (受 QPI/UPI 链路限制)
Node 1 本地带宽:   ~120 GB/s
总理论带宽:        ~240 GB/s
```

如果大量访问落在远程（比如 50% 远程访问），实际可用带宽远小于理论总和：

```
实际有效带宽 = 120 × 0.5 + 40 × 0.5 = 80 GB/s
利用率 = 80 / 240 = 33%
```

这也是为什么 NUMA 优化不当，"加内存"不一定能"加速"——新加的内存在另一个节点，访问它要付出远程代价。

### 总结

NUMA 优化的核心思想可以浓缩为一句话：

```{note}
**让数据靠近计算。** 如果一个进程主要在 Node 0 的 CPU 上运行，它的热数据就该在 Node 0 的内存中。方法有三种：手动绑定（最可控）、交错分配（最省心）、信任 AutoNUMA（最自动化）。选哪种取决于你对应用行为的理解程度和维护成本。
```

```
+---------------------------------------------------+
|                  NUMA 优化决策树                    |
|                                                   |
|  你能精细控制进程的 CPU 绑定吗？                     |
|       |                                           |
|   是  |  否                                        |
|       v       v                                   |
|  numactl   你的多线程共享一块大内存吗？              |
|  cpunodebind  |                                   |
|  +membind   是  |  否                              |
|              v       v                            |
|         interleave  AutoNUMA 或 numad              |
|         =all         (让内核/用户态守护进程         |
|                      自动处理)                    |
+---------------------------------------------------+
```

## 参考资料

- [Linux NUMA 文档](https://docs.kernel.org/admin-guide/numa.html)
- [numactl 手册](https://man7.org/linux/man-pages/man8/numactl.8.html)
- [AutoNUMA 设计文档](https://docs.kernel.org/mm/numa.html)
- [AMD EPYC NUMA 拓扑指南](https://developer.amd.com/resources/epyc-resources/)
- [MySQL 8.0 NUMA 支持](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_numa_interleave)
- [QEMU NUMA 配置](https://www.qemu.org/docs/master/system/qemu-manpage.html)

## 线上资源

```{toctree}
:maxdepth: 2
```
