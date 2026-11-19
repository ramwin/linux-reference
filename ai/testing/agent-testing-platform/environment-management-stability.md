# 环境管理系统的稳定性设计：清单要从「服务高可用」换成「环境可重复」

```{contents}
```

你现在这套方案——NGINX 自动负载均衡、web 容器化随时启停、灰度发布、Redis 集群主备热切换、数据库读写分离 + 副本容灾、Zabbix 盯 CPU/内存——是一份标准的**在线服务高可用清单**。它没有一条是错的，2026 年每一条都还成立。

但环境管理系统不是在线服务。它是「按需创建、短生命周期、高并发、跑完就该消失」的资源系统。拿在线服务的清单去兜它的稳定性，最常见的现场是：**控制面 99.99% 很稳，可环境创建失败率 8%、跑完不清理、同一个用力跑两次结果不一样。** 稳定性最痛的地方一项都没覆盖。

这篇做四件事：给你的清单做一次**前提审计**（这才是"知识更新"的正确做法，不是学新名词）；给出 2026 年各层的对应技术；列出环境系统还该考虑的 12 个设计；最后把上报链路这一层拆开讲——接口分级、流控、降级怎么落（第九节）。

## 一、先定位：环境系统在管两种完全不同的东西

在讨论技术之前必须把这句话说清，否则所有讨论都会混在一起：

| | 算力型环境 | 拓扑型环境 |
|---|---|---|
| 是什么 | 给 agent / 测试脚本执行用的沙箱、执行机 | 一套部署好、可打流量的被测系统（多服务 + 数据 + 配置） |
| 生命周期 | 分钟到小时，随任务 | 小时到天，随测试计划 |
| 数量级 | 几十到几百，高并发创建 | 几套到几十套 |
| 失败代价 | 任务失败、结果不可信 | 整套测试结论作废 |
| 稳定性第一指标 | 创建成功率、P95 创建时延、隔离不泄漏 | 环境一致性（可复现）、依赖不漂移 |
| 典型技术 | 容器 / microVM + 池化 + 配额 | 声明式部署 + 快照 / 一键重建 + 数据造数 |

**算力型怕争抢与泄漏，拓扑型怕漂移与不可重现。** 两条线上的技术选型、SLO、甚至值班方式都不一样。你的 Redis 集群、读写分离、NGINX 负载均衡，全都在回答"服务本身别挂"——而环境系统真正的稳定性风险，大部分不在这张清单上（见第三节）。

## 二、给你的清单做一次前提审计

上一篇[架构视野更新](./architecture-option-refresh.md)给的方法是：**更新知识不是学新名词，是给每个默认选择做一次前提审计**——它当年成立的前提是什么，现在还成立吗。下面逐条审计你这份清单，结论只有三种：保留、换掉、降级为可选。

