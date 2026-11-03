# AI 批量产 MR 后冲突不断：怎么减少合并冲突

```{contents}
```

用 AI 开发之后 MR 出得快、排得多，但检视还是老节奏，MR 在队列里一挂几天，合进去一个，剩下的一排全部要 rebase 修冲突。问题不在 git，而在一条简单公式：

> **冲突次数 ≈ MR 之间的代码重叠面积 × MR 的存活时间（排队时长）**

所以所有手段只有两类：**压重叠面积**（拆小、按模块分地）、**压存活时间**（检视提速、合入串行化）。再加一类兜底：**冲突自动消化**（自动 rebase、AI 解冲突），让不可避免的冲突不再占人的时间。下面按改造成本从低到高给六档，文末有对比表和建议。

## 一、先把存量纪律立住：小 MR + 高频 rebase（零成本）

最有效的两件事不需要任何平台改造：

**1. MR 粒度砍半再砍半。** 一个 800 行的 MR 和四个 200 行的 MR，冲突期望不是四倍关系——后者存活时间短（好检视、秒批）、重叠面积小（每个只碰一小块）。给 AI 的任务里直接写明"一个 MR 不超过 300 行 diff，超了就拆"。

**2. 提交前、检视中每天都 rebase 主干。** 不要让分支游离超过一天：

```bash
# ~/.gitconfig 加一个别名，每天开工先跑一次
[alias]
    sync = !git fetch origin && git rebase origin/master
```

冲突在刚引入时只有几行，三天后就长成几十行。rebase 越勤，单次冲突越小，AI 也越容易自动修。

## 二、派任务时就按模块分地（低成本）

冲突的根源是多个 MR 改同一批文件。给多个 AI agent 派活时，把"文件归属"写进任务书，而不是让它们自由发挥：

```markdown
## 任务分工（同一轮并行）
| MR | 分支 | 允许改动的目录 | 禁止改动 |
|----|------|--------------|---------|
| #101 | feat/login-rate-limit | auth/ | 其他一律不动 |
| #102 | feat/report-export | report/, api/report.py | auth/、公共 utils |
| #103 | chore/deps-upgrade | requirements*.txt, lock 文件 | 任何源码 |

公共文件（utils/、models/）如需改动，单独开一个小 MR 先合入，再各自 rebase。
```

公共依赖（基类、公共工具、数据库迁移）最容易撞车，**单独抽一个小 MR 先合**，其余 MR rebase 之后再继续——这把"N 方混战"变成了"一次串行小冲突"。

## 三、检视提速：CI 先绿、AI 一审、小 MR 快车道（中成本）

MR 存活时间的大头是等人检视。三个可照抄的动作：

**1. CI 不绿不允许进入检视队列**——检视人只看已绿的 MR，避免来回拉扯。

**2. AI 先审一遍，人只看疑点。** 在 GitLab CI 里加一个 job，MR 打开时自动调模型生成"意图摘要 + 风险点 + 受影响调用方"并贴在 MR 评论里，检视人从逐行读变成抽查：

```yaml
# .gitlab-ci.yml 片段
ai-preview:
  stage: review
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
  script:
    - git diff origin/master...HEAD > /tmp/mr.diff
    - python script/ai_review.py /tmp/mr.diff   # 输出贴回 MR 评论
```

注意让审的模型和写代码的模型不同源，详见 [AI 时代的审查瓶颈](ai-era-code-review-bottleneck.md)。

**3. 小 MR 走快车道。** 在团队约定里写死：diff ≤ 100 行、CI 绿、非关键目录的 MR，一个人 Approve 即可当天合入。大多数 AI 产出都是这种体量，队列自然清空。

## 四、合入串行化：Merge Train / Merge Queue（中高成本）

检视人再也不用关心"我这个 MR 合了之后别人要不要 rebase"——平台替你串行排队、自动 rebase、自动重跑 CI：

