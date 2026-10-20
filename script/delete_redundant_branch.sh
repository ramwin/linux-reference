#!/usr/bin/env bash
# Xiang Wang(ramwin@qq.com)
#
# delete_redundant_branch.sh — 清理冗余分支
#
# 「冗余」= 分支上的工作已经落到主线, 或者上游早就删了它, 留着只是噪音.
# 本脚本只做判断和删除, **不重新 rebase, 不切换当前分支**, 默认 dry-run,
# 删除前自动打备份 ref (refs/backup/branch-cleaner/...), 随时可以恢复.
#
#   ./delete_redundant_branch.sh                  # 只看不改
#   ./delete_redundant_branch.sh --all            # 看 squash 合并 / 补丁等价 / 上游已删
#   ./delete_redundant_branch.sh --all --yes      # 真删本地分支(带备份); 远程要再加 --remote
#   ./delete_redundant_branch.sh --recurse-submodules --yes --all
#
# 判定依据(全部只读, 不碰工作区):
#   merged   分支是基线的祖先              git merge-base --is-ancestor
#   squash   分支合回主线不改变主线内容     git merge-tree --write-tree (覆盖 squash 合并)
#   patch    每个提交的补丁都已在主线       git cherry (识别 rebase/cherry-pick 落地)
#   pr       有已合并的 PR                gh pr list --state merged (需 --gh)
#   gone     上游分支已删除                [gone]  (需 --gone)
#
# 用法见 --help. Bash 3.2 兼容(macOS 自带 bash 也能跑).
set -uo pipefail

PROG=${0##*/}
VERSION=1.0.0

DRY_RUN=1
FORCE=0
CHECK_SQUASH=0
CHECK_PATCHES=0
CHECK_GONE=0
CHECK_GH=0
CLEAN_REMOTE=0
DO_PRUNE=0
BACKUP=1
AGE_DAYS=0
JSON=0
RECURSE=0
QUIET=0
BASE_ARG=""
DEFAULT_KEEP="main master develop trunk release/* hotfix/* gh-pages backup/* dependabot/*"
KEEP_PATTERNS="$DEFAULT_KEEP"
TS=$(date +%Y%m%d-%H%M%S)
# 内部用  (US, refname 里不可能出现) 做字段分隔: 制表符是 IFS 空白,
# read 会把连续制表符合并成一个, 空字段(track/status)会把列全部错位.
SEP=$(printf '\037')

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 1; }
warn() { printf '%s: warn: %s\n' "$PROG" "$*" >&2; }
# JSON 模式下所有过程信息走 stderr, 保证 stdout 只有一份可解析的 JSON
log() {
	[ "$QUIET" = 1 ] && return 0
	if [ "$JSON" = 1 ]; then printf '%s\n' "$*" >&2; else printf '%s\n' "$*"; fi
}
indent_out() {
	[ "$QUIET" = 1 ] && return 0
	if [ "$JSON" = 1 ]; then sed 's/^/  /' >&2; else sed 's/^/  /'; fi
}

usage() {
	cat <<EOF
$PROG $VERSION — 清理冗余分支(默认只报告, 不删除)

用法: $PROG [选项]

  -n, --dry-run            只报告, 不删除(默认)
  -y, --yes                真正执行删除
  -f, --force              允许删除「本地有独有提交」的 gone 分支(删前必做备份)
      --squash             额外识别 squash 合并: 把分支合回主线不会改变主线内容
      --patches            额外识别补丁等价: rebase/cherry-pick 落地(git cherry)
      --gh                 额外用 gh 检查「PR 已合并」的分支(需 gh 已登录)
      --all                等于 --squash --patches --gone --prune (不含 --remote)
      --gone               额外清理上游已删除([gone])的分支
      --remote             同时清理 origin 上已合并的远程分支(要单独加, --all 不含它)
      --prune              先 git fetch --prune 刷新 [gone] 状态
      --no-backup          不创建备份 ref(不推荐)
  -b, --base REF           指定基线分支(默认: origin/HEAD → main/master → 当前分支)
  -k, --keep GLOB          额外保留的分支名模式, 可多次(如 -k 'wip/*')
      --no-protect         不使用默认保留规则(默认: $DEFAULT_KEEP)
      --age N              只清理最近 N 天都没提交过的分支
      --json               以 JSON 输出结果(便于插件/CI 调用)。递归子模块时每个仓库输出一行 JSON
      --recurse-submodules 对本仓库所有已初始化的子模块各跑一遍
  -q, --quiet              安静模式(只输出结论)
  -V, --version            版本
  -h, --help               本帮助

退出码: 0 正常; 1 出错.

例子:
  $PROG --all                       # 全面体检
  $PROG --all --yes                 # 全面清理
  $PROG --gone --yes                # 只清上游没了的
  $PROG -b origin/master --yes      # 指定对比基线
EOF
}

