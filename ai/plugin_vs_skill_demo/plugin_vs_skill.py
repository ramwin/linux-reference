#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DSH 插件 / DSH skill / Claude Code skill 三者的最小对照实验, 零依赖纯 Python。

不靠记忆, 直接读本机真实的安装目录, 把"哪些是代码、哪些是文本"数出来:

  1. DSH 插件包   -> package.json 里的 `dsh` 字段(声明了什么)+ lib/ 里的可执行代码
  2. DSH skill    -> SKILL.md 的 frontmatter(声明了什么)+ 正文里有没有可执行的东西
  3. Claude skill -> 同上, 但 root 不同, 且会多出 fork / 动态注入等字段

判定标准只有一条: **组件是否能让宿主执行一段代码**。
  * 插件: package.json 有 `dsh` 字段, 且 main/exports 指向真实存在的 .js 文件
  * skill: 正文里出现 !`cmd` 或 ```! 代码块(渲染时由宿主执行), 以及 allowed-tools 授权

    python3 ai/plugin_vs_skill_demo/plugin_vs_skill.py                    # 用默认路径
    python3 ai/plugin_vs_skill_demo/plugin_vs_skill.py --json             # 只输出机器可读结果
    python3 ai/plugin_vs_skill_demo/plugin_vs_skill.py --dsh-profile ~/.dsh/profiles/web

需要 Python 3.8+, 无第三方依赖。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

# ------------------------------------------------------------------ frontmatter

FM_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*(?:\n|\Z)", re.S)
# 动态注入: 行首或空白之后的 !`cmd`
INJECT_RE = re.compile(r"(?:^|\s)!`[^`]+`", re.M)
INJECT_BLOCK_RE = re.compile(r"^```!\s*$", re.M)


def split_frontmatter(path: Path) -> tuple[dict, str]:
    """返回 (frontmatter 字典, 正文)。解析失败就返回空 frontmatter, 不抛异常。"""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}, ""
    m = FM_RE.match(text)
    if not m:
        return {}, text
    fm = _parse_simple_yaml(m.group(1))
    return fm, text[m.end():]


def _parse_simple_yaml(block: str) -> dict:
    """把 frontmatter 当简单 YAML 解析: 支持 key: value 与缩进列表 / 行内列表。

    缩进列表有两种写法, 都要认:
        allowed-tools:            allowed-tools: Read, Glad
          - Read
    """
    data: dict = {}
    pending: str | None = None   # 上一行是 "key:"(没值), 后续缩进项归它
    for raw in block.splitlines():
        line = raw.rstrip()
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        # 缩进列表项: 必须真的以 "-" 开头。块状 YAML 里键总在第 0 列,
        # 所以除了列表项, 没有别的缩进内容需要认。
        if line[0] in " \t" and stripped.startswith("-"):
            item = stripped.lstrip("-").strip().strip("'\"")
            if item and pending:
                # 不能直接用 setdefault: 键已经在上一行被写成 None 了。
                if not isinstance(data.get(pending), list):
                    data[pending] = []
                data[pending].append(item)
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if not value:
            data[key] = None
            pending = key
            continue
        if value.startswith("[") and value.endswith("]"):
            data[key] = [v.strip().strip("'\"") for v in value[1:-1].split(",") if v.strip()]
        else:
            data[key] = value.strip("'\"")
        pending = None
    return data


def as_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"true", "yes", "on", "1"}


# ------------------------------------------------------------------ skill 扫描

# (来源标记, 展示用的根名, 相对路径或 ~ 开头)
SKILL_ROOTS = [
    ("dsh", "项目级 (.dsh/skills)",      ".dsh/skills"),
    ("dsh", "项目级 (.agents/skills)",   ".agents/skills"),
    ("dsh", "用户级 (~/.dsh/skills)",    "~/.dsh/skills"),
    ("dsh", "用户级 (~/.agents/skills)", "~/.agents/skills"),
    ("claude", "Claude 用户级 (~/.claude/skills)", "~/.claude/skills"),
    ("claude", "Claude 项目级 (.claude/skills)",   ".claude/skills"),
]


def find_project_root(start: Path) -> Path:
    """DSH 的约定: 最近一个含 .git 的祖先目录, 没有就用当前目录。"""
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / ".git").exists():
            return candidate
    return cur


def expand_root(spec: str, project_root: Path) -> Path:
    if spec.startswith("~/"):
        return Path(os.path.expanduser("~")) / spec[2:]
    return project_root / spec


