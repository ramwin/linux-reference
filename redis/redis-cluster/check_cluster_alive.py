#!/usr/bin/env python3
import redis, click, logging
from concurrent.futures import ThreadPoolExecutor
from typing import Set, List, Tuple

logging.basicConfig(level=logging.INFO, format="%(message)s")


def cluster_nodes_raw(rc) -> str:
    """返回原始 CLUSTER NODES 文本，避免封装层缓存/字段差异"""
    return rc.execute_command("CLUSTER", "NODES")


def parse_slots(raw: str) -> Tuple[Set[int], List[str]]:
    """解析原始 CLUSTER NODES，返回 (已覆盖槽集合, 异常警告列表)"""
    covered: Set[int] = set()
    warns: List[str] = []

    for line in raw.strip().splitlines():
        if not line or "handshake" in line:
            continue
        parts = line.split()
        flags = parts[2]
        host_port = parts[1].split("@")[0]

        if "master" in flags:
            # 剩余字段全是槽或槽区间
            for seg in parts[8:]:
                if "-" in seg:
                    start, end = map(int, seg.split("-"))
                else:
                    start = end = int(seg)
                covered.update(range(start, end + 1))
                logging.info(f"master {host_port}  slots [{start}-{end}]")
        if "fail" in flags or "noflags" in flags:
            warns.append(f"节点 {host_port} 状态异常: {flags}")

    return covered, warns


@click.command()
@click.argument("seed", type=str)  # host:port
@click.option("-t", "--timeout", default=2, help="socket timeout (s)")
def main(seed: str, timeout: int):
    host, port = seed.rsplit(":", 1)
    rc = redis.Redis(host=host, port=int(port), socket_timeout=timeout, decode_responses=True)

    # 1. 原始节点列表
    raw_nodes = cluster_nodes_raw(rc)
    nodes: List[Tuple[str, int]] = [
        (ep.split(":")[0], int(ep.split(":")[1]))
        for line in raw_nodes.splitlines()
        if (ep := line.split()[1].split("@")[0])
    ]

    # 2. 并行 PING
    def ping(addr: Tuple[str, int]) -> bool:
        try:
            return redis.Redis(host=addr[0], port=addr[1], socket_timeout=timeout).ping() is True
        except Exception:
            return False

    down = [addr for addr in nodes if not ping(addr)]
    for h, p in nodes:
        click.echo(f"{h}:{p}  {'OK' if (h, p) not in down else 'DOWN'}")

    if down:
        logging.error(f"不可达节点: {down}")
        raise click.Abort

    # 3. 槽位覆盖
    covered, warns = parse_slots(raw_nodes)
    for w in warns:
        logging.warning(w)

    if len(covered) != 16384:
        missing = 16384 - len(covered)
        # 把缺失的槽号区间也打出来
        all_slots = set(range(16384))
        missing_ranges = []
        start = None
        for s in sorted(all_slots - covered):
            if start is None:
                start = s
            if s + 1 not in all_slots - covered:
                missing_ranges.append(f"{start}-{s}" if start != s else f"{s}")
                start = None
        logging.error(f"[ERR] 缺失 {missing} 个槽，区间: {','.join(missing_ranges)}")
        raise click.Abort

    logging.info("[OK] 所有节点可达且 16384 槽位全覆盖")


if __name__ == "__main__":
    main()
