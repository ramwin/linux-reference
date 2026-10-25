# 重复性运维：把「感知」交给脚本，把「判断」留给 AI

```{contents}
```

> 背景：同一套「更新代码仓」的操作（把改过的自仓 rebase 到最新主干 → 主仓快进 → 提交子模块指针 → 推送），
> 这几天连着做了四轮。每轮都能踩到上一次踩过的坑，每轮 AI 都要从 `git status` 开始重新摸索。
> 这篇文章回答一个具体问题：**这种高频、重复、有固定步骤、又经常报错的操作，怎么让 AI 参与，
> 但别让它把 token 花在重新发现已知事实上。**
>
> 结论先说：方向就是题目里那个直觉——**先跑脚本，失败只把「失败信息 + 脚本逻辑」交给 AI**。
> 它成立，但只做这一层省不了多少；真正让它变成「常态零成本、异常也便宜」的，是后面五件事。

## 引子：同一件重复操作，AI 从头摸索了四遍

先把账摊开。这四轮「更新代码仓」发生在同一个会话里，会话记录（`~/.dsh/sessions/` 下的 jsonl）统计出来是：

| 指标 | 数值 |
|---|---|
| 步数（assistant 轮次） | 96 |
| `bash` 调用次数 | 104 |
| `read` / `write` 调用 | 0 / 0 |
| 非缓存输入 token | 285,075 |
| 缓存命中输入 token | 7,821,696 |
| 合计 totalTokens | 8,187,738 |

208 次工具调用里，104 次是 `bash`——几乎每轮都在重跑同一批命令：`git status`、`git fetch`、
`git submodule status`、`git rev-list --left-right --count`、`git rev-parse`。

而四轮里踩到的坑高度重复：

- `git reset --hard` 因为全局 `submodule.recurse = true`，递归进子模块、被一个缺对象的子模块卡住，整个操作回滚；
- `git rebase` 因为工作区的 gitlink 有差异而被拒（报的是「未暂存改动」，本质是子模块指针）；
- `git add <被 .gitignore 覆盖的已跟踪子模块>` 退出码 1——路径被忽略规则挡住，但**其实已经暂存成功**，`&&` 串联把后续步骤吞掉了；
- `git stash` 根本不捕获子模块 gitlink 的变化，结果「stash 了却还在 dirty」；
- 部分子模块没有配置 upstream，主干得靠约定回退，不能直接 `@{u}`；
- 同一个子模块配了两个远端且已分叉，谁才是「最新主干」不是命令能回答的；
- 指针指向悬空对象或父提交（记录值比实际的旧一代、或干脆是个孤儿提交）；
- `.git/modules/<子模块路径>` 存在但工作区缺 `.git` gitfile，于是整个目录被当成普通未跟踪文件；
- 并发会话在同一仓里 `commit --amend` + 强推，把刚推上去的提交改掉了，本地瞬间分叉。

这九条没有一条需要「创造性思考」——它们全部是**确定性事实**：哪种状态、哪条命令、哪条规则能修。
让大模型每轮重新发现它们，是纯浪费。

## 一、重复操作的成本结构：三份钱

| 成本 | 来源 | 典型表现 |
|---|---|---|
| 探索成本 | 每次都要重新采集状态（哪些仓改了、落后几个提交、有没有 upstream） | 每轮 10~30 次工具调用 |
| 噪声成本 | 全量输出（`git log`、`git status` 长文本、构建日志）进上下文，且后续每一轮重发 | 一次 `git submodule status` 递归输出就上千 token |
| 返工成本 | 踩同一个坑、试错、回滚、再试 | 一轮里 3~5 次失败后重来 |

三者相乘。因为 agent 的上下文是**按步计费**的：每加一轮，前面所有内容都要重发一遍
（缓存只让单价降，不改变「累积」这个结构，详见[上下文工程](./context-engineering.md) 第 2.5 节）。
上表里 782 万缓存命中输入，就是「同一批内容被反复重发」的实证。