| 你的方案 | 当年成立的前提 | 2026 年的变化 | 现在的常见答案 | 结论 |
|---|---|---|---|---|
| NGINX 自动负载均衡 | L7 入口靠某个控制器产品，选它最省事 | **ingress-nginx 官方 2025-11 宣布退休，2026-03 归档停止维护**（最后一版 `controller-v1.13.9`，此后无安全补丁）；入口已变成 API 标准，Gateway API v1.0 于 2023-10 GA，v1.6（2026-06）把 TCPRoute/UDPRoute 升入 Standard | K8s 内用 Gateway API（Envoy Gateway、Cilium）；裸机用 Caddy/Traefik；很多场景根本不需要 L7 LB，因为 web 层无状态、QPS 极低 | **换**（新项目别选 ingress-nginx） |
| web 服务容器化随时启停 | 部署单元是容器 | 容器只是"打包格式"，"随时启停"应该由编排器接管；手动重启等于绕过健康检查 | 编排器 + readiness/liveness + PodDisruptionBudget + 优雅退出 | **保留，但升级为编排器管** |
| 灰度发布 | 人工切流量、看监控、手动回滚 | 已变成声明式 + 指标驱动，自动判断成功/回滚；Argo Rollouts v1.10（2026-11）与 Flagger v1.45（2026-09）都活跃 | 发布策略写进 CRD，金丝雀指标不达标自动回滚 | **保留，升级为指标驱动** |
| Redis 集群主备热切换 | 缓存要横向扩到 TB 级，且买不到托管 | Redis 8 起提供 AGPLv3 选项，Valkey 9.x 双线推进，主流发行版已切 Valkey；**Cluster 解决的是分片，不是高可用**；Sentinel 才是主从热切换，默认 `down-after-milliseconds=30s`、`failover-timeout=180s`，真实切换 5–30 秒 | 数据放得进单机就用主从 + Sentinel 或托管多可用区；只有内存/写吞吐真不够才上 Cluster | **降级**（先 Sentinel，别把 Cluster 当 HA） |
| 数据库读写分离 | 读多写少、单机撑不住 | 先测量再分离已经成为共识：主库 CPU 持续 >70% 且读占比 >80% 才值得加只读副本；副本不加速单条慢查询，还引入复制延迟与"读己之写"问题；PgBouncer 只做池化，不解析 SQL、不做读写路由 | 单机 + PgBouncer/连接池 + 合理索引；真到瓶颈再加副本 | **降级为可选** |
| 副本容灾（duplicate） | 任何数据都不能丢 | 测试平台已经按 RPO/RTO 分级：用例库/golden 集 git 化，运行时状态可丢、可重放（见[架构篇 7.3](./architecture.md)） | 分级冗余；多活对测试平台几乎永远过度 | **保留，但按等级做** |
| Zabbix 看 CPU/内存 | 采集靠 agent、中心服务器轮询、主机/指标/触发器模型 | 采集与存储已经分层（exporter/collector + 时序库）；**判断"资源吃紧"的正确信号是 PSI 与 cgroup v2**，不是 CPU 使用率；Zabbix 8.0（2026-11，LTS）确实在补 OTLP/ClickHouse，但它的定位是**告警与事件中心**，不是云原生指标平面 | 采集：node_exporter + OTel Collector / Grafana Alloy；存储：Prometheus 3.x 或 VictoriaMetrics；资源压力：`/proc/pressure/*` + cgroup v2 | **降级为告警层**（指标面换掉） |

一句话总结这张表：**你的清单里没有一条是"过时"的，但有四条的前提已经变了。** 而前提变了还照着用，才是"知识没更新"的真实形态——不是你不会说新名词，是你把旧前提下的答案当成了默认答案。

## 三、环境系统真正的稳定性风险排序

按"出问题的概率 × 对结论可信度的伤害"排，环境系统的风险长这样：

| 排序 | 风险 | 为什么会发生 | 对策 |
|---|---|---|---|
| 1 | 控制面与数据面耦合 | 环境创建请求和 agent 执行抢同一批资源；一次批量创建把 API server / 调度器拖死 | 控制面独立节点池；创建走队列 + 准入控制；控制面挂了不影响在跑的环境 |
| 2 | 资源超卖与 noisy neighbor | CPU 超卖、内存只有 limit 没有软限，一个环境的编译把同节点其他环境拖慢，测试**随机**变慢变红 | cgroup v2 + 按绝对核数分配；`memory.high` 软限 + PSI 监控；禁止靠 CPU 使用率判断 |
| 3 | 环境漂移、不可重现 | `image: latest`、运行时 `apt install`、依赖外网下载、本地写状态 | 镜像固定 digest；启动时算"环境指纹"写进报告；构建期装依赖 |
| 4 | 环境泄漏、孤儿堆积 | 任务失败/超时/被取消后没人回收；一周后池子满了，"平台自己把自己撑死" | 租约 TTL + 定期 GC + 所有权标记；回收失败要告警 |
| 5 | 发布与在跑环境耦合 | 升级平台/宿主内核/CNI 时，把正在跑的环境一起重启 | 控制面蓝绿、数据面排水（drain）后再升级；环境版本可回滚（digest pin） |
| 6 | 数据面单点 | 对象存储或数据库挂了，环境起不来、结果传不上 | 用托管/成熟组件，不要自研；工件写对象存储，元数据进 PG |
| 7 | 冷启动太慢导致"假失败" | 镜像拉取、依赖下载超过任务超时，被当成用例失败 | 预热池 + 分层镜像 + 本地 registry 缓存；冷启动时延单独做 SLO |

注意第 7 条：**在测试平台里，"环境的慢"经常伪装成"被测系统的错"**。这就是为什么环境系统的稳定性指标必须是"创建成功率 + 就绪时延 + 失败归因"，而不是"服务可用性 99.99%"。

## 四、2026 年各层的对应技术

只列有明确版本/状态的事实，不堆名词。判断标准永远是"你的规模和团队能不能驾驭"。