# ---------------------------------------------------------------- 参数解析
ARGS=("$@")
while [ $# -gt 0 ]; do
	case "$1" in
	-n | --dry-run) DRY_RUN=1 ;;
	-y | --yes) DRY_RUN=0 ;;
	-f | --force) FORCE=1 ;;
	--squash) CHECK_SQUASH=1 ;;
	--patches) CHECK_PATCHES=1 ;;
	--gone) CHECK_GONE=1 ;;
	--gh) CHECK_GH=1 ;;
	--all) CHECK_SQUASH=1; CHECK_PATCHES=1; CHECK_GONE=1; DO_PRUNE=1 ;;
	--remote) CLEAN_REMOTE=1 ;;
	--prune) DO_PRUNE=1 ;;
	--no-backup) BACKUP=0 ;;
	-b | --base)
		[ $# -ge 2 ] || die "$1 需要一个参数"
		BASE_ARG=$2
		shift
		;;
	-k | --keep)
		[ $# -ge 2 ] || die "$1 需要一个参数"
		KEEP_PATTERNS="$KEEP_PATTERNS $2"
		shift
		;;
	--no-protect) KEEP_PATTERNS="" ;;
	--age)
		[ $# -ge 2 ] || die "$1 需要一个参数"
		AGE_DAYS=$2
		shift
		;;
	--json) JSON=1 ;;
	--recurse-submodules) RECURSE=1 ;;
	-q | --quiet) QUIET=1 ;;
	-V | --version) printf '%s %s\n' "$PROG" "$VERSION"; exit 0 ;;
	-h | --help) usage; exit 0 ;;
	*) die "未知参数: $1 (用 --help 查看用法)" ;;
	esac
	shift
done

case "$AGE_DAYS" in '' | *[!0-9]*) die "--age 需要非负整数, 收到: $AGE_DAYS" ;; esac

# ------------------------------------------------------------ 子模块递归
if [ "$RECURSE" = 1 ] && [ "${BRANCH_CLEANER_NO_RECURSE:-0}" != 1 ]; then
	GIT_TOP=$(git rev-parse --show-toplevel 2>/dev/null) || die "当前目录不是 git 仓库"
	SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
	# 递归到子模块时只做本地分支清理: 去掉 --recurse-submodules,
	# 并且不带 --prune/--remote —— 那会在几十个子模块里各拉一次网、各删一次远程分支,
	# 既慢又远超「清理这个仓的分支」的意图. --all 在子模块里降级为 squash+patches+gone.
	PASS=()
	for a in ${ARGS[@]+"${ARGS[@]}"}; do
		case "$a" in
		--recurse-submodules | --prune | --remote) ;;
		--all) PASS=(${PASS[@]+"${PASS[@]}"} "--squash" "--patches" "--gone") ;;
		*) PASS=(${PASS[@]+"${PASS[@]}"} "$a") ;;
		esac
	done
	log "子模块只做本地清理(不带 --prune/--remote)"
	status=0
	# 列出已初始化的子模块(含嵌套)
	SUB_LIST=$(git submodule status --recursive 2>/dev/null | awk '{print $2}')
	[ -n "$SUB_LIST" ] || log "没有子模块, 只处理当前仓库"
	for sub in $SUB_LIST; do
		[ -d "$GIT_TOP/$sub/.git" ] || [ -f "$GIT_TOP/$sub/.git" ] || { log "跳过未初始化子模块: $sub"; continue; }
		if [ "$JSON" = 1 ]; then
			printf '\n=== 子模块 %s ===\n' "$sub" >&2
		else
			printf '\n=== 子模块 %s ===\n' "$sub"
		fi
		(
			cd "$GIT_TOP/$sub" || exit 1
			BRANCH_CLEANER_NO_RECURSE=1 bash "$SELF" ${PASS[@]+"${PASS[@]}"}
		) || status=1
	done
	exit "$status"
