#!/usr/bin/env python3
"""repo-update —— 主仓 + 子仓的重复性维护入口.

设计目标(见 ai/coding/repetitive-ops-automation.md):
  常态路径只输出一行 `ok ...`;异常只输出结构化信封(错误码 + 最小字段),
  由 rules.toml 承接已知错误的自动修法,未知错误才交给 AI/人。

用法:
  repo-update.py --explain              # 打印逻辑摘要(给 AI 的最小上下文)
  repo-update.py --dry-run              # 只采集 + 出计划,不动任何东西
  repo-update.py --apply                # 执行
  repo-update.py --apply --no-push      # 执行到提交指针,不推
  repo-update.py --apply --resume       # 断点续跑
  repo-update.py --self-test            # 纯函数自测
  repo-update.py --json ...             # 成功行与信封都走 JSON

退出码: 0 成功 / 2 需人决策 / 3 可重试 / 4 已自愈 / 5 未知
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
CODES_MD = HERE / "codes.md"
RULES_TOML = HERE / "rules.toml"
STATE_DIR = Path(os.environ.get("REPO_UPDATE_STATE", "/tmp/repo-update"))
STEPS = ("preflight", "fetch", "rebase-subs", "ff-main", "commit-pointers", "push", "verify")
ENVELOPE_KEYS = ("step", "rc", "code", "affected", "stderr_tail", "hint", "reversible", "rollback", "suggested_next", "log")

# 退出码语义见 codes.md
EXIT_OK, EXIT_ASK, EXIT_RETRY, EXIT_FIXED, EXIT_UNKNOWN = 0, 2, 3, 4, 5


# ---------------------------------------------------------------- 过程控制


@dataclass
class Run:
    repo: Path
    run_id: str
    log_dir: Path
    apply: bool
    push: bool
    json_out: bool
    timeout: int
    start_head: str = ""
    start_origin: str = ""
    done: list[str] = field(default_factory=list)
    fixed: list[str] = field(default_factory=list)
    warns: list[str] = field(default_factory=list)
    staged: list[str] = field(default_factory=list)
    pushed_subs: list[str] = field(default_factory=list)

    def log_file(self, step: str) -> Path:
        return self.log_dir / f"{step}.log"

    def event(self, step: str, code: str = "", affected: str = "") -> None:
        ev = {"ts": round(time.time(), 3), "run": self.run_id, "step": step, "code": code, "affected": affected}
        with (self.log_dir / "events.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(ev, ensure_ascii=False) + "\n")


def git(args: list[str], cwd: Path, timeout: int = 120) -> tuple[int, str, str]:
    """跑一条 git(或任意)命令,永不抛异常,把输出截断保存。"""
    cmd = ["git", *args]
    try:
        cp = subprocess.run(
            cmd, cwd=str(cwd), timeout=timeout, capture_output=True,
            text=True, encoding="utf-8", errors="replace",
        )
        return cp.returncode, cp.stdout or "", cp.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", f"timeout after {timeout}s: {' '.join(args)}"
    except FileNotFoundError as exc:
        return 127, "", str(exc)


def tail(text: str, n: int = 20) -> list[str]:
    return [line.rstrip() for line in text.strip().splitlines()[-n:]]


def write_log(run: Run, step: str, text: str) -> None:
    with run.log_file(step).open("a", encoding="utf-8") as fh:
        fh.write(text if text.endswith("\n") else text + "\n")


# ---------------------------------------------------------------- 信封 / 退出


def envelope(run: Run, *, step: str, rc: int, code: str, affected: list[str],
             stderr: str = "", hint: list[str] | None = None, reversible: bool = True,
             rollback: str = "", suggested_next: list[str] | None = None) -> None:
    """只把最小字段交给调用方(AI);完整日志留在 log 路径里。"""
    env = {
        "step": step,
        "rc": rc,
        "code": code,
        "affected": affected,
        "stderr_tail": tail(stderr, 20),
        "hint": hint or [],
        "reversible": reversible,
        "rollback": rollback,
        "suggested_next": suggested_next or [],
        "log": str(run.log_file(step)),
    }
    assert set(env) == set(ENVELOPE_KEYS), "信封字段漂移"
    run.event(step, code, ",".join(affected))
    print(json.dumps(env, ensure_ascii=False), file=sys.stderr)
    if not run.json_out:
        print(f"  ({code} 的说明见 {CODES_MD.name};完整日志 {env['log']})", file=sys.stderr)


def bail(run: Run, exit_code: int, **kw) -> "NoReturn":  # type: ignore[name-defined]
    rc = kw.pop("rc", 1)
    envelope(run, rc=rc, **kw)
    raise SystemExit(exit_code)


# ---------------------------------------------------------------- 采集


@dataclass
class Sub:
    path: str
    head: str
    index: str
    flag: str  # ' ' 一致 / '+' 指针不同 / '-' 未初始化

    @property
    def pointer_differs(self) -> bool:
        return self.index and self.head and self.index != self.head


def parse_submodule_status(text: str) -> list[Sub]:
    """解析 `git submodule status` 的一行: 前缀 + sha + 空格 + 路径 (可带 (heads/xxx))。"""
    subs: list[Sub] = []
    for line in text.splitlines():
        if not line.strip():
            continue
        flag, rest = line[0], line[1:].strip()
        parts = rest.split(None, 1)
        if len(parts) != 2:
            continue
        sha, path = parts[0], parts[1].split(" (")[0].strip()
        # 注意: status 行里的 sha 是"工作区检出"的提交,不是索引里的指针,
        # 指针必须另取 `git rev-parse :<path>`,否则比较永远相等(实测踩过)。
        subs.append(Sub(path=path, head=sha, index="", flag=flag))
    return subs


def collect(run: Run) -> list[Sub]:
    # 注意: 不要加 --recursive —— 嵌套子模块的 .gitmodules 映射一旦坏了,
    # git 会中途报错并截断输出,导致后面的子仓被漏采(实测踩过)。
    rc, out, err = git(["submodule", "status"], run.repo)
    write_log(run, "collect", out + err)
    subs = parse_submodule_status(out)
    keep: list[Sub] = []
    for sub in subs:
        if sub.flag == "-":
            continue  # 未初始化,不碰
        p = run.repo / sub.path
        r, h, _ = git(["rev-parse", "HEAD"], p, run.timeout)
        if r != 0:
            continue
        sub.head = h.strip()
        ri, idx, _ = git(["rev-parse", ":" + sub.path], run.repo, run.timeout)
        sub.index = idx.strip() if ri == 0 else ""
        keep.append(sub)
    return keep


# ---------------------------------------------------------------- 规则


def load_rules() -> dict[str, dict]:
    if not RULES_TOML.exists():
        return {}
    try:
        import tomllib

        with RULES_TOML.open("rb") as fh:
            return {r["code"]: r for r in tomllib.load(fh).get("rule", [])}
    except Exception:  # 规则文件坏了不应该挡住主流程
        return {}


# ---------------------------------------------------------------- 子仓主干判定


def sub_trunk(run: Run, sub: Sub) -> tuple[str | None, str]:
    """返回 (主干引用, 错误码)。优先级: upstream → 远端同名分支 → main → master。"""
    p = run.repo / sub.path
    rc, out, _ = git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], p, run.timeout)
    if rc == 0 and out.strip():
        return out.strip(), ""

    branch = git(["rev-parse", "--abbrev-ref", "HEAD"], p, run.timeout)[1].strip()
    rc, out, _ = git(["for-each-ref", "--format=%(refname)", "refs/remotes/"], p, run.timeout)
    remotes = [r for r in out.split() if r and not r.endswith("/HEAD")]

    candidates: list[str] = []
    if branch and branch != "HEAD":
        candidates += [r for r in remotes if r.endswith("/" + branch)]
    for name in ("main", "master"):
        candidates += [r for r in remotes if r.endswith("/" + name) and r not in candidates]
    if not candidates:
        return None, "WARN_NO_TRUNK"

    # 多个候选且互相分叉 → 主干不唯一,必须问人
    base = candidates[0]
    for other in candidates[1:]:
        c = git(["rev-list", "--left-right", "--count", f"{base}...{other}"], p, run.timeout)
        if c[0] != 0:
            continue
        behind, ahead = (int(x) for x in c[1].split())
        if behind and ahead:
            return None, "ASK_MULTI_TRUNK"
    return base, ""


def ahead_behind(run: Run, path: Path, left: str, right: str) -> tuple[int, int]:
    rc, out, _ = git(["rev-list", "--left-right", "--count", f"{left}...{right}"], path, run.timeout)
    if rc != 0:
        return -1, -1
    b, a = out.split()
    return int(b), int(a)


def is_published(run: Run, path: Path, ref: str = "HEAD") -> bool:
    rc, out, _ = git(["for-each-ref", "--contains", ref, "--format=%(refname)", "refs/remotes/"], path, run.timeout)
    return rc == 0 and bool(out.strip())


def has_worktree_changes(run: Run, path: Path) -> bool:
    """子仓工作区是否有非指针改动(有就不碰它)。"""
    rc, out, _ = git(["status", "--porcelain", "--untracked-files=no"], path, run.timeout)
    return rc == 0 and bool(out.strip())


# ---------------------------------------------------------------- 各步骤


def step_preflight(run: Run, dirty_policy: str) -> None:
    rc, out, err = git(["rev-parse", "--show-toplevel"], run.repo)
    if rc != 0:
        bail(run, EXIT_ASK, step="preflight", rc=rc, code="ERR_NOT_A_REPO",
             affected=[str(run.repo)], stderr=err)
    run.repo = Path(out.strip())
    run.start_head = git(["rev-parse", "HEAD"], run.repo, run.timeout)[1].strip()
    run.start_origin = git(["rev-parse", "--abbrev-ref", "@{u}"], run.repo, run.timeout)[1].strip()

    # 只采集一次,后面两步复用
    subs_found = collect(run)

    # gitfile 修复: .git/modules 有、工作区缺 .git
    for sub in subs_found:
        p = run.repo / sub.path
        gitfile = p / ".git"
        module = run.repo / ".git" / "modules" / sub.path
        if not gitfile.exists() and module.exists():
            rel = os.path.relpath(module, p)
            if run.apply:
                gitfile.write_text(f"gitdir: {rel}\n", encoding="utf-8")
                run.fixed.append("ERR_GITFILE_MISSING")
                run.event("preflight", "ERR_GITFILE_MISSING", sub.path)
            else:
                print(f"plan fix ERR_GITFILE_MISSING {sub.path}")

    # 主仓脏文件策略: 非子模块的已跟踪改动 → 默认停下问人
    rc, out, _ = git(["status", "--porcelain=v1"], run.repo, run.timeout)
    subs = {s.path for s in subs_found}
    blocked = []
    for line in out.splitlines():
        if not line.strip():
            continue
        code, path = line[:2], line[3:].strip().strip('"')
        if code == "??":
            run.warns.append(f"WARN_UNTRACKED {path}")
            continue
        if path in subs or any(path.startswith(s + "/") for s in subs):
            continue  # 子模块指针/内容变化由后面步骤处理
        blocked.append(path)
    if blocked:
        if dirty_policy == "ask":
            bail(run, EXIT_ASK, step="preflight", rc=0, code="ASK_DIRTY_WORKTREE",
                 affected=blocked, hint=["先提交或 stash 这些文件"],
                 suggested_next=["git status --porcelain"], reversible=True)
        run.warns.append("WARN_DIRTY_WORKTREE " + ",".join(blocked))
    run.done.append("preflight")


def step_fetch(run: Run) -> None:
    rc, out, err = git(["fetch", "--all", "--prune", "--quiet"], run.repo, run.timeout)
    write_log(run, "fetch", out + err)
    if rc != 0:
        run.warns.append("WARN_REMOTE_UNREACHABLE main:" + tail(err, 1)[0] if err.strip() else "WARN_REMOTE_UNREACHABLE main")
    run.done.append("fetch")


def step_rebase_subs(run: Run, all_subs: bool = False) -> None:
    changed = 0
    subs = collect(run)
    targets = subs if all_subs else [s for s in subs if s.pointer_differs]
    for sub in targets:
        p = run.repo / sub.path
        if has_worktree_changes(run, p):
            run.warns.append(f"WARN_SUB_DIRTY {sub.path}")
            continue
        trunk, code = sub_trunk(run, sub)
        if code == "ASK_MULTI_TRUNK":
            bail(run, EXIT_ASK, step="rebase-subs", rc=0, code=code, affected=[sub.path],
                 hint=["同一子仓的多个远端主干已分叉,选一个再继续"],
                 suggested_next=[f"git -C {shlex.quote(sub.path)} log --oneline --graph --all -12"],
                 reversible=False)
        if not trunk:
            run.warns.append(f"{code} {sub.path}")
            continue
        rr, out, err = git(["fetch", "--quiet", "--all", "--prune"], p, run.timeout)
        if rr != 0:
            run.warns.append(f"WARN_REMOTE_UNREACHABLE {sub.path}")
        behind, ahead = ahead_behind(run, p, trunk, "HEAD")
        if behind <= 0:
            continue
        if ahead > 0 and is_published(run, p):
            bail(run, EXIT_ASK, step="rebase-subs", rc=0, code="ASK_HISTORY_REWRITE",
                 affected=[sub.path],
                 hint=[f"{sub.path} 有已推送的本地提交,rebase 会改写公开历史"],
                 suggested_next=[f"git -C {shlex.quote(sub.path)} log --oneline {trunk}..HEAD"],
                 reversible=False)
        rb, o, e = git(["rebase", trunk], p, run.timeout)
        write_log(run, "rebase-subs", f"{sub.path} rebase {trunk}: rc={rb}\n{o}{e}")
        if rb != 0:
            git(["rebase", "--abort"], p, run.timeout)
            bail(run, EXIT_UNKNOWN, step="rebase-subs", rc=rb, code="ERR_REBASE_CONFLICT",
                 affected=[sub.path], stderr=e, hint=["冲突需要人判断"],
                 rollback=f"git -C {shlex.quote(sub.path)} rebase --abort", reversible=True)
        changed += 1
        run.event("rebase-subs", "", sub.path)
    if not run.apply:
        print(f"plan rebase-subs targets={len(targets)} changed={changed}")
    run.done.append("rebase-subs")


def step_ff_main(run: Run) -> None:
    if not run.start_origin:
        run.warns.append("WARN_NO_UPSTREAM main")
        run.done.append("ff-main")
        return
    behind, ahead = ahead_behind(run, run.repo, run.start_origin, "HEAD")
    if behind > 0 and ahead > 0:
        bail(run, EXIT_ASK, step="ff-main", rc=0, code="ASK_MAIN_DIVERGED",
             affected=["<主仓>"], hint=["主仓既有本地提交又落后远端"],
             suggested_next=["git log --oneline --graph --all -12"], reversible=False)
    if behind == 0:
        run.done.append("ff-main")
        return
    print(f"plan ff-main {behind} commits")
    if not run.apply:
        run.done.append("ff-main")
        return
    rc, out, err = git(["-c", "submodule.recurse=false", "rebase", run.start_origin], run.repo, run.timeout)
    write_log(run, "ff-main", out + err)
    if rc != 0:
        git(["rebase", "--abort"], run.repo, run.timeout)
        bail(run, EXIT_UNKNOWN, step="ff-main", rc=rc, code="ERR_MAIN_REBASE",
             affected=["<主仓>"], stderr=err, hint=["用 -c submodule.recurse=false 避免递归进子模块"],
             rollback="git rebase --abort", reversible=True)
    run.done.append("ff-main")


def step_commit_pointers(run: Run) -> None:
    subs = collect(run)
    stale = []
    for sub in subs:
        if not sub.pointer_differs:
            continue
        p = run.repo / sub.path
        rc, _, _ = git(["merge-base", "--is-ancestor", sub.index, sub.head], p, run.timeout)
        if rc != 0:
            stale.append(f"{sub.path} {sub.index[:7]}->{sub.head[:7]}")
            continue
        print(f"plan pointer {sub.path} {sub.index[:7]}->{sub.head[:7]}")
        run.staged.append(sub.path)
        if not run.apply:
            continue
        add_rc, add_out, add_err = git(["add", "--", sub.path], run.repo, run.timeout)
        staged = git(["diff", "--cached", "--name-only", "--", sub.path], run.repo, run.timeout)[1].strip()
        if add_rc != 0 and not staged:
            bail(run, EXIT_UNKNOWN, step="commit-pointers", rc=add_rc, code="ERR_ADD_FAILED",
                 affected=[sub.path], stderr=add_err, reversible=True)
        if add_rc != 0 and staged:
            run.fixed.append("WARN_IGNORED_PATH")
            run.event("commit-pointers", "WARN_IGNORED_PATH", sub.path)

    if stale:
        bail(run, EXIT_ASK, step="commit-pointers", rc=0, code="ASK_STALE_POINTER",
             affected=stale, hint=["索引里的指针不是 HEAD 的祖先(旧指针/悬空对象),不能自动降级"],
             suggested_next=["git submodule status --recursive"], reversible=True)

    if not run.apply:
        run.done.append("commit-pointers")
        return
    if not run.staged:
        run.done.append("commit-pointers")
        return
    if git(["rev-parse", "HEAD"], run.repo, run.timeout)[1].strip() != run.start_head:
        bail(run, EXIT_ASK, step="commit-pointers", rc=0, code="ERR_HEAD_MOVED",
             affected=["<主仓>"], hint=["提交前发现 HEAD 已变(疑似并发会话),停止"],
             reversible=True)
    msg = "chore: 同步子模块指针\n\n" + "\n".join(f"- {p}" for p in run.staged) + "\n"
    rc, out, err = git(["commit", "-m", msg], run.repo, run.timeout)
    write_log(run, "commit-pointers", out + err)
    if rc != 0:
        bail(run, EXIT_UNKNOWN, step="commit-pointers", rc=rc, code="ERR_COMMIT_FAILED",
             affected=run.staged, stderr=err, reversible=True,
             suggested_next=["git diff --cached --name-status"])
    run.event("commit-pointers", "", ",".join(run.staged))
    run.done.append("commit-pointers")


def step_push(run: Run) -> None:
    if not run.push:
        run.done.append("push")
        return
    if not run.apply:
        for sub in collect(run):
            p = run.repo / sub.path
            if git(["rev-parse", "--abbrev-ref", "@{u}"], p, run.timeout)[0] == 0:
                _, ahead = ahead_behind(run, p, "@{u}", "HEAD")
                if ahead > 0:
                    print(f"plan push {sub.path} ({ahead} commits)")
        run.done.append("push")
        return
    # 子仓先推,主仓后推:主仓指针必须指向"远端已存在"的提交
    failed: list[str] = []
    for sub in collect(run):
        p = run.repo / sub.path
        rc_up, up, _ = git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], p, run.timeout)
        if rc_up != 0:
            continue
        _, ahead = ahead_behind(run, p, "@{u}", "HEAD")
        if ahead <= 0:
            continue
        remote = up.strip().split("/", 1)[0]
        print(f"plan push {sub.path} -> {remote} ({ahead} commits)")
        rc, out, err = git(["push", remote, "HEAD"], p, max(run.timeout, 300))
        write_log(run, "push", f"{sub.path}: rc={rc}\n{out}{err}")
        if rc != 0:
            run.warns.append(f"WARN_REMOTE_UNREACHABLE {sub.path}")
            failed.append(sub.path)
        else:
            run.pushed_subs.append(sub.path)

    # 刚提交的指针里,只要有一个子仓没推上去,就不推主仓
    blocked = [p for p in failed if p in run.staged]
    if blocked:
        bail(run, EXIT_RETRY, step="push", rc=0, code="ERR_SUBMODULE_PUSH_FAILED",
             affected=blocked, hint=["子仓提交没推上去,主仓指针不能指向不存在的提交"],
             suggested_next=[f"git -C {shlex.quote(p)} push" for p in blocked],
             reversible=True)

    branch = git(["rev-parse", "--abbrev-ref", "HEAD"], run.repo, run.timeout)[1].strip()
    rc, out, err = git(["push", "--no-recurse-submodules", "origin", branch], run.repo, max(run.timeout, 300))
    write_log(run, "push", out + err)
    if rc != 0:
        bail(run, EXIT_RETRY, step="push", rc=rc, code="ERR_PUSH_REJECTED", affected=[branch],
             stderr=err, hint=["常见原因: 远端有新提交 / 钩子拒绝 / 网络"],
             suggested_next=[f"git -c submodule.recurse=false pull --rebase && git push --no-recurse-submodules origin {branch}"],
             reversible=False)
    run.event("push", "", branch)
    run.done.append("push")


def step_verify(run: Run) -> None:
    subs = [s for s in collect(run) if s.pointer_differs]
    head = git(["rev-parse", "HEAD"], run.repo, run.timeout)[1].strip()
    state = "ok"
    if subs:
        state = "pending-pointers"
    print(f"{state} steps={len(run.done)} pointers={len(run.staged)} fixed={len(run.fixed)} "
          f"warnings={len(run.warns)} pushed_subs={len(run.pushed_subs)} head={head[:9]}")
    if run.warns and run.json_out:
        print(json.dumps({"warnings": run.warns}, ensure_ascii=False), file=sys.stderr)
    run.event("verify", "", "")
    run.done.append("verify")


# ---------------------------------------------------------------- 状态/自测


def save_state(run: Run, args: argparse.Namespace) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "state.json").write_text(json.dumps({
        "run": run.run_id, "done": run.done, "warns": run.warns,
        "flags": {"no_push": not run.push, "repo": str(run.repo)},
    }, ensure_ascii=False, indent=2), encoding="utf-8")


def load_done() -> list[str]:
    try:
        return json.loads((STATE_DIR / "state.json").read_text(encoding="utf-8")).get("done", [])
    except Exception:
        return []


def self_test() -> int:
    fails = 0

    def check(name: str, cond: bool) -> None:
        nonlocal fails
        print(("  ok   " if cond else "  FAIL ") + name)
        if not cond:
            fails += 1

    subs = parse_submodule_status(
        " 5eb0da1 c/x (heads/master)\n+90dcfa9 d/y (heads/main)\n-097da9d e/z\n"
    )
    check("解析: 一致行 flag 为空格", subs[0].flag == " " and subs[0].path == "c/x")
    check("解析: '+' 标记且路径去括号", subs[1].flag == "+" and subs[1].path == "d/y")
    check("解析: '-' 未初始化", subs[2].flag == "-" and subs[2].path == "e/z")
    check("解析: 索引 SHA 不从 status 行取", subs[1].index == "")
    check("信封字段固定", set(ENVELOPE_KEYS) == {
        "step", "rc", "code", "affected", "stderr_tail", "hint",
        "reversible", "rollback", "suggested_next", "log"})
    check("tail 截断到 n 行", len(tail("\n".join(str(i) for i in range(50)), 20)) == 20)

    rules = load_rules()
    if rules:
        codes = set(re.findall(r"`([A-Z][A-Z0-9_]+)`", CODES_MD.read_text(encoding="utf-8"))) if CODES_MD.exists() else set()
        missing = [c for c in rules if c not in codes]
        check(f"规则都在 codes.md 里({len(rules)} 条)", not missing)
        if missing:
            print("     缺失:", missing)
    else:
        print("  skip rules.toml 为空")
    print(f"self-test: {'PASS' if not fails else f'{fails} FAILED'}")
    return EXIT_OK if not fails else EXIT_UNKNOWN


# ---------------------------------------------------------------- 入口


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        description="主仓 + 子仓的重复性维护(常态一行输出,异常一个信封)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="退出码: 0 成功 / 2 需人决策 / 3 可重试 / 4 已自愈 / 5 未知",
    )
    ap.add_argument("--repo", default=os.getcwd(), help="主仓路径,默认当前目录")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="只采集 + 出计划")
    g.add_argument("--apply", action="store_true", help="执行")
    g.add_argument("--explain", action="store_true", help="打印逻辑摘要(给 AI 的最小上下文)")
    g.add_argument("--self-test", action="store_true", help="纯函数自测")
    ap.add_argument("--json", action="store_true", help="成功行/警告也走 JSON")
    ap.add_argument("--resume", action="store_true", help="跳过 state.json 里已完成步骤")
    ap.add_argument("--no-push", action="store_true", help="只做到提交指针,不推送")
    ap.add_argument("--all-subs", action="store_true",
                    help="体检全部子仓(默认只处理指针变了的那些)")
    ap.add_argument("--dirty", choices=("ask", "warn"), default="ask",
                    help="主仓有非子模块脏文件时: ask 停下(默认) / warn 继续")
    ap.add_argument("--timeout", type=int, default=180, help="单条命令超时秒数")
    return ap


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)

    if args.explain:
        print(CODES_MD.read_text(encoding="utf-8") if CODES_MD.exists() else "(codes.md 缺失)")
        return EXIT_OK
    if args.self_test:
        return self_test()

    if not args.dry_run and not args.apply:
        build_parser().print_help()
        return EXIT_ASK

    stamp = time.strftime("%Y%m%dT%H%M%S", time.gmtime())
    run = Run(
        repo=Path(args.repo).resolve(),
        run_id=f"{stamp}-{os.getpid()}",
        log_dir=STATE_DIR / "logs" / f"{stamp}-{os.getpid()}",
        apply=args.apply,
        push=not args.no_push,
        json_out=args.json,
        timeout=args.timeout,
    )
    run.log_dir.mkdir(parents=True, exist_ok=True)
    done_before = set(load_done()) if args.resume else set()

    steps = {
        "preflight": lambda: step_preflight(run, args.dirty),
        "fetch": lambda: step_fetch(run),
        "rebase-subs": lambda: step_rebase_subs(run, args.all_subs),
        "ff-main": lambda: step_ff_main(run),
        "commit-pointers": lambda: step_commit_pointers(run),
        "push": lambda: step_push(run),
        "verify": lambda: step_verify(run),
    }
    try:
        for name in STEPS:
            if name in done_before and name not in ("verify",):
                print(f"skip {name} (resume)")
                continue
            steps[name]()
    finally:
        save_state(run, args)
    return EXIT_OK if not run.warns or run.apply else EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