| 层 | 你原来的选择 | 2026 年的选择（附状态） | 什么时候别用 |
|---|---|---|---|
| 入口 / L7 | NGINX Ingress | Gateway API v1.0+（2023-10 GA）；实现：Envoy Gateway v1.10（2026-11）、Cilium（CNCF Graduated，v1.20） | 只有一两台机器、几个服务时，Caddy/Traefik 或云 LB 就够 |
| 编排与调度 | Docker + 手工启停 | K8s v1.37（2026-08）稳定线；批任务配额/排队用 Kueue v0.20（kubernetes-sigs，**不是 CNCF 项目**）；gang scheduling 与公平共享用 Volcano v1.16（CNCF Incubating） | 单机、<20 环境、没人会运维 K8s 时，k3s/k0s 甚至 compose 更稳 |
| 隔离 | 容器（runc） | 可信负载 runc 就够；不可信/高密度：Firecracker v1.18、Kata 4.3（RuntimeClass 接入）、gVisor（周更）；需要完整 OS + 快照回滚：KubeVirt v1.9 | 隔离需求没到"不可信代码"级别，上 microVM 只是给自己加运维 |
| 发布 | 自研灰度 | Argo Rollouts v1.10 / Flagger v1.45，指标驱动自动回滚 | 只有单实例时，蓝绿一台机器更快 |
| 队列（控制面） | 直接用 Redis 当队列 | 小规模：PostgreSQL `SKIP LOCKED` 或 pgmq 1.13；中规模：NATS JetStream 2.15（CNCF Graduated） | 每秒几百到几千以内，Kafka 是负收益；Kafka 4.4 只在需要重放/多消费方时上 |
| 元数据 / 状态 | MySQL + 读写分离 | PostgreSQL 18 + Patroni 4.1 或 CloudNativePG 1.30（CNCF Incubating，2026-11）；向量用 pgvector 0.8，定时清理用 pg_cron | 单机够用时别上集群；读写分离先测量 |
| 缓存 / 会话 | Redis Cluster 主备 | Redis 8（AGPLv3 可选）或 Valkey 9.1；主从 + Sentinel；托管多可用区 | 把"会话/锁/队列/缓存"全塞进 Redis 时，先问问哪些该外置 |
| 对象存储（工件、快照、日志） | 本地盘 / 自建 | **MinIO 社区版 2025 起删管理功能、停发 Docker 镜像与二进制、进 maintenance 模式**，新部署别选它；替代：SeaweedFS 4.54（Apache-2.0）、Garage 2.5（无 versioning）、Ceph/Rook（S3 最完整但重） | 小团队别为了 S3 上 Ceph；能有云对象存储就先用 |
| 指标 | Zabbix agent | node_exporter 1.13 + Prometheus 3.16 或 VictoriaMetrics 1.156（单机版官方定位 <100 万 samples/s） | 指标量很小、只想要告警时，Zabbix 继续用没问题 |
| 资源压力真相 | CPU 使用率 | **PSI**（`/proc/pressure/{cpu,memory,io}` + cgroup v2），K8s 1.36 起 `KubeletPSI` 稳定 | 老内核（<4.20）没有 PSI，只能退回使用率 |
| 链路与 eBPF | 无 / 抓包 | OTel Collector core 1.71；Cilium Hubble（L3–L7 flow）；Tetragon 1.8（运行时安全）；零代码埋点走 **OTel OBI v1.0**（Beyla 已捐给 OTel）；Pixie 最后正式版停在 2025-01，别当新项目主力 | profiles 信号在 OTel 里仍是 Alpha，持续 profiling 用 Pyroscope/Parca |
| GPU | 无 | dcgm-exporter 4.9 + MIG（硬件级隔离；time-slicing 无显存隔离，NVIDIA 明确不保证算力比例）；DRA 已 GA 但 NVIDIA DRA driver 仍 0.x | 只有开发机式共享时用 time-slicing |
| 混沌 | 无 | Chaos Mesh / LitmusChaos，或自写故障注入脚本 | 没有任何 SLO 的早期系统，先补指标再谈混沌 |

## 五、还能考虑哪些设计（按稳定性收益排序）

这 12 条里，前 6 条是环境系统独有的，后 6 条是"你的清单之外的加固"。

**1. 环境即代码 + 不可变镜像。** 环境定义（compose/Helm/K8s YAML）进 git，镜像用 digest 而不是 tag，运行时不装依赖。收益：环境可重建、可审计、可回滚。最小实现：CI 里 `docker build --pull` 后把 digest 写进部署清单。

