#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""统计 mock 网关收到的请求: 谁发的、每个路径多少次、请求体顶层字段是什么。

用途: selftest 结束后一眼看清 DSH 到底按哪种协议、发了哪些字段。
按 User-Agent 把请求分成两类 —— DSH 自己发的(`deepseek-harness/...`)和
探测器发的(Python-urllib), 免得把探测请求的字段误当成 DSH 的字段。

    python3 summarize_requests.py /tmp/mock-gateway-requests.jsonl
"""

from __future__ import annotations

import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    buckets: dict[str, dict[str, dict]] = {"DSH": {}, "probe": {}}
    with open(sys.argv[1], encoding="utf-8") as fp:
        for line in fp:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            body = record.get("body") or {}
            agent = record.get("headers", {}).get("user-agent", "")
            who = "DSH" if "deepseek-harness" in agent else "probe"
            path = record.get("path", "?")
            entry = buckets[who].setdefault(path, {"count": 0, "keys": []})
            entry["count"] += 1
            # 同一路径上保留字段最多的请求体: 探测请求很抠, agent 请求最全
            if body and len(body) > len(entry["keys"]):
                entry["keys"] = sorted(body)

    if not any(buckets.values()):
        print("    (没有请求)")
        return 0

    for who, label in (("DSH", "DSH 发出的请求"), ("probe", "探测器发出的请求")):
        table = buckets[who]
        if not table:
            continue
        total = sum(item["count"] for item in table.values())
        print(f"    {label} (共 {total} 条):")
        for path, entry in sorted(table.items()):
            print(f"        {path}  x{entry['count']}")
            if entry["keys"]:
                print(f"            请求体字段: {', '.join(entry['keys'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
