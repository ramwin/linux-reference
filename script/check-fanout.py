#!/usr/bin/env python3
"""检查目录扇出（fanout）与深度，给人类和 AI 都留一条可读的目录树。

用法:
    python3 script/check-fanout.py                 # 检查当前目录
    python3 script/check-fanout.py --max 15        # 自定义单目录条目上限
    python3 script/check-fanout.py --strict        # 有越界就以 1 退出（用于 CI 门禁）
    python3 script/check-fanout.py --json          # 机器可读输出

默认阈值（见 ai/coding/folder-fanout-for-ai.md）:
    单目录条目数 ≤ 20，目录深度 ≤ 4 层。
"""

import argparse
import json
import os
import sys

# 默认不看的目录：版本库、构建产物、依赖、缓存
SKIP_DIRS = {
    ".git", ".hg", ".svn", "node_modules", "__pycache__", ".venv", "venv",
    ".mypy_cache", ".pytest_cache", ".ruff_cache", "dist", "build", "_build",
    ".next", ".nuxt", "target", "vendor", ".idea", ".tox", "coverage",
}


def measure(root: str):
    """返回 [(相对路径, 条目数, 深度)]，只统计目录。"""
    rows = []
    root = os.path.abspath(root)
    for cur, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        rel = os.path.relpath(cur, root)
        entries = len(dirs) + len(files)
        depth = 0 if rel == "." else rel.count(os.sep) + 1
        rows.append((rel, entries, depth))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description="检查目录扇出与深度")
    ap.add_argument("root", nargs="?", default=".", help="检查的根目录，默认当前目录")
    ap.add_argument("--max", type=int, default=20, help="单目录条目上限，默认 20")
    ap.add_argument("--max-depth", type=int, default=4, help="目录深度上限，默认 4")
    ap.add_argument("--top", type=int, default=15, help="最多打印多少条越界")
    ap.add_argument("--strict", action="store_true", help="有越界则返回非零退出码")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    args = ap.parse_args()

    rows = measure(args.root)
    fat = [r for r in rows if r[1] > args.max]
    deep = [r for r in rows if r[2] > args.max_depth]
    fat.sort(key=lambda r: -r[1])
    deep.sort(key=lambda r: -r[2])

    if args.json:
        print(json.dumps(
            {
                "root": os.path.abspath(args.root),
                "dirs": len(rows),
                "max_entries": args.max,
                "max_depth": args.max_depth,
                "over_entries": [{"path": p, "entries": n} for p, n, _ in fat],
                "over_depth": [{"path": p, "depth": d} for p, _, d in deep],
            },
            ensure_ascii=False,
            indent=2,
        ))
        return 1 if (fat or deep) and args.strict else 0

    print(f"根目录: {os.path.abspath(args.root)}")
    print(f"目录总数: {len(rows)}，单目录上限: {args.max}，深度上限: {args.max_depth}\n")

    if fat:
        print(f"条目超限（>{args.max}）: {len(fat)} 个目录")
        for p, n, _ in fat[: args.top]:
            print(f"  {n:4d}  {p}")
        if len(fat) > args.top:
            print(f"  ... 另有 {len(fat) - args.top} 个")
    else:
        print(f"条目超限（>{args.max}）: 无")

    if deep:
        print(f"\n深度超限（>{args.max_depth}）: {len(deep)} 个目录")
        for p, _, d in deep[: args.top]:
            print(f"  深度 {d}  {p}")
        if len(deep) > args.top:
            print(f"  ... 另有 {len(deep) - args.top} 个")
    else:
        print(f"\n深度超限（>{args.max_depth}）: 无")

    return 1 if (fat or deep) and args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
