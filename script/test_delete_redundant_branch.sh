#!/usr/bin/env bash
# Xiang Wang(ramwin@qq.com)
#
# delete_redundant_branch.sh 的回归测试: 每个场景造一个临时仓库, 断言判断和删除结果.
#   ./test_delete_redundant_branch.sh        # 全跑, 输出 ok/FAIL, 有 FAIL 退出码 1
# 不依赖 bats / 网络 / 用户全局 git 配置.
set -uo pipefail

SCRIPT=$(cd "$(dirname "$0")" && pwd)/delete_redundant_branch.sh
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/branch-cleaner-test.XXXXXX")
trap 'cd /; rm -rf "$ROOT"' EXIT

# 临时仓库不继承全局 commit-msg / pre-commit 钩子(否则测试提交会被拦)
mkdir -p "$ROOT/nohooks"

FAIL=0
pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; FAIL=$((FAIL + 1)); }
assert() { # $1=描述 $2=实际 $3=期望
	if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (期望 [$3] 实际 [$2])"; fi
}
assert_exists() { # $1=描述 $2=分支
	if git rev-parse --verify --quiet "refs/heads/$2" >/dev/null; then pass "$1"; else fail "$1 (分支 $2 不存在)"; fi
}
assert_missing() {
	if git rev-parse --verify --quiet "refs/heads/$2" >/dev/null; then fail "$1 (分支 $2 还在)"; else pass "$1"; fi
}

# 从 --json 输出里取一个分支的 "action status"
judge() { # $1=json $2=分支
	python3 - "$1" "$2" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
for bucket in ("local", "remote"):
    for b in d.get(bucket, []):
        if b["name"] == sys.argv[2]:
            print(b["action"], b["status"]); raise SystemExit
print("absent absent")
PY
}

new_repo() { # $1=名字 → 打印仓库路径, 带一个本地 bare origin
	local name=$1 dir=$ROOT/$1
	mkdir -p "$dir"
	cd "$dir" || exit 1
	git init -q -b main
	git config user.email test@example.com
	git config user.name Test
	git config commit.gpgsign false
	git config core.hooksPath "$ROOT/nohooks"
	printf 'a\n' >a.txt
	git add a.txt
	git commit -qm init
	git init -q --bare "$ROOT/$name-origin.git"
	git remote add origin "$ROOT/$name-origin.git"
	git push -q -u origin main 2>/dev/null
	git remote set-head origin main >/dev/null 2>&1 || true
	printf '%s' "$dir"
}

add_commit() { # $1=分支 $2=文件 $3=内容 → 在 main 上开分支提交一次
	git checkout -q -b "$1" main
	printf '%s\n' "$3" >"$2"
	git add "$2"
	git commit -qm "$1"
	git checkout -q main
}

echo "== 1. 已合并分支: dry-run 不动, --yes 删除并留备份 =="
cd "$(new_repo r1)" || exit 1
add_commit feat-merged f1.txt one
git merge -q --no-ff feat-merged -m "merge feat-merged"
out=$("$SCRIPT" --json)
assert "已合并 → delete/merged" "$(judge "$out" feat-merged)" "delete merged"
assert_exists "dry-run 之后分支还在" feat-merged
out=$("$SCRIPT" --yes 2>&1)
assert_missing "--yes 之后分支被删除" feat-merged
backup=$(git for-each-ref --format='%(refname)' refs/backup/branch-cleaner/)
if [ -n "$backup" ]; then pass "删除前留下了备份 ref"; else fail "没有备份 ref"; fi
sha=$(git for-each-ref --format='%(objectname)' refs/backup/branch-cleaner/)
git branch feat-merged "$sha" 2>/dev/null && assert_exists "可以用备份恢复分支" feat-merged

echo "== 2. 未合并分支: 默认保留 =="
cd "$(new_repo r2)" || exit 1
add_commit feat-wip w.txt work
out=$("$SCRIPT" --json)
assert "未合并 → keep/skip" "$(judge "$out" feat-wip)" "keep skip"
out=$("$SCRIPT" --all --yes 2>&1)
assert_exists "未合并分支在 --all 下也保留" feat-wip

echo "== 3. squash 合并: 只有 --squash 才识别 =="
cd "$(new_repo r3)" || exit 1
add_commit feat-squash s.txt squash
git merge -q --squash feat-squash
git commit -qm "squash merge feat-squash"
assert "默认不认 squash 合并" "$(judge "$("$SCRIPT" --json)" feat-squash)" "keep skip"
assert "加 --squash 认出来" "$(judge "$("$SCRIPT" --squash --json)" feat-squash)" "delete squash"
"$SCRIPT" --squash --yes >/dev/null 2>&1
assert_missing "--squash --yes 删掉 squash 合并的分支" feat-squash

echo "== 4. rebase/cherry-pick 落地: 只有 --patches 才识别 =="
cd "$(new_repo r4)" || exit 1
add_commit feat-pick p.txt pick
sha=$(git rev-parse feat-pick)
# 先让 main 前进, 否则 cherry-pick 会直接复用原提交(变成快进), 测不出补丁等价
printf 'other\n' >other.txt
git add other.txt
git commit -qm "main moves on"
git cherry-pick "$sha" >/dev/null 2>&1
assert "默认不认补丁等价" "$(judge "$("$SCRIPT" --json)" feat-pick)" "keep skip"
assert "加 --patches 认出来" "$(judge "$("$SCRIPT" --patches --json)" feat-pick)" "delete patch"