fi

# ---------------------------------------------------------------- 仓库检查
git rev-parse --git-dir >/dev/null 2>&1 || die "当前目录不是 git 仓库"
cd "$(git rev-parse --show-toplevel)" || die "无法进入仓库根目录"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/branch-cleaner.XXXXXX") || die "无法创建临时目录"
trap 'rm -rf "$TMPD"' EXIT
LOCAL_TSV=$TMPD/local.tsv   # name \t sha \t ts \t track \t action \t status \t reason
REMOTE_TSV=$TMPD/remote.tsv # name \t sha \t action \t status \t reason
: >"$LOCAL_TSV"
: >"$REMOTE_TSV"

DEFAULT_REMOTE=""
if git remote get-url origin >/dev/null 2>&1; then DEFAULT_REMOTE=origin; fi

detect_base() {
	if [ -n "$BASE_ARG" ]; then
		printf '%s' "${BASE_ARG#origin/}"
		return 0
	fi
	local ref c
	if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
		printf '%s' "${ref#origin/}"
		return 0
	fi
	for c in main master trunk; do
		if git rev-parse --verify --quiet "refs/heads/$c" >/dev/null; then
			printf '%s' "$c"
			return 0
		fi
	done
	for c in main master trunk; do
		if git rev-parse --verify --quiet "refs/remotes/origin/$c" >/dev/null; then
			printf '%s' "$c"
			return 0
		fi
	done
	ref=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) && [ -n "$ref" ] || return 1
	printf '%s' "$ref"
}

BASE=$(detect_base) || die "无法自动判断基线分支, 用 -b/--base 指定"
BASE_LOCAL=""
BASE_REMOTE=""
if git rev-parse --verify --quiet "refs/heads/$BASE" >/dev/null; then BASE_LOCAL=$BASE; fi
if git rev-parse --verify --quiet "refs/remotes/origin/$BASE" >/dev/null; then BASE_REMOTE="origin/$BASE"; fi
[ -n "$BASE_LOCAL$BASE_REMOTE" ] || die "基线分支 $BASE 在本地和 origin 都不存在"
# 判定「已落地」时, 只要落到任意一条主线即可(本地 master 和 origin/master 谁新算谁)
MERGE_BASE_REFS="${BASE_LOCAL:+$BASE_LOCAL}${BASE_LOCAL:+ }${BASE_REMOTE}"
MERGE_BASE_REFS=${MERGE_BASE_REFS% }
# 本地 master 和 origin/master 谁新谁旧不确定, 所有"是否已落地"的判定都遍历两条
MAIN_REFS=$MERGE_BASE_REFS

# ---------------------------------------------------------------- 工具函数
# 分支名是否命中保留模式(支持 * ? [ ] 通配)
keep_by_pattern() {
	local name=$1 pat
	for pat in $KEEP_PATTERNS; do
		# shellcheck disable=SC2254 # 故意让变量里的 glob 生效
		case "$name" in $pat) return 0 ;; esac
	done
	return 1
}

# 所有 worktree 正在检出的分支(含主工作区)
checked_out_branches() {
	git worktree list --porcelain 2>/dev/null |
		sed -n 's|^branch refs/heads/||p'
}

is_ancestor_merged() { # $1=sha: 只要落到任意一条主线就算
	local r
	for r in $MAIN_REFS; do
		git merge-base --is-ancestor "$1" "$r" 2>/dev/null && return 0
	done
	return 1
}

is_patch_merged() { # $1=branch
	# git cherry 输出 '+' 开头的行代表还没落地的补丁; 一条都没有 = 补丁全在
	local r plus
	for r in $MAIN_REFS; do
		plus=$(git cherry "$r" "refs/heads/$1" 2>/dev/null | grep -c '^+')
		[ "${plus:-1}" -eq 0 ] && return 0
	done
	return 1
}

# 把分支合回主线, 如果主线内容一点不变, 说明该分支的工作已经在主线里了
# (squash 合并 / 内容完全一致都是这种情况). 用 merge-tree 只在对象层计算, 不碰工作区.
is_merge_noop() { # $1=branch
	local r out tree base_tree
	for r in $MAIN_REFS; do
		out=$(git merge-tree --write-tree "$r" "refs/heads/$1" 2>/dev/null) || continue
		tree=$(printf '%s\n' "$out" | head -n 1)
		base_tree=$(git rev-parse "$r^{tree}" 2>/dev/null) || continue
		[ -n "$tree" ] && [ "$tree" = "$base_tree" ] && return 0
	done
	return 1
}

