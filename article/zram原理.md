# ZRAM 原理

ZRAM 是 Linux 内核中的一个模块，它在 RAM 中创建压缩的块设备。简单来说，ZRAM 就是**用 CPU 算力换取内存容量**——把本应占用物理内存的数据压缩存放，需要时再解压读取。

```{toctree}
:maxdepth: 2
```

## 概念

传统的块设备（如硬盘、SSD）以扇区为单位存取数据。ZRAM 则在内存中虚拟出一个块设备，数据写入时**先压缩再存入内存**，读取时**先解压再返回**。

```
+-------------------+
|    应用程序       |
+--------+----------+
         | 读写
+--------v----------+
|  ZRAM 块设备      |  /dev/zram0
|  (压缩层)         |
+--------+----------+
         | 压缩/解压
+--------v----------+
|   物理内存        |
|  (压缩后的数据)   |
+-------------------+
```

## 工作原理

### 压缩

ZRAM 把物理内存分成固定大小的"页"（通常是 4KB），每个页独立压缩：

并发的优势: ZRAM 的每个压缩操作都是针对单个内存页(4KB)进行的，且不同页之间没有任何关联。这意味着多个 CPU 核心可以同时压缩不同页，性能可以随 CPU 核心数线性扩展。这也是 ZRAM 在现代多核服务器上表现优异的原因之一。

```{mermaid}
flowchart LR
    A[写请求] --> B[接收内存页 4KB]
    B --> C[选择压缩算法]
    C --> D[压缩该页]
    D --> E{压缩后大小?}
    E -- 小于原页 --> F[存入压缩内存池]
    E -- 压缩比差 --> G[直接存原始数据]
```
> 图示: 一个内存页被送到 ZRAM 后，先压缩。如果压缩率不错就存压缩后的数据，否则放弃压缩（并非所有数据都能被有效压缩，比如已经压缩过的图片）。

压缩后的数据不是原地存放的，内核会维护一个映射表，记录:

1. 哪个逻辑扇区对应哪个物理内存位置
2. 压缩前的原始大小、压缩后的实际大小
3. 当前是否还能写入

**注意事项:** 存压缩数据的内存不是预分配的，而是动态分配的。因此 ZRAM 设备创建时声明的大小（如 8GB）是"解压后的数据最多 8GB"的意思，实际占用的物理内存远小于这个值。

### 压缩后的数据如何保存

ZRAM 背后依赖一个专门的内存分配器——**zsmalloc**，它负责管理所有压缩后大小不一的数据块。

#### 问题：碎片化

如果直接用内核的伙伴系统（buddy allocator）来存压缩后的数据，会产生严重的**内部碎片**。比如一个 4KB 页被压缩到 500 字节，如果分配一个完整的 4KB 物理页来存放，就浪费了 3.5KB。极端情况下压缩效果反而让内存占用更多。

zsmalloc 的思路是：**把多个压缩后的对象打包到同一个物理页里**。

#### zsmalloc 的结构

zsmalloc 将物理页组织为 **zspage**（一组连续的物理页），一个 zspage 内可以存放多个压缩对象：

```
+----------------------------------+
|          zspage (2个物理页)       |
|  +----------------------------+  |
|  | obj1 (512B) | obj2 (300B) |   |
|  +----------------------------+  |
|  | obj3 (1KB)      | obj4...  |   |
|  +----------------------------+  |
+----------------------------------+
```

```{mermaid}
flowchart TB
    subgraph "大小类 0 (32-48B)"
        ZP1[zspage<br/>存 ~80 个对象]
    end
    subgraph "大小类 5 (256-384B)"
        ZP2[zspage<br/>存 ~20 个对象]
    end
    subgraph "大小类 10 (2KB-3KB)"
        ZP3[zspage<br/>存 ~4 个对象]
    end
    ALLOC[zsmalloc 分配器] --> ZP1
    ALLOC --> ZP2
    ALLOC --> ZP3
```

> 图示: zsmalloc 按压缩后的大小把对象分到不同的"大小类"。同一类的对象大小相近，所以打包到一个 zspage 时浪费的空隙最少。

#### 大小类（size class）

zsmalloc 预先定义了若干"大小类"，每个类覆盖一个尺寸区间。当压缩后的数据需要存储时：

1. 算出压缩后数据的实际大小（比如 700 字节）
2. 找到能容纳它的最小大小类（比如 768-1024 这个类）
3. 从该类的某个 zspage 中分配一个槽位
4. 如果该类没有空闲槽位，申请新的物理页创建 zspage