def scan_skill_root(root: Path, spec: str) -> list[dict]:
    """扫描一个 skill 根: 支持 <name>/SKILL.md 与 <name>.md, 只扫一层。"""
    found = []
    if not root.is_dir():
        return found
    for entry in sorted(root.iterdir()):
        if entry.name.startswith("."):
            continue
        md = None
        if entry.is_dir() and (entry / "SKILL.md").is_file():
            md = entry / "SKILL.md"
        elif entry.is_file() and entry.suffix == ".md":
            md = entry
        if md is None:
            continue
        fm, body = split_frontmatter(md)
        tools = fm.get("allowed-tools") or fm.get("tools")
        if isinstance(tools, str):
            tools = [t for t in re.split(r"[,\s]+", tools) if t]
        found.append({
            "name": fm.get("name") or entry.stem,
            "description": (fm.get("description") or "").strip(),
            "path": str(md),
            "root": str(root),
            "spec": spec,
            "tools": tools or [],
            "injected_commands": len(INJECT_RE.findall(body)) + len(INJECT_BLOCK_RE.findall(body)),
            "forks_context": fm.get("context") == "fork",
            "model_invocable": not as_bool(fm.get("disable-model-invocation")),
            "user_invocable": as_bool(fm.get("user_invocable", fm.get("user-invocable", True))),
            "extra_fields": sorted(set(fm) - {"name", "description"}),
        })
    return found


# ------------------------------------------------------------------ 插件扫描

RUNTIME_SUFFIXES = {".js", ".cjs", ".mjs"}


def resolve_entry(pkg: Path, pkg_json: dict) -> Path | None:
    """找到包的运行时入口(真实存在的 .js 文件), 证明它是要被 require 的代码。

    只认 .js/.cjs/.mjs: exports 里排在最前的往往是类型声明(.d.ts), 那是给编辑器
    看的, 不是宿主执行的东西。
    """
    candidates = []
    exports = pkg_json.get("exports")
    if isinstance(exports, dict):
        for key, value in exports.items():
            if key in {"./package.json", "./typert"}:
                continue
            if isinstance(value, str):
                candidates.append(value)
            elif isinstance(value, dict):
                candidates += [v for v in value.values() if isinstance(v, str)]
    for key in ("main", "module"):
        if isinstance(pkg_json.get(key), str):
            candidates.append(pkg_json[key])
    for rel in candidates:
        if not rel.startswith("."):
            continue
        target = (pkg / rel).resolve()
        if target.is_file() and target.suffix in RUNTIME_SUFFIXES:
            return target
    return None


def scan_plugins(node_modules: Path) -> list[dict]:
    """遍历 node_modules 里带 `dsh` 字段的包 —— 它们就是 DSH 插件。"""
    found: dict[str, dict] = {}
    if not node_modules.is_dir():
        return []
    for manifest in sorted(node_modules.glob("*/package.json")) + sorted(node_modules.glob("@*/*/package.json")):
        try:
            pkg_json = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        dsh = pkg_json.get("dsh")
        if not isinstance(dsh, dict):
            continue
        pkg = manifest.parent
        real = str(pkg.resolve())
        if real in found:
            continue
        entry = resolve_entry(pkg, pkg_json)
        js_files = sum(1 for _ in pkg.glob("lib/**/*.js")) if (pkg / "lib").is_dir() else 0
        client = dsh.get("client")
        found[real] = {
            "name": pkg_json.get("name"),
            "version": pkg_json.get("version"),
            "description": (pkg_json.get("description") or "").strip(),
            "path": str(pkg),
            "entry": str(entry) if entry else None,
            "js_files": js_files,
            "has_patch": bool(isinstance(dsh.get("bundle"), dict) and dsh["bundle"].get("patch")),
            "browser_ui": bool(client.get("platform")) if isinstance(client, dict) else False,
            "client_injects": list(client.get("inject") or []) if isinstance(client, dict) else [],
            "peers": sorted((pkg_json.get("peerDependencies") or {}).keys()),
            "dsh_fields": sorted(dsh),
        }
    return sorted(found.values(), key=lambda p: (p["name"] or "").lower())


# ------------------------------------------------------------------ 输出


def fmt_table(headers: list[str], rows: list[list[str]]) -> str:
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))
    line = "  ".join(h.ljust(widths[i]) for i, h in enumerate(headers))
    sep = "  ".join("-" * w for w in widths)
    body = "\n".join("  ".join(str(c).ljust(widths[i]) for i, c in enumerate(row)) for row in rows)
    return f"{line}\n{sep}\n{body}"