**2. 环境指纹进报告。** 启动时算一个 hash（镜像 digest + 环境变量 + 内核/CNI 版本 + 数据快照 id），写进测试报告的 header。收益：**同一个用例两次结果不同时，能立刻判断是不是环境变了**——这是测试平台可信度的地基。最小实现：启动脚本 `sha256sum` 一堆东西，塞进 `env_fingerprint` 字段。

**3. 预热池 + 租约 TTL。** 常驻 N 个已就绪环境，领取即用；租约到期自动回收。收益：把 P95 创建时延从分钟压到秒，同时天然解决泄漏。最小实现：池子 + `expires_at` 字段 + 定时 GC 任务。

**4. 准入控制与配额。** 按 CPU/内存/GPU 而不是"任务数"限流；超载时**排队或拒绝**，不要拖垮。收益：避免一次批量提交把整个平台打死。最小实现：Kueue（K8s）或自研令牌桶 + 队列深度告警。

**5. 控制面 / 数据面分离。** 管理 API、调度器、数据库放独立节点池（甚至独立小集群）；执行环境的节点池可以随时扩容、随时排水。收益：环境爆炸不会拖死管理面，管理面升级不影响在跑环境。

**6. 幂等 + 可重入 + 失败归因。** 创建/销毁接口幂等；任务失败必须能归到三类之一：**环境故障 / 平台故障 / 被测缺陷**。收益：直接决定"测试红了到底要不要开发修"。最小实现：失败分类字段 + 分诊规则，报告里必带。

**7. 资源隔离用硬约束。** CPU 给绝对核数（cpuset），内存给 `memory.high` 软限 + `memory.max` 硬限，IO 用 `io.max`；PSI 超过阈值就迁移或告警。收益：消灭"随机慢"。

**8. 自愈与自清理。** watchdog 定期检查：环境无 owner、租约过期、进程僵死、磁盘占用 >90% → 自动处理并记录。收益：把"平台慢慢烂掉"变成"平台自己修自己"。

**9. 混沌演练常态化。** 定期故意杀容器、断网、填满磁盘、杀掉控制面一个副本，验证自愈。收益：**"稳定性最重要"这句话，只有混沌演练能证明**。最小实现：每周一次夜间演练 + 记录恢复时间。

**10. 快照与回滚，但要挑对工具。** VM 级快照（KubeVirt `VirtualMachineSnapshot`）恢复需要停机；K8s 容器 checkpoint（KEP-2008）目前是 beta 且**没有 in-tree restore**，Pod 级 checkpoint/restore 还是 alpha。收益：拓扑型环境"造好一套、测多次、坏了回滚"。结论：环境快照优先用"镜像 + 数据快照"重建，别指望进程级 checkpoint。

**11. 分级 SLO，别一律当生产伺候。** 给环境分三档：P0（关键回归环境，多副本 + 秒级重建）、P1（常规测试，分钟级重建）、P2（临时实验，可丢）。收益：成本降一半，稳定性反而更清楚。**不是所有环境都值得 SLO。**

**12. 成本与稳定性一起算账。** spot/抢占式节点 + 抢占感知（被回收前保存工件）+ 低优先级环境可被驱逐。收益：同样的钱买到更多并发；但必须保证被抢占的环境可重建，否则稳定性反而降。

## 六、三档落地方案

| | 方案 A：单机 Docker + systemd | 方案 B：k3s + 池化 + 配额（推荐） | 方案 C：完整 K8s + microVM + 多集群 |
|---|---|---|---|
| 适用规模 | <20 并发环境，1–2 人维护 | 20–200 并发环境，3–5 人 | 200+ 并发、多租户、跑不可信代码 |
| 编排 | docker compose / systemd | k3s（单二进制，CNCF Sandbox）或 k0s | K8s 1.37 + Kueue/Volcano 调度 |
| 隔离 | 容器（可信负载） | 容器 + RuntimeClass 可选 gVisor | Kata/Firecracker microVM |
| 入口 | Caddy/Traefik | Gateway API（Envoy Gateway / Cilium） | 多集群 + 全局入口 |
| 状态 | 单机 PG + 每日备份 | PG + Patroni/CNPG，对象存储 | 分级冗余 + 多可用区 |
| 监控 | node_exporter + VictoriaMetrics 单机 | 同上 + OTel Collector + PSI 告警 | 全链路 + eBPF + 持续 profiling |
| 利 | 简单，故障面小，一个人能兜 | 生态齐全（配额、快照、Gateway API），运维量可控 | 隔离强、可多租户、可扩到千级 |
| 弊 | 扩不动；手工运维易漂移 | 要学 K8s 与 operator；组件多 | 运维成本数倍；需要专职平台工程 |
| 失败模式 | 环境泄漏、资源争抢 | 控制面与数据面耦合、配额配错 | 复杂度本身成为稳定性风险 |