这种按大小分类的策略类似于 slab 分配器，极大地减少了内部碎片。

#### 映射表：从扇区到压缩对象

ZRAM 在内核中维护一张映射表，每个逻辑扇区对应一条记录：

| 字段 | 含义 |
|------|------|
| handle (句柄) | 指向 zsmalloc 中压缩对象的指针 |
| stored_size | 压缩后的实际大小 |
| flags | 状态标记（全零页、写入中 等） |

```{note}
handle 并不是一个普通的内存指针。zsmalloc 用一个 32 位或 64 位的整数编码了对象所在的 zspage 和在页内的偏移量。这样 ZRAM 不需要关心对象具体被放在哪个物理页——只需要持有 handle，交给 zsmalloc 去定位即可。
```

#### 写入流程（完整版）

把之前的流程图展开到存储层面：

1. 应用写入一个 4KB 页
2. 压缩算法将其压缩为 N 字节
3. 检查 N 是否小于阈值（通常设为原页大小，即压缩必须有收益）
4. 若压缩无收益，直接存原始 4KB 数据（此时 stored_size = 4096）
5. 若压缩有收益，调用 zsmalloc 分配 N 字节的空间，把压缩后的数据拷贝进去
6. 将返回的 handle 和 stored_size 写入映射表

#### 释放与覆盖

当某个扇区被覆盖写入或不再需要时：

1. 查映射表拿到旧的 handle
2. 调用 zsmalloc 释放该对象（对应槽位标记为空闲）
3. 更新映射表指向新的 handle

释放的对象**不会立即归还给内核**——zsmalloc 保留这些空槽位，等下次分配时复用。只有当整个 zspage 上的所有对象都被释放后，该 zspage 的物理页才会归还给伙伴系统。

```{mermaid}
flowchart LR
    subgraph "写入前"
        ZP_OLD[zspage<br/>▇ objA ▇ ▇ objC ▇]
    end
    subgraph "释放 objA 后"
        ZP_FREE[zspage<br/>□ 空洞 □ ▇ objC ▇]
    end
    subgraph "写入 objD"
        ZP_NEW[zspage<br/>▇ objD ▇ ▇ objC ▇]
    end
    ZP_OLD --> ZP_FREE --> ZP_NEW
```

> 图示: objA 被释放后留下空洞，新写入的 objD 如果大小合适，就直接填入那个空洞。

#### 避免空洞：zspage 的分组管理

上面的机制有一个隐患：运行时间长了，可能出现大量 zspage 每个都只剩一两个对象——页面稀疏却占着整页物理内存。zsmalloc 通过**按填充率分组 + 对象迁移**来解决。

**三个队列**

每个大小类内部，zspage 按填充率分到三个链表：

```{mermaid}
flowchart LR
    subgraph ALMOST_EMPTY["almost_empty (几乎空了)"]
        AE[填充率 ≤ 25%]
    end
    subgraph ALMOST_FULL["almost_full (几乎满了)"]
        AF[填充率 ≥ 75%]
    end
    subgraph FULL["full (满了)"]
        F[填充率 = 100%]
    end
    ALLOC[新分配请求] --> AE
    ALLOC --> AF
    RELEASE[释放对象后] --> ALMOST_EMPTY
    RELEASE --> ALMOST_FULL
    RELEASE --> FULL
```

> 图示: 分配新对象优先从 almost_full 取，释放对象后 zspage 可能从 full 掉到 almost_full 或 almost_empty。

| 分组 | 填充率 | 定位 | 作用 |
|------|--------|------|------|
| almost_empty | ≤ 25% | `pages_almost_empty` | 搬迁候选——尽量把剩下的对象搬走，释放整页 |
| almost_full | ≥ 75% | `pages_almost_full` | 写入首选——还有空位，优先填充 |
| full | 100% | `pages_full` | 已满，不接受新写入，直到有对象被释放 |

普通填充率（25%~75%）的 zspage 不在任何特殊链表中，处于中间态。

**对象迁移（compaction）**

当 zsmalloc 发现某个大小类的 almost_empty 页太多时，触发压缩整理：

1. 扫描 almost_empty 链表，挑出一个"源 zspage"
2. 遍历该页中剩余的少量对象，在**同大小类**的 almost_full 页中找到空槽位
3. 把对象 memcpy 过去，更新 ZRAM 映射表中的 handle
4. 源 zspage 上所有对象都搬走后，整页归还给伙伴系统