echo "== 5. 上游已删除的分支 =="
cd "$(new_repo r5)" || exit 1
add_commit feat-gone g.txt gone
git push -q -u origin feat-gone
git checkout -q main
git push -q origin --delete feat-gone
git fetch -q --prune
assert "默认不管 gone" "$(judge "$("$SCRIPT" --json)" feat-gone)" "keep skip"
assert "gone 且有独有提交: 需 -f" "$(judge "$("$SCRIPT" --gone --json)" feat-gone)" "keep skip"
assert "-f 之后才删" "$(judge "$("$SCRIPT" --gone -f --json)" feat-gone)" "delete gone"

echo "== 6. 保护规则: 基线/当前分支/worktree/默认保留模式/自定义 -k =="
cd "$(new_repo r6)" || exit 1
add_commit release/1.0 rel.txt rel
git merge -q --no-ff release/1.0 -m merge-release
add_commit feat-current c.txt cur
git checkout -q feat-current
add_commit feat-wt w.txt wt
git worktree add -q "$ROOT/r6-wt" feat-wt 2>/dev/null
add_commit wip/idea i.txt idea
git merge -q --no-ff wip/idea -m merge-idea
add_commit maintenance m.txt m
git merge -q --no-ff maintenance -m merge-m
git checkout -q feat-current
out=$("$SCRIPT" -k 'wip/*' --json)
assert "release/* 受保护" "$(judge "$out" release/1.0)" "keep protect"
assert "当前分支受保护" "$(judge "$out" feat-current)" "keep protect"
assert "worktree 检出的分支受保护" "$(judge "$out" feat-wt)" "keep protect"
assert "-k 命中受保护" "$(judge "$out" wip/idea)" "keep protect"
assert "maintenance 不被 main 误伤" "$(judge "$out" maintenance)" "delete merged"
assert "main 永远是基线" "$(judge "$out" main)" "keep protect"

echo "== 7. 不切换当前分支, 不 rebase =="
cd "$(new_repo r7)" || exit 1
add_commit feat-a a.txt a7
git merge -q --no-ff feat-a -m merge-a
add_commit feat-b b.txt b7
git checkout -q feat-b
before=$(git rev-parse HEAD)
"$SCRIPT" --yes >/dev/null 2>&1
assert "仍停留在 feat-b" "$(git symbolic-ref --short HEAD)" "feat-b"
assert "HEAD 没被改写" "$(git rev-parse HEAD)" "$before"
assert "别的已合并分支被删" "$(judge "$("$SCRIPT" --json)" feat-a)" "absent absent"

echo "== 8. --age: 太新的分支不碰 =="
cd "$(new_repo r8)" || exit 1
git checkout -q -b feat-old main
printf 'old\n' >old.txt
git add old.txt
GIT_COMMITTER_DATE="$(date -d '40 days ago' -R)" GIT_AUTHOR_DATE="$(date -d '40 days ago' -R)" git commit -qm old
git checkout -q main
git merge -q --no-ff feat-old -m merge-old
add_commit feat-new n.txt new
git merge -q --no-ff feat-new -m merge-new
out=$("$SCRIPT" --age 30 --json)
assert "40 天前的分支可删" "$(judge "$out" feat-old)" "delete merged"
assert "刚提交的分支被年龄保护" "$(judge "$out" feat-new)" "keep protect"

echo "== 9. 指定基线 -b =="
cd "$(new_repo r9)" || exit 1
git checkout -q -b develop main
printf 'd\n' >d.txt
git add d.txt
git commit -qm dev
add_commit feat-on-dev x.txt x
git checkout -q develop
git merge -q --no-ff feat-on-dev -m merge-dev
git checkout -q main
assert "默认基线 main 时没合并" "$(judge "$("$SCRIPT" --json)" feat-on-dev)" "keep skip"
assert "-b develop 时认出来" "$(judge "$("$SCRIPT" -b develop --json)" feat-on-dev)" "delete merged"

echo "== 10. JSON 合法 =="
cd "$(new_repo r10)" || exit 1
add_commit feat-j j.txt j
if "$SCRIPT" --all --json | python3 -m json.tool >/dev/null 2>&1; then pass "--json 输出能被 python 解析"; else fail "--json 不是合法 JSON"; fi

echo "== 11. 子模块递归 =="
cd "$(new_repo r11)" || exit 1
mkdir -p "$ROOT/subrepo"
(
	cd "$ROOT/subrepo" || exit 1
	git init -q -b main
	git config user.email test@example.com
	git config user.name Test
	git config core.hooksPath "$ROOT/nohooks"
	printf 's\n' >s.txt
	git add s.txt
	git commit -qm init
	git checkout -q -b sub-merged
	printf 'm\n' >m.txt
	git add m.txt
	git commit -qm merged
	git checkout -q main
	git merge -q --no-ff sub-merged -m merge-sub
)
git -c protocol.file.allow=always submodule add -q "$ROOT/subrepo" sub >/dev/null 2>&1
git commit -qm "add sub"
add_commit feat-parent par.txt parent
git merge -q --no-ff feat-parent -m merge-parent
"$SCRIPT" --recurse-submodules --yes >/dev/null 2>&1
if git -C sub rev-parse --verify --quiet refs/heads/sub-merged >/dev/null; then
	fail "子模块里的已合并分支没被清理"
else
	pass "子模块里的已合并分支被清理"
fi
assert_missing "主仓自己的已合并分支也被清理" feat-parent

echo
if [ "$FAIL" -eq 0 ]; then
	printf '全部通过\n'
	exit 0
fi
printf '%d 个断言失败\n' "$FAIL"
exit 1