- **GitLab（Premium/Ultimate）**：项目 Settings → Merge requests → 启用 *Merge trains*。MR 点合入后进入列车，按顺序逐个 rebase + 跑流水线，绿了才落主干。冲突的那个自动被踢出队列并通知作者，**其他 MR 不受影响**。
- **GitHub**：分支保护里勾选 *Require merge queue*，效果相同。
- **内网 GitLab 免费版没有 merge train**：可以用 `git pull --rebase origin master` 的定时脚本兜底（见第五节），或约定"主干合入锁"——同一时间只允许一个 MR 走"rebase → CI → 合入"流程。

这是结构性解法：把"谁和谁冲突"从人际协调问题变成队列调度问题。

## 五、冲突自动消化：定时 rebase + AI 解冲突（中成本）

检视再快也有排队，剩下的冲突让机器先扛：

**1. 定时自动 rebase 所有在途 MR。** 放一个 cron（或 CI schedule）每小时跑一次：

```bash
#!/bin/bash
# rebase-all-mrs.sh：对在途 MR 分支逐个 rebase 主干
set -e
git fetch origin
for br in $(git branch -r --list 'origin/feat/*' 'origin/chore/*' | sed 's|origin/||'); do
  git checkout -q -B "$br" "origin/$br"
  if git rebase origin/master; then
    git push --force-with-lease origin "$br"
  else
    git rebase --abort
    echo "::warning::$br rebase 有冲突，转人工/AI 处理"
  fi
done
```

**2. 冲突了让 AI 修，测试做裁判。** 冲突文件里 `<<<<<<<` 标记本身就是给 AI 的现成输入，配合测试套件判定修没修对：

```bash
git rebase origin/master || true
# 把冲突文件和两边意图交给 AI（claude / kimi / dsh 都行）
claude -p "当前 rebase 冲突，运行 git diff --name-only --diff-filter=U 找到冲突文件，
根据两边分支的提交信息（git log master..HEAD 和 git log HEAD..master）判断各自意图，
解决冲突后运行 pytest 验证，全绿才算完成。"
```

小冲突（import、格式化、相邻行改动）AI 解起来成功率很高；解不了的（两边改了同一逻辑）再转人——**人只处理真正需要判断的冲突**。

## 六、六档对比与建议

| 档位 | 做法 | 改造成本 | 压的是 | 适用场景 |
|------|------|---------|--------|---------|
| 1 | 小 MR + 高频 rebase | 零 | 面积+时间 | 任何团队，今天就做 |
| 2 | 派任务按模块分地 | 低 | 面积 | 多 agent 并行开发 |
| 3 | CI 门禁 + AI 一审 + 快车道 | 中 | 时间 | 检视排队 > 半天 |
| 4 | Merge train / merge queue | 中高 | 时间 | MR 量大、有平台权限 |
| 5 | 定时 rebase + AI 解冲突 | 中 | 冲突处理成本 | 无 merge train 的内网 |
| 6 | 按目录 CODEOWNERS 分流检视人 | 低 | 时间 | 多人多模块的大仓 |

**建议**：先做 1+2（零成本，往往直接消掉一半冲突），一周内上 5 的自动 rebase 脚本（解放修冲突的双手），同时推 3 给检视侧提速。如果 MR 日增量超过 10 个且有平台权限，直接上 4 的 merge train，这是唯一能把冲突问题"关掉"而不是"缓解"的方案。

根源上这是「AI 产出提速、检视原地踏步」的结构性失衡，流程侧的整体改造思路见 [代码越产越快，Review 跟不上：AI 时代的审查瓶颈怎么破](ai-era-code-review-bottleneck.md)；多 agent 并行开发的隔离与编排见 [让 AI 并行开发一个代码仓的多个功能](parallel-feature-development.md)。

## 版本记录

- v1（2026-01）：首版。模型：DeepSeek（DSH, k3-256k）。