```{mermaid}
flowchart TB
    subgraph BEFORE["迁移前"]
        AE_PAGE["almost_empty 页<br/>□ obj_X □ □ □ □"]
        AF_PAGE["almost_full 页<br/>▇ ▇ ▇ ▇ ▇ □"]
    end
    subgraph AFTER["迁移后"]
        AE_FREE["空页 → 归还内核"]
        AF_DONE["full 页<br/>▇ ▇ ▇ ▇ ▇ ▇"]
    end
    BEFORE -->|"memcpy obj_X"| AFTER
```

> 图示: obj_X 从稀疏页搬迁到有空位的 almost_full 页，稀疏页释放。

**为什么这件事重要**

如果没有这套机制，随着时间推移，会出现"每个页面都只剩 1 个对象"的尴尬局面——zspage 总数很高，但有效数据很少，内存被空洞白白浪费。有了迁移机制，zsmalloc 可以持续把碎片合并，让空闲页面真正归还给系统。

这也解释了为什么 `zramctl` 看到的 `mem_used_total` 会在系统空闲时缓慢下降——后台的 compaction 在回收稀疏页面。

#### 总结

ZRAM 的存储层 = **zsmalloc（防碎片打包器）+ 映射表（扇区→句柄的索引）**。压缩后的数据不是零散存放的，而是按大小分类、紧密打包在物理页中，这使得 ZRAM 的实际内存开销接近压缩后数据的总和，浪费极少。

### 读取与解压

读数据时:

1. 先查映射表，找到压缩后的数据在内存中的位置
2. 把数据解压到临时的页缓存中
3. 返回给调用方

如果发现要读的页根本不存在（全零页），ZRAM 会直接返回全零的数据，这个优化大幅减少了"已分配但从未使用"的内存浪费。

### 压缩算法的选择

ZRAM 支持多种压缩算法，选择标准通常是**压缩率 vs CPU 开销**:

| 算法 | 压缩率 | CPU 开销 | 适合场景 |
|------|--------|----------|----------|
| lzo / lzo-rle | 低 | 极低 | 低延迟要求的场景 |
| lz4 | 中低 | 低 | 通用场景，平衡之选 |
| zstd | 高 | 中 | 内存紧张、追求高压缩比 |

**实际配置**可以通过 `/sys/block/zram0/comp_algorithm` 查看和切换。

## 典型用途

### 作为 swap 设备

ZRAM 最常见的用法是把 `/dev/zram0` 格式化成 swap 设备。这比传统的磁盘 swap **快几个数量级**：

传统的 swap 是当物理内存不够用时，把不常用的页写入到磁盘上。而 ZRAM swap 则是在物理内存中划出一块区域存放压缩后的数据，完全不涉及硬盘 I/O。

**代价**是: 你的 CPU 需要花时间压缩/解压数据。但在现代的 CPU 上，这个开销通常远小于硬盘寻道的时间。

现代 Linux 发行版（如 Fedora、Ubuntu）默认就启用了 ZRAM swap。

### 作为临时文件系统

可以把 ZRAM 设备格式化为 ext4 或任何文件系统，当作一个超快的压缩 RAM 盘：

```bash
# 创建 zram 设备
echo 1 > /sys/class/zram-control/hot_add   # 返回设备号, 比如 zram0
echo 4G > /sys/block/zram0/disksize
mkfs.ext4 /dev/zram0
mount /dev/zram0 /mnt/zram
```

适合存放编译临时文件、日志等不需要持久化但需要快速读写的场景。

### 对比 zswap

两者都涉及内存压缩，但思路不同：

| 特性 | ZRAM | zswap |
|------|------|-------|
| 位置 | 纯内存中 | 内存 → 磁盘之间 |
| 是否涉及磁盘 I/O | 否 | 是（交换到磁盘上的存储池） |
| 配置复杂度 | 低 | 中 |
| 适用场景 | 没有磁盘 swap 或内存紧张 | 有磁盘 swap 且想减少 I/O |

简单来说: **ZRAM 在内存不够时压缩一部分数据，zswap 在往磁盘写 swap 时先压缩一次**。很多系统会同时使用两者。

## 配置

### 内核参数

创建 ZRAM 设备不需要手动编译内核，现代发行版的内核都内置了 `zram` 模块。

检查是否已加载：

```bash
lsmod | grep zram
```

如果没有加载：

```bash
modprobe zram
```

### 手动创建与启用

