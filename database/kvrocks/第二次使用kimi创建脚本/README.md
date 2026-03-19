==============================================
Kvrocks 高可用集群部署脚本生成完成
==============================================
目录位置: /home/wangx/github/linux-reference/database/kvrocks/第二次使用kimi创建脚本/kvrocks-ha-cluster

使用步骤：
1. cd /home/wangx/github/linux-reference/database/kvrocks/第二次使用kimi创建脚本/kvrocks-ha-cluster
2. ./start-all.sh          # 启动并初始化集群
3. ./monitor-cluster.sh    # 查看集群状态
4. ./test-failover.sh 1    # 测试节点1故障自动转移（观察节点4接管）
5. ./stop-all.sh           # 停止集群
6. ./destroy-all.sh        # 彻底删除（含数据）

故障转移机制：
- 当 kvrocks1/2/3 (主) 崩溃时，kvrocks4/5/6 (备) 自动接管为新的主节点
- 原主节点恢复后，可作为从节点重新加入集群
- 数据通过 RDB + AOF 持久化到 ./data/ 目录
==============================================