所以优化的目标不是「让模型更聪明地探索」，而是**让探索这件事根本不发生**：

> 常态：一次工具调用，返回一行结果。
> 异常：一次工具调用，返回一段结构化错误，外加「这个脚本想干什么、失败在哪、能不能回滚」。

## 二、你的判断：脚本先跑，失败只回传「失败信息 + 脚本逻辑」

### 2.1 方向是对的，而且可以再切一刀

这个直觉背后其实是一条分工线：

| | 谁来做 | 为什么 |
|---|---|---|
| **感知**：采集状态、判断前后关系、跑命令、比对结果 | 脚本 | 确定性、可重放、零 token |
| **判断**：分叉了算不算问题、要不要动历史、多远端谁是主干 | AI | 需要权衡、需要问人、没有唯一答案 |

大多数「重复性操作」里，感知占了 95% 的步骤，判断只占 5%。现在的做法是把 95% 也交给
AI，于是每一轮都要为 95% 的机械活付上下文钱。

再切一刀的意思是：**连「失败后让 AI 读脚本」也可以省掉大半**——只要脚本自己知道
「这条错误以前见过，修法是 X」。这就是第三节的规则库。规则库 miss 了，才轮到 AI。

### 2.2 「失败信息」要长成什么样：错误信封

「把失败信息给 AI」如果只是贴 `stderr`，等于没过滤。建议固定一个信封（envelope），
机器生成、字段稳定：

```json
{
  "run_id": "2026-10-25T23:10:00Z-7f3a",
  "step": "rebase_submodules",
  "rc": 128,
  "code": "ERR_SUBMODULE_CHECKOUT",
  "affected": ["<子模块路径>"],
  "stderr_tail": [
    "错误：子模组 '<子模块路径>' 无法被更新。",
    "错误：Submodule '<子模块路径>' cannot checkout new HEAD."
  ],
  "hint": ["r1_recurse_off", "check_missing_object"],
  "reversible": true,
  "rollback": "git -C <子模块路径> checkout <原 SHA>",
  "suggested_next": ["git -c submodule.recurse=false reset --hard origin/master"],
  "log": "/tmp/repo-update/logs/2026-10-25T23:10-7f3a/rebase_submodules.log"
}
```

**进上下文的只有六项**：`step`、`code`、`affected`、`stderr_tail`（截到 20 行以内）、
`hint`、`suggested_next`。`log` 只给路径，AI 需要时再 `tail`；`rollback` 只在
`reversible=false` 或需要人决策时才贴。

三个字段值得单独解释：

- **`code` 是分类，不是原始报错。** 同一种错误在不同语言、不同 git 版本下 stderr 文字不一样
  （中文/英文、`fatal:` 还是 `错误：`），但 `code` 稳定。AI 看到 `ERR_DIRTY_GITLINK`
  就知道该用哪条修法，不需要理解那段中文。
- **`hint` 是「候选规则」，不是结论。** 脚本命中规则库时直接自动修、不打扰 AI；
  只有多条规则互相矛盾时，才把候选列出来交 AI 裁决。
- **`reversible` 决定要不要叫醒人类。** 动历史（rebase 已推送分支、force-push）永远标
  `reversible=false`，这类必须走确认；`checkout`/`reset` 之类标 `true`。

### 2.3 为什么传「逻辑」而不是「全文」

一个 300 行的脚本全文大约 3K~4K token。而 AI 判断一次失败真正需要的只有三件事：

1. 这个脚本**想达到的终态**是什么（比如「所有子仓在自己的主干 tip 上，主仓干净且与远端一致」）；
2. **失败卡在哪一步**（`step`）；
3. **能不能退回去**（`reversible` / `rollback`）。

这三件事用 20 行以内就能说清。做法有两个，都不需要 AI 去读源码：