# 老 git (<2.38) 没有 merge-tree --write-tree, 退化为内容比较
is_content_same() { # $1=branch
	local r
	for r in $MAIN_REFS; do
		git diff --quiet "$r" "refs/heads/$1" -- 2>/dev/null && return 0
	done
	return 1
}

# 分支上有多少个提交还没落到主线(取两条主线的较小值, 不夸大)
ahead_count() { # $1=branch
	local r n min=""
	for r in $MAIN_REFS; do
		n=$(git rev-list --count "$r..refs/heads/$1" 2>/dev/null) || n=0
		if [ -z "$min" ] || [ "$n" -lt "$min" ]; then min=$n; fi
	done
	printf '%s' "${min:-0}"
}

pr_merged() { # $1=branch, 依赖 gh
	command -v gh >/dev/null 2>&1 || return 1
	local n
	n=$(gh pr list --head "$1" --state merged --json number --jq 'length' 2>/dev/null) || return 1
	[ "${n:-0}" -gt 0 ]
}

backup_branch() { # $1=branch $2=sha
	[ "$BACKUP" = 1 ] || return 0
	local ref="refs/backup/branch-cleaner/$TS/$1"
	if git update-ref "$ref" "$2" 2>/dev/null; then
		log "  备份: $ref"
	else
		# 分支名不符合 ref 规则时退化为文件备份
		printf '%s %s\n' "$2" "$1" >>"$(git rev-parse --git-dir)/branch-cleaner-backup.log"
		warn "  分支名不能做 ref, 已记到 .git/branch-cleaner-backup.log"
	fi
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\t'; }

# ---------------------------------------------------------------- 主流程
if [ "$DO_PRUNE" = 1 ]; then
	log "== git fetch --prune (刷新 [gone] 状态) =="
	git fetch --prune --quiet || warn "fetch 失败, [gone] 状态可能不准"
fi

CURRENT=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
WORKTREES=$(checked_out_branches)

delete_local() { # $1=name $2=sha $3=safe|force, 返回 git branch 的退出码
	[ "$DRY_RUN" = 1 ] && return 0
	backup_branch "$1" "$2" || return 1
	local out rc
	if [ "$3" = safe ]; then
		out=$(git branch -d -- "$1" 2>&1); rc=$?
	else
		out=$(git branch -D -- "$1" 2>&1); rc=$?
	fi
	[ -n "$out" ] && printf '%s\n' "$out" | indent_out
	return $rc
}

NOW=$(date +%s)
while IFS=$'\t' read -r name sha ts track; do
	[ -n "$name" ] || continue
	action=keep
	status=skip
	reason=""
	safe=force

	if [ "$name" = "$BASE" ]; then
		reason="基线分支"; action=keep; status=protect
	elif [ "$name" = "$CURRENT" ]; then
		reason="当前检出的分支"; action=keep; status=protect
	elif printf '%s\n' "$WORKTREES" | grep -Fxq "$name"; then
		reason="被 worktree 检出"; action=keep; status=protect
	elif keep_by_pattern "$name"; then
		reason="命中保留规则"; action=keep; status=protect
	elif [ "$AGE_DAYS" -gt 0 ] && [ -n "$ts" ] && [ $(((NOW - ts) / 86400)) -lt "$AGE_DAYS" ]; then
		reason="最近 $(((NOW - ts) / 86400)) 天内有提交"; action=keep; status=protect
	elif is_ancestor_merged "$sha"; then
		action=delete; status=merged; reason="已合并到 $BASE"; safe=safe
	elif [ "$CHECK_SQUASH" = 1 ] && is_merge_noop "$name"; then
		action=delete; status=squash; reason="合回 $BASE 不改变主线内容"
	elif [ "$CHECK_SQUASH" = 1 ] && is_content_same "$name"; then
		action=delete; status=squash; reason="内容与 $BASE 一致"
	elif [ "$CHECK_PATCHES" = 1 ] && is_patch_merged "$name"; then
		action=delete; status=patch; reason="补丁已全在 $BASE"
	elif [ "$CHECK_GH" = 1 ] && pr_merged "$name"; then
		action=delete; status=pr; reason="PR 已合并"
	elif [ "$CHECK_GONE" = 1 ] && [ "$track" = "[gone]" ]; then
		ahead=$(ahead_count "$name")
		if [ "${ahead:-0}" -eq 0 ]; then
			action=delete; status=gone; reason="上游已删除, 无独有提交"; safe=safe
		elif [ "$FORCE" = 1 ]; then
			action=delete; status=gone; reason="上游已删除, 本地有 $ahead 个独有提交(已授权 -f)"
		else
			action=keep; status=skip; reason="上游已删除但本地有 $ahead 个独有提交(需 -f)"
		fi
	else
		ahead=$(ahead_count "$name")
		action=keep; status=skip; reason="未合并(领先 $ahead 个提交)"
	fi

	printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\n' \
		"$name" "$sha" "$ts" "$track" "$action" "$status" "$reason" >>"$LOCAL_TSV"
done < <(git for-each-ref --sort=committerdate --format='%(refname:short)%09%(objectname)%09%(committerdate:unix)%09%(upstream:track)' refs/heads)

# 远程分支
if [ "$CLEAN_REMOTE" = 1 ] && [ -n "$DEFAULT_REMOTE" ]; then
	while IFS=$'\t' read -r refname sha; do
		[ -n "$refname" ] || continue
		case "$refname" in refs/remotes/origin/HEAD) continue ;; esac
		rname=${refname#refs/remotes/origin/}
		[ "$rname" = "$BASE" ] && continue
		keep_by_pattern "$rname" && continue
		if git merge-base --is-ancestor "$sha" "refs/remotes/origin/$BASE" 2>/dev/null; then
			printf '%s\037%s\037%s\037%s\037%s\n' "$rname" "$sha" delete merged "已合并到 origin/$BASE" >>"$REMOTE_TSV"
		elif [ "$CHECK_SQUASH" = 1 ] && [ "$(git merge-tree --write-tree "refs/remotes/origin/$BASE" "$refname" 2>/dev/null | head -n 1)" = "$(git rev-parse "refs/remotes/origin/$BASE^{tree}" 2>/dev/null)" ]; then
			printf '%s\037%s\037%s\037%s\037%s\n' "$rname" "$sha" delete squash "合回 origin/$BASE 不改变内容" >>"$REMOTE_TSV"
		elif [ "$CHECK_PATCHES" = 1 ] && [ "$(git cherry "refs/remotes/origin/$BASE" "refs/remotes/origin/$rname" 2>/dev/null | grep -c '^+')" -eq 0 ]; then
			printf '%s\037%s\037%s\037%s\037%s\n' "$rname" "$sha" delete patch "补丁已全在 origin/$BASE" >>"$REMOTE_TSV"
		else
			printf '%s\037%s\037%s\037%s\037%s\n' "$rname" "$sha" keep skip "未合并到 origin/$BASE" >>"$REMOTE_TSV"
		fi
	done < <(git for-each-ref --format='%(refname)%09%(objectname)' refs/remotes/origin)
fi

# ---------------------------------------------------------------- 输出/执行
n_del=0
n_keep=0
n_skip=0
while IFS=$SEP read -r name sha ts track action status reason; do
	[ -n "$name" ] || continue
	case "$status" in
	merged | squash | patch | pr | gone) n_del=$((n_del + 1)) ;;
	protect) n_keep=$((n_keep + 1)) ;;
	*) n_skip=$((n_skip + 1)) ;;
	esac
	[ "$JSON" = 1 ] && continue
	[ "$QUIET" = 1 ] && continue
	if [ "$action" = delete ]; then
		printf '[删除] %s\t%s\n' "$name" "$reason"
	else
		printf '[保留] %s\t%s\n' "$name" "$reason"
	fi