**建议：从 B 起步，按需加 C 的能力，顺序固定为「先配额 → 再池化 → 再 microVM → 最后 KubeVirt」。**

理由很直接：你的团队 3–5 人、内网环境、只跑内部模型，B 的生态（Gateway API、Kueue 配额、快照、OTel）刚好覆盖你清单之外那 12 条设计的大部分，而 A 会很快在并发和隔离上撞墙。C 单独上，复杂度会先于规模到来——你今天真正缺的不是"更先进的编排"，是**配额、池化、指纹、归因**这四件小事。

## 七、"稳定性最重要"的四条验收指标

别用"服务可用性 99.99%"验收环境系统，用这四条：

| 指标 | 目标（参考） | 它回答什么问题 |
|---|---|---|
| 环境创建成功率 | ≥99%（按任务类型分桶） | 平台自己靠不靠得住 |
| 创建 P95 时延 / 就绪时延 | 预热池命中 <30s，冷启动 <3min | 慢是不是被误判成被测缺陷 |
| 孤儿环境残留 | 租约过期 1 小时内回收率 100% | 平台会不会自己把自己撑死 |
| 失败归因准确率 | 抽样复核 ≥95% | 测试红了到底该谁修 |

再补一条成本指标：**每个环境-小时的成本**。它决定了你该不该上 spot、该不该给环境分级。

## 八、30 天更新这套知识

| 时间 | 动作 | 产出 |
|---|---|---|
| 第 1 周 | 给上面 7 条清单逐条做前提审计，写成你自己的版本（带"我的规模下是否仍成立"） | 一页前提审计表 |
| 第 1 周 | 把当前环境系统的失败案例捞 20 条，按环境故障/平台故障/被测缺陷分类 | 一张失败归因表 |
| 第 2 周 | 先做配额 + 租约 GC（两项加起来通常 <200 行） | 配额与回收上线 |
| 第 3 周 | 接入 PSI + 环境指纹 | 两张新面板 / 报告新增字段 |
| 第 4 周 | 做一次混沌演练（杀容器 + 填盘），记录恢复时间 | 一篇演练记录，写进[平台 reviews](./reviews/README.md) |

## 九、上报链路：接口分级、流控与降级

你的思路——接口分级 + 流控 + 压力大时降频丢弃——方向是对的，而且是环境系统里最容易被低估的一块。但它其实是**最后一档**手段，前面还有两档更便宜的做法。原因在数字里。

### 9.1 先把数算清：10,000 台是什么量级

100 个环境 × 100 台 = 10,000 台。

- 每台每分钟上报一次 → **166.7 QPS**（是"每秒 167 个请求"，不是"每分钟处理一台"）；
- 每包 10 KB → 1.7 MB/s ≈ 13 Mbps，带宽根本不是瓶颈；
- 假设每台每次带 100 个指标点 → **每分钟 100 万点、每秒 1.67 万点写库**，这才是真瓶颈；
- 若单个请求处理耗时 200ms → 正常在途并发约 33（`并发 = 到达率 × 停留时间`）。

降频到 5 分钟时，两种做法差别很大：

| 做法 | 入口 QPS | 写库点数/秒 | 实际省下的 |
|---|---|---|---|
| 只在服务端丢 4/5 | 仍 166.7 | 3,333 | 只省了写库与下游处理 |
| 让 agent 真降频 | 33.3 | 3,333 | 连接、TLS、解析、写库全省 |

**开销的大头在前几跳（连接、反序列化），最后一跳才是写库。** 所以"请求发上来再丢掉"，省下的和付出的经常是同一量级——这也是为什么它该是最后一档。

### 9.2 三档机制，从便宜到贵