def truncate(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"


def report(plugins: list[dict], skills: list[dict]) -> None:
    print("=" * 96)
    print("一、DSH 插件: 有 dsh 字段 + 有可执行入口")
    print("=" * 96)
    if not plugins:
        print("(没找到插件; 用 --dsh-profile 指定 profile 目录)")
    else:
        rows = []
        for p in plugins:
            rows.append([
                truncate(p["name"] or "?", 34),
                p["version"] or "?",
                "是" if p["entry"] else "否",
                str(p["js_files"]),
                "是" if p["has_patch"] else "-",
                "是" if p["browser_ui"] else "-",
                str(len(p["peers"])),
            ])
        print(fmt_table(["包名", "版本", "可执行入口", "lib 的 js 数", "改配置树", "浏览器 UI", "宿主 peer"], rows))
        print(f"\n共 {len(plugins)} 个插件。'可执行入口'=package.json 的 main/exports 指向真实存在的 .js。")
        sample = next((p for p in plugins if p["browser_ui"]), plugins[0])
        print(f"\n示例: {sample['name']}")
        print(f"  路径      : {sample['path']}")
        print(f"  入口      : {sample['entry']}")
        print(f"  dsh 字段  : {', '.join(sample['dsh_fields'])}")
        print(f"  peer 依赖 : {', '.join(sample['peers'][:3]) or '(无)'}")
        if sample["client_injects"]:
            print(f"  前端注入  : {', '.join(sample['client_injects'][:3])}")

    print()
    print("=" * 96)
    print("二、skill: 只有 SKILL.md, 没有可执行入口")
    print("=" * 96)
    if not skills:
        print("(没找到 skill; 用 --extra-skill-root 指定目录来对比)")
    else:
        rows = []
        for s in skills:
            rows.append([
                truncate(s["name"], 28),
                s["spec"],
                "是" if s["model_invocable"] else "否",
                "是" if s["user_invocable"] else "否",
                str(len(s["tools"])),
                str(s["injected_commands"]),
                "是" if s["forks_context"] else "-",
                truncate(s["root"].replace(str(Path.home()), "~"), 36),
            ])
        print(fmt_table(["skill", "体系", "模型可调", "用户可调", "授权工具数", "动态注入", "fork 子代理", "来源根"], rows))
        print(f"\n共 {len(skills)} 个 skill。前三列全是 frontmatter 声明, 不是代码。")

    print()
    print("=" * 96)
    print("三、结论: 唯一的分界线是「宿主会不会执行它」")
    print("=" * 96)
    total_js = sum(p["js_files"] for p in plugins)
    with_entry = sum(1 for p in plugins if p["entry"])
    with_inject = sum(1 for s in skills if s["injected_commands"])
    with_tools = sum(1 for s in skills if s["tools"])
    print(f"  插件 {len(plugins):>3} 个: {with_entry} 个有可执行入口, lib 下共 {total_js} 个 .js 文件")
    print(f"  skill {len(skills):>3} 个: {with_tools} 个声明了工具授权, {with_inject} 个含动态注入命令")
    print()
    print("  插件: 宿主 require() 它, 它在进程内注册工具/服务/UI, 能读写宿主状态。")
    print("  skill: 宿主把 Markdown 塞进上下文, 模型自己照着做; 唯一的例外是")
    print("         !`cmd` 动态注入 —— 那是宿主替模型跑命令, 但仍然只是把输出写进提示词,")
    print("         模型拿不到任何新增的工具、服务或界面。")
    print()
    print("  所以: 要「多一个能力」写插件; 要「让模型按某种方式做事」写 skill。")


def main() -> int:
    home = Path.home()
    parser = argparse.ArgumentParser(description="DSH 插件 / skill 对照实验")
    parser.add_argument("--dsh-profile", default=str(home / ".dsh/profiles/web"),
                        help="DSH profile 目录(默认 ~/.dsh/profiles/web)")
    parser.add_argument("--project", default=os.getcwd(), help="项目目录(默认当前目录)")
    parser.add_argument("--claude-marketplace",
                        default=str(home / ".claude/plugins/marketplaces/claude-plugins-official"),
                        help="Claude 插件市场目录, 用来对比它的 skills/")
    parser.add_argument("--extra-skill-root", action="append", default=[],
                        help="额外的 skill 根(可重复), 归到 claude 体系展示")
    parser.add_argument("--json", action="store_true", help="只输出 JSON")
    args = parser.parse_args()

    profile = Path(args.dsh_profile).expanduser()
    project_root = find_project_root(Path(args.project))

    plugins = scan_plugins(profile / "node_modules")

    skills: list[dict] = []
    for spec, _label, rel in SKILL_ROOTS:
        skills.extend(scan_skill_root(expand_root(rel, project_root), spec))

    # DSH 插件可以自带 skill: <plugin>/skills/<name>/SKILL.md
    for p in plugins:
        skills.extend(scan_skill_root(Path(p["path"]) / "skills", "dsh"))

    # Claude 插件市场里的 skill: <marketplace>/{plugins,external_plugins}/<plugin>/skills/<name>/SKILL.md
    for extra in args.extra_skill_root:
        skills.extend(scan_skill_root(Path(extra).expanduser(), "claude"))
    marketplace = Path(args.claude_marketplace).expanduser()
    for sub in ("plugins", "external_plugins"):
        base = marketplace / sub
        if base.is_dir():
            for plugin_dir in sorted(base.iterdir()):
                skills.extend(scan_skill_root(plugin_dir / "skills", "claude"))

    seen, unique = set(), []
    for s in skills:
        if s["path"] not in seen:
            seen.add(s["path"])
            unique.append(s)

    if args.json:
        print(json.dumps({"profile": str(profile), "project": str(project_root),
                          "plugins": plugins, "skills": unique}, ensure_ascii=False, indent=2))
        return 0

    print(f"DSH profile : {profile}")
    print(f"项目根目录  : {project_root}")
    print(f"Claude 市场 : {marketplace}")
    print()
    report(plugins, unique)
    return 0


if __name__ == "__main__":
    sys.exit(main())