```bash
# 1. 创建一个 zram 设备
echo 1 > /sys/class/zram-control/hot_add
# 返回数字 N，则设备为 /dev/zramN

# 2. 设置大小（解压后的最大大小）
echo 8G > /sys/block/zram0/disksize

# 3. 选择压缩算法
echo zstd > /sys/block/zram0/comp_algorithm

# 4. 格式化为 swap
mkswap /dev/zram0
swapon /dev/zram0 -p 100   # -p 设置优先级, 数字越大越优先使用
```

### 监控

```bash
# 查看压缩统计
cat /sys/block/zram0/mm_stat
# 输出格式:
# orig_data_size compr_data_size mem_used_total mem_limit mem_used_max
# same_pages_pages(被识别为全零的页数) pages_compacted(压缩过的页数) huge_pages(大页数)

# 更易读的统计
zramctl
```

### 卸载 ZRAM 设备

```bash
# 如果用作 swap
swapoff /dev/zram0

# 释放设备
echo 1 > /sys/block/zram0/reset
```

### systemd 方式

`systemd` 提供了 `systemd-zram-setup@.service`，可以自动管理 ZRAM 设备:

```bash
# 创建一个 zram 设备
echo '[Swap]' > /etc/systemd/zram-generator.conf
echo 'zram-size = 4096' >> /etc/systemd/zram-generator.conf
echo 'compression-algorithm = zstd' >> /etc/systemd/zram-generator.conf

systemctl enable --now systemd-zram-setup@zram0.service
```

### 如何选择合适的压缩算法？

检查你的 CPU 支持哪些:

```bash
cat /sys/block/zram0/comp_algorithm
# 输出类似: lzo [lzo-rle] lz4 lz4hc 842 zstd
# 方括号内的是当前使用的算法
```

大多数 Fedora 版本默认使用 `lzo-rle` 算法，因为它的 CPU 开销极低，适合做频换的换入换出操作。

**建议:**
1. 新内核上使用 `zstd`（高压缩比+不错的性能）
2. 老系统上使用 `lz4`（快速+靠谱）
3. 如果是临时挂载的文件系统，也不需要特别高的压缩比，用 `lzo-rle`

## 技术细节

### 为什么 4KB

Linux 内核管理内存的基本单位就是 4KB（不考虑大页）。ZRAM 的压缩单元与内核的内存页一一对应，这样:

1. 换出时：直接把一个 4KB 页送给 ZRAM 压缩
2. 换入时：需要一个页大小的空间，ZRAM 就解压出一页来

不需要中间转换，减少了复杂度。

### ZRAM 创建的磁盘大小

ZRAM 初始化时，**并不是立即占用 `disksize` 大小的内存**。它只是声明"最多存这么多解压后的数据"。实际内存占用 = 压缩后的数据 + 元数据（映射表），通常在 `disksize` 的 1/3 到 1/2。

用 `zramctl` 可以看到当前的实际内存占用。

### 全零页识别

ZRAM 在写入每一页前会检查该页是否全是零。如果是全零页，不分配任何内存——映射表中标记为"全零"即可。很多应用分配了内存页但从未真正使用，这个优化能节省可观的物理内存。

```{note}
`/sys/block/zram0/mm_stat` 中的 `same_pages_present` 字段就是被识别为全零的页数。如果你的系统运行很多 Java 或 Node.js 应用（这些程序倾向于分配大块内存但未必全都使用），这个数字可能非常大。
```

### 内存不足时怎么办

极端情况下，ZRAM 本身也会被内核的 OOM killer 回收。但如果要写入的新数据无法压缩到可用内存空间，可能会发生死锁。好的做法是保守设置 `disksize`，确保它不超过物理内存的 200%。

### 现代桌面 Linux 的默认配置

大多数现代 Linux 发行版（Fedora 33+、Ubuntu 20.04+）默认启用了 ZRAM，通常配置为:
- 大小: 物理内存的 50%-100%
- 算法: lzo-rle（老发行版）或 lz4（新发行版）
- 优先级: 高于所有磁盘 swap（-p 100）

可以通过 `cat /proc/swaps` 查看当前活跃的 swap 设备及其优先级。

## 参考资料

- [Linux ZRAM 文档](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [systemd ZRAM 生成器](https://github.com/systemd/zram-generator)
- [Arch Wiki: ZRAM](https://wiki.archlinux.org/title/Zram)
- [Fedora ZRAM 默认启用说明](https://fedoraproject.org/wiki/Changes/ZRAM)

## 线上资源

```{toctree}
:maxdepth: 2
```
