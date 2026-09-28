#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验任务书(AGENT-TASK.md)附录 B 里手写的 YAML 是否能直接用。

动机: 附录 B 是"不走脚本、照抄配置"的兜底路径, 那两段 YAML 是手写的, 和
probe_gateway.py 生成的配置是两份东西 —— 很容易改了生成器忘了改文档。
这里把文档里的代码块原样抽出来跑一遍: dump-config 能看到路由, 冒烟能拿到回复,
才算文档没过期。

    python3 check_doc_examples.py AGENT-TASK.md http://127.0.0.1:18500 /tmp/dir \
        node /path/to/dsh/lib/bin.js
"""

from __future__ import annotations

import os
import pathlib
import re
import shutil
import subprocess
import sys


def _force_utf8_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def run(dsh: list[str], env: dict, *args: str, timeout: int = 300):
    return subprocess.run(dsh + list(args), capture_output=True, text=True,
                          env=env, timeout=timeout)


def main() -> int:
    _force_utf8_stdio()
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    doc_path, gateway, workdir = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
    dsh = sys.argv[4:]

    doc = pathlib.Path(doc_path).read_text(encoding="utf-8")
    blocks = [b for b in re.findall(r"```yaml\n(.*?)```", doc, re.S) if "- id:" in b]
    if len(blocks) < 2:
        print(f"  ❌ 文档里只找到 {len(blocks)} 段可用的 YAML(期望 2 段: OpenAI 版与 Claude 版)")
        return 1

    failed = 0
    for label, block in (("OpenAI 兼容", blocks[0]), ("Claude 对接", blocks[1])):
        name = "openai" if "llm-pi-ai" in block else "anthropic"
        home = workdir / name
        shutil.rmtree(home, ignore_errors=True)
        home.mkdir(parents=True)
        env_file = home / ".env"
        env_file.write_text("INTRANET_LLM_API_KEY=doc-check-key\n", encoding="utf-8")
        os.chmod(env_file, 0o600)
        (home / "cordis.patch.yml").write_text(block.replace("<GW>", gateway), encoding="utf-8")

        env = dict(os.environ, DSH_HOME=str(home), NODE_NO_WARNINGS="1")
        try:
            dumped = run(dsh, env, "--profile", "headless", "--dump-config", timeout=180)
            visible = ("intranet-gw" in dumped.stdout) or ("llm-deepseek" in dumped.stdout)
            smoke = run(dsh, env, "--profile", "headless", "只回答两个字：正常")
        except subprocess.TimeoutExpired:
            print(f"  ❌ [{label}] 超时")
            failed += 1
            continue

        if dumped.returncode == 0 and visible and smoke.returncode == 0 and smoke.stdout.strip():
            print(f"  ✅ [{label}] 文档里的 YAML 原样可用(路由可见 + 冒烟有回复)")
        else:
            failed += 1
            print(f"  ❌ [{label}] dump={dumped.returncode} 路由可见={visible} "
                  f"冒烟={smoke.returncode}")
            tail = (smoke.stdout + smoke.stderr).strip().splitlines()
            if tail:
                print(f"       {tail[-1][:160]}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