| 档 | 做法 | 改哪里 | 省下什么 | 数据代价 | 什么时候用 |
|---|---|---|---|---|---|
| A | **源头降频**：服务端下发采集策略，agent 按新周期上报 | agent 支持动态配置 | 全链路 | 分辨率下降，不丢历史 | 首选 |
| B | **网关拒绝 + 退避**：429 + `Retry-After`，agent 本地缓存后合并补传 | 网关 + agent 缓存 | 应用层 | 延迟，不丢数据 | agent 改不动，但能升级 |
| C | **服务端采样丢弃**：按比例丢，带 `reason` 标签 | 处理端 | 下游 | 真的丢 | 必须保护 DB 且数据可丢 |

**优先 A，其次 B，C 只在"下游会死、数据又允许丢"时用。** 注意 B 比 C 好的地方：请求被拒绝后 agent 可以把数据攒起来下次合并上报，数据不丢；而 C 是静默丢失，事后没人知道丢了什么。

### 9.3 指标用拉取模型：天然支持"降频但不丢数"

如果你采的是**指标**，根本不必发明降频协议——**服务端主动拉**（Prometheus scrape、或每个环境部署一个 OTel Collector 由中心拉取）时，`scrape_interval` 从 60s 改成 300s 就是降频，而且**不丢数据**：服务端不拉，agent 不用发包；下次拉到的是最新状态，历史趋势仍然连续。

- **指标 → 拉**，降频是改配置，不是丢请求；
- **日志 / 事件 / 告警 → 推**，因为事件发生过就该被记录，只能批量 + 压缩 + 补传；
- **更根本的优化是边缘聚合**：每个环境一个 collector，100 台机器 → 1 个连接，10,000 → 100。这是数量级的优化，比任何限流都管用。

### 9.4 分级要按"可丢性 + 谁在等"分，不按接口名分

| 数据类别 | 时效要求 | 可丢性 | 降级手段 | 恢复方式 |
|---|---|---|---|---|
| 心跳 / 存活 | 秒级 | **不可丢** | 独立通道，周期不变，只压缩 payload | 自动 |
| 告警 / 故障事件 | 秒级 | **不可丢** | 全量，可延迟不可丢，本地排队 | 补传 |
| 状态变更（部署/重启/异常） | 秒级 | **不可丢** | 同上 | 补传 |
| 指标 | 秒到分钟 | 可采样 | 降频 + 降维（砍高基数 label） | 自动恢复 |
| 普通日志 | 分钟 | 可大比例采样 | 采样 1%–10% | 自动 |
| 错误日志 | 分钟 | 尽量不丢 | 单独通道，优先于普通日志 | 补传 |
| 追踪 span | 请求级 | 可采样 | 头部/尾部采样 | 自动 |
| 审计 / 计费 | — | **不可丢** | 只延迟不丢；拒绝即违规 | 补传 + 核对 |
| 人触发的查询/大盘 | 即时 | 不可丢（体验） | 排队 + 429 提示 | 立即 |

一条判据就够用：**"这条数据丢了，谁会在什么时候疼？"** 答不上"不会疼"的，都不能丢。你的例子里，"第 2–4 分钟的数据"如果只是利用率采样，丢了不疼；但如果是"第 3 分钟机器宕机"这条事件，丢了就是事故——**所以降级必须按通道生效，不能按时间一刀切。**

### 9.5 流控算法怎么选，"上限"怎么定

| 算法 | 防的是什么 | 放在哪层 | 坑 |
|---|---|---|---|
| 令牌桶 / 漏桶 | 入口突发流量 | 网关，按租户/接口等级 | 单机桶算的是单机总量；集群要全局配额或近似 |
| 并发信号量 | 下游资源（DB 连接、线程、文件句柄） | 应用层 | 与 QPS 混淆；长请求会把并发占满 |
| 自适应并发 | 不知道真实容量时 | 保护下游 | 依赖延迟样本质量；冷启动会误判 |
| 队列过期丢弃 | 排队过久、做了也没意义 | 处理端 | 要丢最旧的，不是最新的；必须带原因 |
| 分级队列 + 权重 | 一个租户/环境打满公共通道 | 调度层 | 权重需要人定期校准 |

**"请求数不能高于多少"这个数不能拍脑袋。** 两种定法：用 `并发 = 到达率 × 停留时间` 从时延预算反推；或者压测找拐点。而且上限要**按最紧的下游定**（数据库连接数、CPU 核数、provider 限流），不是按入口定——入口限得再漂亮，下游先死一样是事故。

### 9.6 三档降级档位（可直接抄）