- 脚本自带 `--explain`，输出一段固定模板：步骤列表 + 每步的终态断言 + 每条 `code` 的一行含义；
- 或者退一步，用函数名 + `code` 列表当逻辑摘要（一份 20 行的 `codes.md` 就够）。

```bash
$ ./repo-update.sh --explain
steps: fetch → detect-changes → rebase-subs → ff-main → commit-pointers → push
invariant: 每个子仓 HEAD 是主干 tip；主仓 index == HEAD；origin/master == HEAD 或本地领先
codes: ERR_SUBMODULE_CHECKOUT / ERR_DIRTY_GITLINK / ERR_NO_UPSTREAM /
       ERR_STALE_POINTER / ERR_GITFILE_MISSING / ASK_MULTI_TRUNK / WARN_IGNORED_PATH
reversible: rebase-subs / ff-main 可回滚；push 与 amend 不可
```

AI 拿到「一次 `--explain` + 一个信封」的上下文，比「脚本全文 + 全部 stderr」小一个数量级，
而且信息密度更高——因为字节少了，干扰项也少了。

### 2.4 省多少（估算，非实测）

| 路径 | 现状 | L1（脚本 + 信封） | 倍数 |
|---|---|---|---|
| 常态一次「更新代码仓」 | 20~30 次工具调用，20K~60K token | 1 次调用，返回一行 `ok steps=6 pointers=3`（约 30 token） | 约两个数量级 |
| 遇到新错误 | 5~10 次调用摸清现场 + 试错 | 1 次拿到信封（约 400~800 token）再决定 | 约 10 倍 |
| 遇到老错误 | 同上，且可能重复踩 | 0 次——规则库自动修 | 无限 |

数字是量级估算，不是承诺。真正的杠杆在第一行：**让常态路径从「对话」退化成「一次命令」**。

## 三、比「回传失败」更省的六个手段

只做第二节（脚本 + 信封），异常路径还是要花几百 token 叫 AI 来判。下面六件是把它继续压下去的：

### 3.1 语义化退出码 + 结构化事件

别让 AI 解析自然语言报错。约定：

| 退出码 | 含义 | 谁处理 |
|---|---|---|
| 0 | 成功 | 无人 |
| 2 | 需要人决策（分叉、动历史） | 停下问人 |
| 3 | 可自动重试（网络、锁文件） | 脚本自己退避重试 |
| 4 | 已知可修（命中规则库，已修并继续） | 无人，只记事件 |
| 5 | 未知错误 | AI |

同时把每一大步写成一行 JSONL（`events.jsonl`），`code`/`step`/`rc`/耗时/影响路径。
事后排查不用回放整段对话，`grep` 一个文件就行——这也是「让上下文能卸货」的具体做法。

### 3.2 幂等 + 状态文件：断点续跑

重复性操作之所以重复，往往是因为它中途会失败。失败后从第一步重来，就白花了前面的钱。
给脚本一个 `state.json`：

```json
{"run": "2026-10-25T22:10", "done": ["fetch", "detect-changes", "rebase-subs"],
 {"pending": ["ff-main", "commit-pointers", "push"], "targets": {"<子模块路径>": "<目标 SHA>"}}
```

重跑时 `--resume` 跳过 `done`。对 AI 的好处是：**它的上下文里根本不需要出现「前面做到哪了」**，
脚本自己记得。

### 3.3 已知错误规则库：AI 只在 miss 时介入

这是收益最大的一条，也是最容易长期积累的。每踩一个新坑，除了修，再往
`rules.toml` 里加一条：

```toml
[[rule]]
code    = "ERR_SUBMODULE_CHECKOUT"
match   = "cannot checkout new HEAD|cannot be updated|子模组 .* 无法被更新"
fix     = "git -c submodule.recurse=false -C {{repo}} checkout {{index_sha}}"
retry   = false
note    = "全局 submodule.recurse=true 时会递归；缺对象时先 fetch 再 checkout"
```

