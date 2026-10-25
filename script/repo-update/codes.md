# repo-update 逻辑摘要（给 AI 的最小上下文）

`repo-update.py --explain` 打印的就是本文件。AI 排查时读这一份 + 一个错误信封即可，
不需要读脚本全文。

## 用法

```bash
./repo-update.py --explain        # 打印本文件（给 AI 的最小上下文）
./repo-update.py --dry-run        # 只采集 + 出计划
./repo-update.py --apply          # 执行（先推子仓，再推主仓）
./repo-update.py --apply --no-push
./repo-update.py --apply --resume # 断点续跑
./repo-update.py --all-subs       # 体检全部子仓（默认只处理指针变了的）
./repo-update.py --self-test      # 纯函数自测 + 规则表/codes.md 一致性
```

## 终态（不变量）

1. 每个已初始化的子仓：`HEAD` 等于自己主干 tip，或本地领先（有未推送提交）；
2. 主仓：`index` 里记录的指针 == 子仓实际 `HEAD`（不存在"旧指针"）；
3. 主仓：`HEAD` == `origin/<主干>` 或本地领先；
4. 主仓工作区：除了子模块指针，没有别的已跟踪改动。

## 步骤

| step | 做什么 | 可回滚 |
|---|---|---|
| `preflight` | 找仓根、记录起始 HEAD、修 `.git/modules` 缺 `.git` 的 gitfile、检查脏文件 | 是 |
| `fetch` | `git fetch --all --prune -q`（主仓） | 是 |
| `rebase-subs` | 对每个子仓：定主干 → 落后则 rebase（只允许快进；有已推送提交时停下问人） | 是 |
| `ff-main` | 主仓 `-c submodule.recurse=false rebase <upstream>` | 是 |
| `commit-pointers` | 只提交"索引指针是 HEAD 祖先"的差异，`git add` 后按 `diff --cached` 判定成败 | 是 |
| `push` | 先推有未推送提交的子仓，再 `push --no-recurse-submodules` 推主仓 | **否** |
| `verify` | 打印一行 `ok ...` 或 `pending-pointers ...` | 是 |

## 退出码

| 码 | 含义 | 谁处理 |
|---|---|---|
| 0 | 成功 | 无人 |
| 2 | 需人决策（走 `ASK_*`） | 人 |
| 3 | 可重试（网络、远端有新提交） | 人或上层脚本 |
| 4 | 已自愈（走 `WARN_*`，已继续） | 无人，只记事件 |
| 5 | 未知错误 | AI |

## 错误码

### 需要人决策（exit 2）

- `ASK_MULTI_TRUNK` — 同一子仓的多个远端主干已分叉，哪个是"最新主干"没有唯一答案；
- `ASK_HISTORY_REWRITE` — 子仓有**已推送**的本地提交，rebase 会改写公开历史；
- `ASK_STALE_POINTER` — 主仓记录的指针不是子仓 `HEAD` 的祖先（旧指针/悬空对象），不能自动降级；
- `ASK_MAIN_DIVERGED` — 主仓既有本地提交又落后远端；
- `ASK_DIRTY_WORKTREE` — 主仓有非子模块的已跟踪改动（`--dirty warn` 可降级为继续）；
- `ERR_HEAD_MOVED` — 提交前发现 `HEAD` 变了（疑似并发会话在同一仓操作）；
- `ERR_NOT_A_REPO` — 给的路径不是 git 仓。

### 可自愈 / 已修（继续执行，记事件）

- `ERR_SUBMODULE_CHECKOUT` — 子仓无法 checkout 到目标提交（缺对象/递归被套住）；用 `git -c submodule.recurse=false` 后先 `fetch` 再 `checkout`；
- `ERR_GITFILE_MISSING` — `.git/modules/<子仓>` 存在但工作区缺 `.git`，被当普通未跟踪目录；已写回 `gitdir:`；
- `WARN_IGNORED_PATH` — `git add <子仓>` 退出码 1（路径被 `.gitignore` 覆盖）但**已暂存成功**；按 `diff --cached` 判定，不串联 `&&`；
- `WARN_REMOTE_UNREACHABLE` — 某个远端不可达（SSH 慢/主机下线）；降级用已有 remote-tracking 引用继续；
- `WARN_NO_TRUNK` — 子仓没有任何可用主干引用（既无 upstream，也无 main/master）；跳过该子仓；
- `WARN_SUB_DIRTY` — 子仓工作区有未提交改动；不碰它的 checkout；
- `WARN_UNTRACKED` — 主仓有未跟踪目录；不阻塞（但仍会出现在 `git status` 里）；
- `WARN_DIRTY_WORKTREE` — 主仓有非子模块已跟踪改动，但用了 `--dirty warn`。

### 可重试 / 未知（exit 3/5）

- `ERR_SUBMODULE_PUSH_FAILED` — 刚提交的子仓指针在远端还不存在（子仓推送失败）；此时**不推主仓**，先修子仓；
- `ERR_PUSH_REJECTED` — 推送被拒（远端有新提交 / 钩子 / 网络）；先 `pull --rebase` 再推；
- `ERR_REBASE_CONFLICT` — rebase 冲突，已 `--abort`；需要人判断取舍；
- `ERR_MAIN_REBASE` — 主仓 rebase 失败；确认是否漏了 `-c submodule.recurse=false`；
- `ERR_ADD_FAILED` — `git add` 失败且确实没暂存任何东西；
- `ERR_COMMIT_FAILED` — 提交失败（常见：commit-msg 钩子拒绝，如首行超 72 字符或出现禁用词）。

## 已知坑（脚本已内建，别再踩一遍）

1. 全局 `submodule.recurse = true` 会让 `reset`/`rebase` 递归进子模块，被无法 checkout 的子仓卡死 →
   涉及主仓的命令一律加 `-c submodule.recurse=false`；
2. `git stash` **不捕获**子模块 gitlink 的变化 → 指针差异不靠 stash，按子仓实际 `HEAD` 重建；
3. `git add` 到被 ignore 的已跟踪子模块路径会返回 1，但**其实暂存成功** → 用 `diff --cached` 判定；
4. 子仓无 `@{u}` 时主干按 `main` → `master` → 远端同名分支回退；多候选且分叉 → 停下问人；
5. `.git/modules/<p>` 有、工作区缺 `.git` → 该目录会被当成普通未跟踪文件，`git add` 会提交源码；
6. 并发会话 `commit --amend` + 强推会让本地分叉 → 提交前重读 `HEAD`。