| 档位 | 触发条件 | 指标周期 | 指标采样 | 日志 | 目标入口 QPS |
|---|---|---|---|---|---|
| 正常 | — | 60s | 100% | 10% | 167 |
| 降级 | 入口 CPU >70% 或队列深度 >1k 持续 1 分钟 | 300s | 20% | 1%，仅 error+告警全量 | 33 |
| 兜底 | 写库 P95 超时 或 DB 连接池 >90% 持续 2 分钟 | 900s | 5% | 0.1%，仅 error+告警 | 11 |

服务端下发给 agent 的策略长这样（agent 只执行，不自己判断）：

```json
{
  "mode": "degraded",
  "reason": "ingest_overload",
  "ttl_seconds": 1800,
  "channels": {
    "heartbeat": {"interval_s": 30, "drop": false},
    "alerts":    {"drop": false, "buffer_on_failure": true},
    "metrics":   {"interval_s": 300, "jitter_s": 30, "sample_ratio": 0.2},
    "logs":      {"sample_ratio": 0.01, "only_error": true},
    "traces":    {"sample_ratio": 0.01}
  }
}
```

三个字段是关键：`ttl_seconds`（降级不会永久卡住）、`reason`（事后能解释数据为什么稀）、**通道级独立**（心跳和告警永远不降）。

### 9.7 六个必须提前想的坑

1. **同秒尖峰。** 所有机器 cron 在同一秒上报 → 平时 167 QPS，整点瞬间 10,000。用 `jitter_s` + 按 `machine_id` 稳定哈希错峰。
2. **监控图失真。** 降频后 1 分钟分桶里 4 个是空的：填 0 会被误判成宕机，last-value 会画出一条假平线掩盖故障。正解是**分桶窗口 ≥ 采集周期**，并显式标"降级中"。
3. **降级期间 MTTR 变长。** 故障从 1 分钟发现变成 5 分钟发现。这是降级的**真实代价**，要写进 SLO 说明；并且故障通道永远不降级。
4. **恢复洪峰。** 降级解除时，积压 + 补传一起放出来会把系统二次打挂。恢复期必须继续限速、渐进放行。
5. **采样偏差。** 真随机丢会导致"同一台机器反复缺席"，定位时对不上号。用稳定哈希保证可复现。
6. **公平性。** 一个环境的 100 台把公共通道占满，别的环境就全哑了。按环境/租户配额，再谈全局限流。

### 9.8 上线前问自己五句话

- 这条数据丢了，谁会在什么时候疼？
- 这次降级，事后能从指标里看出来吗（有 `reason` 标签吗）？
- 降级开关谁有权按？自动还是人工？凌晨三点有人敢按吗？
- 恢复需要多久？恢复时会不会二次打挂？
- 降级期间，真正的故障还能被发现吗？

## 十、参考资料（核查于 2026-11-19）