配套一条：**规则必须可回滚且幂等**，否则自动修会把事情弄更糟。命中规则后打一行
`fixed: ERR_SUBMODULE_CHECKOUT (r1)` 就够，不进 AI 上下文。

这一步和「记忆沉淀」是同一件事的两面：AI 这边记进 `kb/`、`memory/`，
脚本这边记进 `rules.toml`。前者给人看，后者给机器跑。

### 3.4 dry-run / plan 产物：审计划，不审过程

把「先看清再动手」做进脚本：`--dry-run` 输出一份计划（要改哪些指针、从哪个 SHA 到哪个 SHA、
哪些仓要 rebase、哪些要问人），AI 只审这份 20 行的计划，确认后再 `--apply`。

比让 AI 盯着 20 条命令的输出逐条推理便宜得多，而且**计划就是断言**，可以事后核对。

### 3.5 让脚本给「修复建议命令」，AI 只做裁决

脚本的 `suggested_next` 直接给可执行命令。AI 的角色从「推理者」降级为「裁决者」：
选一条、或者因为 `reversible=false` 而问人。裁决只需要看一行，推理需要看一屏。

### 3.6 失败样本回归：同一个 bug 不让 AI 调两次

把每个真实失败现场存成 fixture（仓库状态快照 + 触发的命令 + 期望的 `code`），
用 `--self-test` 跑一遍。好处：改脚本不会弄坏已修好的分支；新错误一旦复现，
先加 fixture 再改规则，AI 只参与一次。

## 四、五档方案：从纯脚本到 AI 编排

| 档 | 形态 | 谁决策 | 常态 token | 异常 token | 能自动处理报错吗 | 投入 |
|---|---|---|---|---|---|---|
| **L0** 纯脚本 | 无 AI，人跑 | 人 | 0 | 0 | 只能处理写死的分支，新错误靠人读日志 | 半天~1 天 |
| **L1** 脚本 + 错误信封（你的方案） | 脚本跑，失败把信封 + `--explain` 给 AI | AI 裁决异常 | ~0（一行结果） | 小（几百 token） | 能，但要叫 AI | +半天（信封、`--explain`、退出码） |
| **L2** + 规则库自愈 | 已知错误脚本自己修 | 规则 | 0 | 很小（只报 `fixed:`） | 常见错误全覆盖 | +1 天，之后每加一条几分钟 |
| **L3** + 幂等状态机 | 断点续跑、可重入 | 脚本 | 0 | 小 | 失败可恢复，不重来 | +1 天 |
| **L4** + AI 编排 | AI 规划分派，脚本执行，子 agent 并行多仓 | AI + 规则 | 中 | 中 | 强，但成本又回来了 | 数天 |

**明确建议：L1 → L2 起步，L3 按需补，L4 先别碰。**

理由：

- L0 不解决「新错误没人修」的问题——脚本一旦报错，你还是得自己读日志；
- L1 就是你的直觉，成本最低，当天能落地，**但只做它会发现异常路径依然每次叫 AI**，
  而且 AI 每次都要重新理解一遍脚本；
- L2 是分水岭：把「AI 每次都懂」变成「脚本一次学会」。这两档加起来一天内做完，
  之后边际成本趋近于零；
- L3 只有在「一次操作要跑十几分钟、中途常挂」时才值得，否则 `--resume` 的复杂度大于收益；
- L4 是另一个话题（多 agent 编排），它的成本结构比单脚本高一个量级，别为了省 token 引入它。

## 五、落地：一个 `repo-update` 脚本长什么样

把你现在散在 `script/` 里的几个片段（`rebase_to_master.sh`、`master_or_main.sh`、
`判断仓库是否更新了.sh`、`添加submodule.sh`）收成**一个入口 + 三个数据文件**：

```
script/repo-update/
├── repo-update.sh      # 唯一入口，支持 --dry-run/--apply/--resume/--json/--explain/--self-test
├── rules.toml          # 已知错误 → 修法（机器读）
├── codes.md            # code 一行含义（AI 读的逻辑摘要）
├── state.json          # 断点状态（运行时生成）
└── logs/<run_id>/      # 每步完整日志，只回路径不回内容
```