done <"$LOCAL_TSV"

if [ "$JSON" != 1 ] && [ "$CLEAN_REMOTE" = 1 ] && [ -n "$DEFAULT_REMOTE" ] && [ -s "$REMOTE_TSV" ]; then
	printf '\n== 远程分支 (origin) ==\n'
	while IFS=$SEP read -r rname sha action status reason; do
		[ -n "$rname" ] || continue
		if [ "$action" = delete ]; then
			printf '[删除远程] %s\t%s\n' "$rname" "$reason"
		else
			printf '[保留远程] %s\t%s\n' "$rname" "$reason"
		fi
	done <"$REMOTE_TSV"
fi

# 真正执行
executed=0
failed=0
rdel=0
rfailed=0
if [ "$DRY_RUN" = 0 ]; then
	del_total=0
	while IFS=$SEP read -r name sha ts track action status reason; do
		[ -n "$name" ] || continue
		[ "$action" = delete ] || continue
		del_total=$((del_total + 1))
		case "$status" in
		merged | gone) delete_local "$name" "$sha" safe || failed=$((failed + 1)) ;;
		*) delete_local "$name" "$sha" force || failed=$((failed + 1)) ;;
		esac
	done <"$LOCAL_TSV"
	executed=$((del_total - failed))
	if [ "$JSON" != 1 ]; then
		log "已删除 $executed 个本地分支"
		[ "$failed" -gt 0 ] && log "有 $failed 个本地分支删除失败, 见上面的 git 输出"
	fi

	if [ "$CLEAN_REMOTE" = 1 ] && [ -n "$DEFAULT_REMOTE" ]; then
		while IFS=$SEP read -r rname sha action status reason; do
			[ -n "$rname" ] || continue
			[ "$action" = delete ] || continue
			out=$(git push --quiet "$DEFAULT_REMOTE" --delete "$rname" 2>&1)
			rc=$?
			[ -n "$out" ] && printf '%s\n' "$out" | indent_out
			if [ "$rc" -eq 0 ]; then
				rdel=$((rdel + 1))
			else
				rfailed=$((rfailed + 1))
			fi
		done <"$REMOTE_TSV"
		[ "$rdel" -gt 0 ] && log "已删除 $rdel 个远程分支"
		[ "$rfailed" -gt 0 ] && log "有 $rfailed 个远程分支删除失败"
	fi