- ingress-nginx 退休公告（2025-11-11）：<https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/>；仓库归档与末版 `controller-v1.13.9`：<https://github.com/kubernetes/ingress-nginx>
- Gateway API v1.0 GA（2023-10-31）：<https://kubernetes.io/blog/2023/10/31/gateway-api-ga/>；v1.6（2026-06-30）：<https://kubernetes.io/blog/2026/08/03/gateway-api-v1-6-release/>
- Envoy Gateway v1.10.0（2026-11-06）：<https://github.com/envoyproxy/gateway/releases/tag/v1.10.0>
- Cilium 1.20 与 CNCF Graduated：<https://github.com/cilium/cilium/releases/tag/v1.20.0>
- K8s v1.37 发布（2026-08-26）：<https://kubernetes.io/blog/2026/08/26/kubernetes-v1-37-release/>
- DRA：v1.34 博客 <https://kubernetes.io/blog/2025/09/01/kubernetes-v1-34-dra-updates/> 与概念页（标注 v1.35 GA）<https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/>，**官方文档口径不一致，但"已 GA"无争议**
- Kueue v0.20.6（2026-11-12）：<https://github.com/kubernetes-sigs/kueue/releases/tag/v0.20.6>
- Volcano v1.16（2026-10）：<https://www.cncf.io/blog/2026/10/28/volcano-v1-16-released-namespacequeue-fairshare-and-a-broader-hypernode-ecosystem/>
- Firecracker v1.18.0（2026-11-09）：<https://github.com/firecracker-microvm/firecracker/releases/tag/v1.18.0>
- Kata 4.3（2026-10）：<https://github.com/kata-containers/kata-containers/blob/main/docs/releases/4.3.0.md>
- KubeVirt v1.9.0（2026-07-30）与快照恢复需停机：<https://kubevirt.io/user-guide/storage/snapshot_restore_api/>
- 容器 checkpoint KEP-2008（beta，无 in-tree restore）：<https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/2008-forensic-container-checkpointing>
- Argo Rollouts v1.10.2（2026-11-04）：<https://github.com/argoproj/argo-rollouts/releases/tag/v1.10.2>；Flagger CHANGELOG v1.45.0：<https://github.com/fluxcd/flagger/blob/main/CHANGELOG.md>
- Prometheus 3.16（2026-11-04）：<https://prometheus.io/download/>；VictoriaMetrics 单机版定位：<https://docs.victoriametrics.com/victoriametrics/cluster-victoriametrics/>
- PSI 内核文档：<https://www.kernel.org/doc/html/latest/accounting/psi.html>；K8s PSI 指标：<https://kubernetes.io/docs/reference/instrumentation/understand-psi-metrics/>
- OTel Collector core 1.71 与 signals status（profiles 仍 development）：<https://opentelemetry.io/docs/specs/status/>
- OTel eBPF Instrumentation（OBI）v1.0.0（2026-10-30）：<https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation>
- dcgm-exporter 4.9（2026-11-06）与 time-slicing 不保证算力：<https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html>
- Zabbix 8.0 LTS（2026-11-05）：<https://www.zabbix.com/release_notes>
- Redis AGPLv3 公告（2025-05-01）：<https://redis.io/blog/agplv3/>；Sentinel 默认超时：<https://github.com/redis/redis/blob/8.10/sentinel.conf>
- Valkey 9.1.4（2026-11-18）：<https://valkey.io/download/releases/>
- NATS Server 2.15（2026-09-17）：<https://nats.io/blog/nats-server-2.15-release/>
- Patroni 4.1.5：<https://patroni.readthedocs.io/en/latest/releases.html>；CloudNativePG 进入 CNCF Incubating（2026-11-10）：<https://www.cncf.io/blog/2026/11/10/cloudnativepg-becomes-a-cncf-incubating-project/>
- 只读副本何时才需要（Supabase 经验阈值，转引）：<https://www.prisma.io/postgres/do-i-need-a-read-replica>；PgBouncer 不做路由：<https://www.pgbouncer.org/faq.html>
- MinIO maintenance mode 与社区版功能移除：<https://github.com/minio/minio>；SeaweedFS 4.54：<https://github.com/seaweedfs/seaweedfs/releases/tag/4.54>；Garage 2.5 与 S3 兼容范围：<https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/>
- SRE Book 第 21 章「Handling Overload」（客户端自适应限流）：<https://sre.google/sre-book/handling-overload/>
- SRE Workbook「Identifying and Recovering from Overload」：<https://sre.google/workbook/overload/>
- Envoy 自适应并发过滤器：<https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/adaptive_concurrency_filter>
- Envoy 本地限流（令牌桶）：<https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/local_rate_limit_filter>
- Netflix concurrency-limits（梯度自适应并发）：<https://github.com/Netflix/concurrency-limits>
- pgmq 1.13.2（2026-11-18）：<https://github.com/pgmq/pgmq/releases/tag/v1.13.2>；pgvector 0.8.7：<https://github.com/pgvector/pgvector>

## 版本记录

| 版本 | 日期 | 使用模型 | 说明 |
|---|---|---|---|
| v1 | 2026-11-19 | deepseek-flash（DSH） | 初稿：两类环境区分、7 条清单前提审计、7 条风险排序、分层技术对应表（2026-11 核查）、12 条设计、三档方案、四条验收指标、30 天路线 |
| v2 | 2026-11-19 | deepseek-flash（DSH） | 新增第九节：上报链路的接口分级、流控与降级（10,000 台算例、三档机制、pull 模型与边缘聚合、数据分级表、流控算法选型、降级档位与下发 JSON、六个坑） |

本次消耗：本会话累计约 92 万 tokens（输入 4.1 万、输出 2.2 万、缓存命中 86.1 万），含三路子 agent 的事实核查。

事实核查由三个子 agent 并行完成（K8s/发布、可观测性、数据层），每条技术结论均带官方链接与版本日期；文中未核实项已在参考资料里标注口径差异（DRA 的 GA 版本）。