骨架（bash 版，能跑通主流程；错误处理按第三节的分层留了钩子）：

```bash
#!/usr/bin/env bash
# repo-update.sh —— 主仓 + 子仓的重复性维护
# 终态: 每个自仓在自己主干 tip；主仓 index == HEAD == origin/master 或本地领先；工作区干净
set -uo pipefail

RUN_ID="$(date -u +%Y-%m-%dT%H:%M:%SZ)-$RANDOM"
LOG_DIR="${LOG_DIR:-/tmp/repo-update/logs/$RUN_ID}"
STATE="${STATE:-/tmp/repo-update/state.json}"
RULES="$(dirname "$0")/rules.toml"
mkdir -p "$LOG_DIR"

emit() {   # 一行 JSON 事件，永远不刷屏
  printf '{"run":"%s","step":"%s","rc":%s,"code":"%s","affected":%s}\n' \
    "$RUN_ID" "$1" "$2" "${3:-}" "${4:-[]}" >> "$LOG_DIR/events.jsonl"
}

fail() {   # 失败信封：只把 allowed 字段交给 AI
  local step="$1" rc="$2" code="$3" affected="${4:-[]}" hint="${5:-[]}" rollback="${6:-}"
  printf '{"step":"%s","rc":%d,"code":"%s","affected":%s,"hint":%s,"reversible":%s,"rollback":"%s",' \
    "$step" "$rc" "$code" "$affected" "$hint" "$([ -n "$rollback" ] && echo true || echo false)" "$rollback" >&2
  printf '"stderr_tail":%s,"log":"%s"}\n' \
    "$(printf '%s' "${ERR_TAIL:-[]}" )" "$LOG_DIR/$step.log" >&2
  emit "$step" "$rc" "$code" "$affected"
  exit "${EXIT_CODE:-5}"      # 0 ok / 2 需人决策 / 3 可重试 / 4 已自动修 / 5 未知
}

# 1) 采集：一次拿全量，输出机器格式（这是省 token 的关键一步）
collect() {
  git fetch --all --prune --quiet 2>>"$LOG_DIR/fetch.log" || true
  git submodule foreach --quiet '
    idx=$(git -C "$toplevel" rev-parse ":$sm_path" 2>/dev/null)
    printf "%s\t%s\t%s\n" "$sm_path" "${idx:0:9}" "$(git rev-parse HEAD)"
  ' 2>/dev/null > "$LOG_DIR/pointers.tsv"
}

# 2) 状态判定：只输出「谁需要动」，输出两列数字而不是 log 全文
plan() {
  git status --porcelain=v1 > "$LOG_DIR/status.txt"
  awk -F'\t' '$2 != $3 { print "pointer", $1, $2, "->", $3 }' "$LOG_DIR/pointers.tsv"
  awk '{ print "dirty", $0 }' "$LOG_DIR/status.txt"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --explain) cat "$(dirname "$0")/codes.md"; exit 0 ;;
      --dry-run) collect; plan; exit 0 ;;
      --resume)  RESUMED=1 ;;
      --json)    JSON=1 ;;
      --apply)   : ;;
      *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
  done

  collect
  git -c submodule.recurse=false rebase origin/master >>"$LOG_DIR/ff-main.log" 2>&1 \
    || { ERR_TAIL='["rebase 失败，见 log"]'; fail ff-main 128 ERR_FF_FAILED '[]' '[]' ""; }

  # 指针：只提交「本地领先」的；方向不对的停下来问人（ASK_* / EXIT_CODE=2）
  while IFS=$'\t' read -r path idx head; do
    [ "$idx" = "$head" ] && continue
    if git -C "$path" merge-base --is-ancestor "$idx" "$head" 2>/dev/null; then
      git add "$path" && printf 'staged %s %s->%s\n' "$path" "${idx:0:7}" "${head:0:7}"
    else
      printf '{"step":"commit-pointers","rc":2,"code":"ASK_STALE_POINTER","affected":["%s"],"reversible":true}\n' \
        "$path" >&2
      exit 2
    fi
  done < "$LOG_DIR/pointers.tsv"

  git diff --cached --quiet || git commit -m "chore: 同步子模块指针" >>"$LOG_DIR/commit.log" 2>&1
  git push origin master >>"$LOG_DIR/push.log" 2>&1 || fail push 128 ERR_PUSH_REJECTED
  echo "ok steps=6 run=$RUN_ID"          # 常态路径的全部输出
}
main "$@"
```