fi
if [ "$JSON" = 1 ]; then
	printf '{"repo":"%s","base":"%s","backup":"refs/backup/branch-cleaner/%s/","dryRun":%s,"deleted":{"local":%s,"remote":%s},"failed":{"local":%s,"remote":%s},"local":[' \
		"$(json_escape "$(git rev-parse --show-toplevel)")" "$(json_escape "$BASE")" "$TS" \
		"$([ "$DRY_RUN" = 1 ] && echo true || echo false)" \
		"$executed" "$rdel" "$failed" "$rfailed"
	first=1
	while IFS=$SEP read -r name sha ts track action status reason; do
		[ -n "$name" ] || continue
		[ "$first" = 1 ] || printf ','
		first=0
		printf '{"name":"%s","sha":"%s","action":"%s","status":"%s","reason":"%s"}' \
			"$(json_escape "$name")" "$sha" "$action" "$status" "$(json_escape "$reason")"
	done <"$LOCAL_TSV"
	printf '],"remote":['
	first=1
	while IFS=$SEP read -r rname sha action status reason; do
		[ -n "$rname" ] || continue
		[ "$first" = 1 ] || printf ','
		first=0
		printf '{"name":"%s","sha":"%s","action":"%s","status":"%s","reason":"%s"}' \
			"$(json_escape "$rname")" "$sha" "$action" "$status" "$(json_escape "$reason")"
	done <"$REMOTE_TSV"
	printf ']}\n'
	exit 0
fi

printf '\n共 %d 个本地分支: 可删 %d, 保护 %d, 跳过 %d\n' \
	"$((n_del + n_keep + n_skip))" "$n_del" "$n_keep" "$n_skip"
if [ "$DRY_RUN" = 1 ] && [ "$n_del" -gt 0 ]; then
	printf '当前是 dry-run, 加 --yes 才会真正删除(删除前自动备份到 refs/backup/branch-cleaner/%s/)\n' "$TS"
fi
if [ "$BACKUP" = 1 ] && [ "$DRY_RUN" = 0 ] && [ "$n_del" -gt 0 ]; then
	printf '恢复任意分支: git branch <分支名> <备份 ref 里的 sha>\n'
	printf '查看备份:   git for-each-ref refs/backup/branch-cleaner/%s/\n' "$TS"
fi
[ $((failed + rfailed)) -gt 0 ] && exit 1
exit 0