几个刻意的地方：

- **`collect` 用一次 `submodule foreach` 出全量**，而不是每个仓一次调用。工具调用次数
  就是上下文轮次，能一次拿完就别分十次。
- **`plan` 输出的是「差异」而不是「状态」**：`pointer x idx -> head`、`dirty ...`，
  几行就够，AI 不用读 60 行 `git status`。
- **常态只 `echo "ok steps=6 run=..."`**。这是整套设计的核心：成功路径不产生上下文。
- **失败走 stderr 的信封**，把「哪些字段给 AI」编码在脚本里，而不是写进提示词让 AI 自己去捞。
- 动历史的步骤（`amend`、`push --force`）永远 `exit 2` 交给人，不进自动修路径。

### 本次踩过的坑 → 直接变成规则

| 现场现象 | `code` | 自动处理 |
|---|---|---|
| `reset/rebase` 递归子模块、卡在 checkout | `ERR_SUBMODULE_CHECKOUT` | `-c submodule.recurse=false`，再 `submodule status` 找 `-`/`+` 单独处理 |
| `cannot rebase` 但报的是「未暂存改动」 | `ERR_DIRTY_GITLINK` | gitlink 不靠 stash；用 `-c submodule.recurse=false rebase` 或先 `git add` |
| `git add <被 ignore 的已跟踪子模块>` 退出 1 但已暂存 | `WARN_IGNORED_PATH` | 不串联 `&&`；用 `git diff --cached --name-status` 判定成败 |
| 子模块没有 `@{u}` | `ERR_NO_UPSTREAM` | 按约定表回退：`main` → `master` → 远端同名分支 |
| 两个远端分叉，谁是主干说不清 | `ASK_MULTI_TRUNK` | 停下问人（`exit 2`），不猜 |
| 指针指向悬空对象或父提交 | `ERR_STALE_POINTER` | `merge-base --is-ancestor` 判方向；只接受「本地领先」 |
| `.git/modules/<p>` 有、工作区缺 `.git` | `ERR_GITFILE_MISSING` | 写回 `gitdir: ../../.git/modules/<p>`，否则会被当普通文件 |
| 并发会话 `amend` + 强推 | `ERR_HEAD_MOVED` | 提交前重读 `rev-parse HEAD`，与开工时不同就停 |
| 远端不可达（SSH 慢 / bundle 丢失） | `WARN_REMOTE_UNREACHABLE` | 降级用已有 remote-tracking ref，不重试到底 |

## 六、把 AI 这一侧也做瘦

脚本侧省的是「执行」，AI 侧还有三块固定开销可以省：

**1）流程固化成 skill / `AGENTS.md` 指针。**
「更新代码仓」的步骤、判定标准、遇到分叉怎么办，一次写进 skill 或仓内 `AGENTS.md`，
之后每轮只花一句「更新代码仓」。别每次在对话里重新交代规则——规则进上下文是每轮都要付钱的。

**2）长输出落盘，只回 `tail` 与 `grep`。**
构建日志、fetch 日志、`submodule foreach` 的输出，一律重定向到 `logs/<run_id>/`；
需要时只回 `grep -E 'error|fatal|rejected' | tail -20`。这条能砍掉大部分噪声成本。

**3）批量采集，一次调用出一个表。**
`git status --porcelain=v1`、`git rev-list --left-right --count`、
`git for-each-ref --format`、一次 `awk` 汇总——这些命令的机器格式就是为「给程序读」设计的，
比让 AI 解析中文片段便宜且可靠。工具调用次数下降，轮次就下降，累积上下文跟着下降。

**4）沉淀闭环。**
一次新错误 →（a）脚本加 `rules.toml` 条目，（b）`kb/` 加一条给人和 AI 看的说明。
下次命中规则零成本；AI 需要细读时才 `grep` 那条 kb。规则层和事实层分开维护，这一点和
[用 git 管理 AI 记忆](./memory-git.md) 是同一个思路。

## 七、反模式：什么时候别上这套

| 场景 | 为什么不合适 | 可以怎么做 |
|---|---|---|
| 一次性操作 | 写脚本比手做还贵，且不会再跑 | 直接做，别抽象 |
| 步骤本身还在变 | 规则库会追不上，脚本一直改 | 先手做几遍，稳定了再固化 |
| 判断占大头（如「这个分支该不该删」） | 脚本写不进去，只能 AI 判 | 让 AI 做，但只给「分支清单 + 判定标准」 |
| 脚本不能回滚 | 自动修会把不可逆错误放大 | 只做 `--dry-run` 和 `suggested_next`，执行交人 |
| 多人共用同一仓、有人会并发改 | 检测到 `HEAD` 移动必须停 | 加 `ERR_HEAD_MOVED`，宁可多问一句 |

## 八、自检清单

对着自己的重复性流程打勾：

- [ ] 终态能用一句话写出来，并且脚本里有对应的断言
- [ ] 常态成功只输出一行，不刷屏
- [ ] 失败输出固定信封，字段稳定（`code` 是分类不是原文）
- [ ] `--explain` 能用 20 行说清「步骤 + 终态 + code 含义」，不需要 AI 读源码
- [ ] 退出码分层：0 / 2 需人决策 / 3 可重试 / 4 已自愈 / 5 未知
- [ ] 有 `--dry-run`，且计划本身就是可核对的断言
- [ ] 有状态文件，失败能 `--resume`，不从头重来
- [ ] 规则库覆盖了最近踩过的所有坑，且每条都可回滚、幂等
- [ ] 动历史（amend / force-push）永远走人确认
- [ ] 每个新错误都会变成一条规则 + 一条 kb，而不是只修一次
- [ ] 上一次重复操作，`bash` 调用次数是个位数（本会话是 104，目标是一个量级以下）

## 参考

- 本仓：[上下文工程](./context-engineering.md)：为什么上下文按步计费、最小高信号 token 集
- 本仓：[Agent 工程师](./agent-engineer.md)：工具返回应该「内部先过滤，只回结构化结论」
- 本仓：[从学习到生产](./production-deployment.md)：幂等、重试、可观测性在线上 Agent 里的位置
- 仓内脚本：`script/rebase_to_master.sh`、`script/master_or_main.sh`、
  `script/判断仓库是否更新了.sh`、`script/添加submodule.sh`——这套脚本的既有碎片

## 版本记录

| 版本 | 日期 | 模型 | 主要变动 |
|---|---|---|---|
| v1 | 2026-10-25 | deepseek-flash | 初稿：三份成本账、错误信封、六个进一步手段、五档对比与建议、`repo-update` 骨架与九条真实规则 |

本会话 token 汇总（口径：`inputTokens` 不含缓存命中；含前三轮「更新代码仓」的实操与本篇写作，截至初稿）：

| 指标 | 数值 |
|---|---|
| 步数 | 96 |
| `bash` 调用 | 104 |
| 非缓存输入 | 285,075 |
| 输出 | 80,967 |
| 缓存命中输入 | 7,821,696 |
| 合计 totalTokens | 8,187,738 |
