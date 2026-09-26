#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""KV cache / prompt cache 最小验证, 零依赖纯 Python。

回答三个问题:
  1. 为什么"逐 token 查关联"还能用缓存?  -> 对比有/无缓存时的乘加次数
  2. 缓存的 key 是什么?                  -> 前缀 token id 序列(这里用元组当 key)
  3. 两段相似的话改一点会怎样?            -> 统计最长公共前缀(命中 token 数)

不需要 numpy: 需要做矩阵乘的地方, 都用显式的三层循环 + 计数器实现,
这样能顺便把"浮点运算次数"数出来 —— 它就是真实 GPU 上要干的活。

    python3 kv_cache_demo.py
"""

from __future__ import annotations

import hashlib
import math
import random
import time

# ---------------------------------------------------------------- 乘加计数器

MACS = 0  # 全局乘加次数, 用来衡量"算了多少活"


def matvec(mat: list[list[float]], vec: list[float]) -> list[float]:
    """矩阵 × 向量: (m, n) × (n,) -> (m,)"""
    global MACS
    MACS += len(mat) * len(vec)
    return [sum(row[j] * vec[j] for j in range(len(vec))) for row in mat]


def dot(a: list[float], b: list[float]) -> float:
    """向量点积: 关联查询(Q·K)的核心运算, 一次都不省"""
    global MACS
    MACS += len(a)
    return sum(x * y for x, y in zip(a, b))


# ------------------------------------------------------------ 单头注意力层

class TinyAttention:
    """一个单头注意力层, 只保留理解 KV cache 所必需的部分。

    为了演示, 去掉了 softmax 的数值稳定性处理和残差/FFN,
    它们不影响"哪个向量需要重算"这个结论。
    """

    def __init__(self, dim: int = 32, rng: random.Random | None = None) -> None:
        rng = rng or random.Random(0)
        self.dim = dim
        self.wq = [[rng.uniform(-0.1, 0.1) for _ in range(dim)] for _ in range(dim)]
        self.wk = [[rng.uniform(-0.1, 0.1) for _ in range(dim)] for _ in range(dim)]
        self.wv = [[rng.uniform(-0.1, 0.1) for _ in range(dim)] for _ in range(dim)]

    def project_kv(self, x: list[float]) -> tuple[list[float], list[float]]:
        """算一个 token 的 K、V —— 这两行就是 KV cache 缓存的东西"""
        return matvec(self.wk, x), matvec(self.wv, x)

    def forward(self, xs: list[list[float]]) -> list[float]:
        """无缓存: 每次都要为全部 token 重算 K/V"""
        pairs = [self.project_kv(x) for x in xs]
        ks = [k for k, _ in pairs]
        vs = [v for _, v in pairs]
        return self._attend(xs[-1], ks, vs)

    def forward_cached(
        self,
        x_new: list[float],
        past: list[tuple[list[float], list[float]]],
    ) -> tuple[list[float], tuple[list[float], list[float]]]:
        """有缓存: 只算新 token 的 K/V, 复用 past 里的全部历史 K/V"""
        k_new, v_new = self.project_kv(x_new)
        ks = [k for k, _ in past] + [k_new]
        vs = [v for _, v in past] + [v_new]
        return self._attend(x_new, ks, vs), (k_new, v_new)

    def _attend(
        self,
        x_q: list[float],
        ks: list[list[float]],
        vs: list[list[float]],
    ) -> list[float]:
        q = matvec(self.wq, x_q)
        scores = [dot(q, k) for k in ks]          # ← 关联查询, 有没有缓存都要做
        weights = _softmax(scores)
        out = [0.0] * len(vs[0])
        for w, v in zip(weights, vs):            # ← 加权求和 V
            for j in range(len(v)):
                out[j] += w * v[j]
        return out


def _softmax(xs: list[float]) -> list[float]:
    m = max(xs)
    es = [math.exp(x - m) for x in xs]
    s = sum(es)
    return [e / s for e in es]


# --------------------------------------------------- 实验一: 有/无缓存的差距

def experiment_cost(steps: int = 64, dim: int = 32) -> None:
    global MACS
    rng = random.Random(42)
    layer = TinyAttention(dim, rng)

    # 模拟一串"已经生成的 token"的输入向量(真实场景里是 embedding + 位置编码)
    xs = [[rng.gauss(0, 1) for _ in range(dim)] for _ in range(steps)]

    MACS = 0
    for i in range(steps):
        layer.forward(xs[: i + 1])          # 每一步都把历史全部重算
    no_cache = MACS

    def with_kv_cache() -> int:
        global MACS
        MACS = 0
        past: list[tuple[list[float], list[float]]] = []
        for x in xs:
            _, kv = layer.forward_cached(x, past)  # 每步只算一个新 token
            past.append(kv)
        return MACS

    with_cache = with_kv_cache()
    ratio = no_cache / with_cache

    print(f"[1] 逐 token 生成 {steps} 步的乘加次数(dim={dim})")
    print(f"    无缓存(每步重算全部):     乘加 {no_cache:>10,} 次")
    print(f"    有 KV cache(只算新 token): 乘加 {with_cache:>10,} 次")
    print(f"    比值: {ratio:.1f}x")
    print("    注: 这里只统计一个注意力层。真实模型每层还有 FFN, 且 Q/K/V 投影的乘加"
          "\n        占前向计算的大头, 所以实际节省的算力通常比这个比值更可观。")
    print("    -> 缓存省掉的是'重复计算已有 token 的 K/V', 关联查询 q·K 一次都没少")
    print()


# --------------------------------------------- 实验二: 改一点, 命中多少 token

def fake_tokenize(text: str) -> list[str]:
    """假装分词器: 中文按 2 字切, 英文按空格切, 标点单独成 token。

    真实分词器(BPE)也遵循同样的精神: 常见的整块保留, 罕见的拆碎,
    所以"改一个字符"往往会让后面好几个 token 的边界一起变。
    """
    tokens: list[str] = []
    for chunk in text.split():
        if _is_cjk(chunk):
            tokens += [chunk[i : i + 2] for i in range(0, len(chunk), 2)]
        else:
            tokens.append(chunk)
    return tokens


def _is_cjk(s: str) -> bool:
    return any("\u4e00" <= ch <= "\u9fff" for ch in s)


def common_prefix_len(a: list[str], b: list[str]) -> int:
    n = 0
    for x, y in zip(a, b):
        if x != y:
            break
        n += 1
    return n


def experiment_prefix() -> None:
    base = "请把这段代码重构一下"
    cases = [
        ("追加(末尾加内容)", base + ", 并加上注释"),
        ("中间改一个词", "请把这段代码优化一下"),
        ("开头加日期", "2026-03-15 " + base),
        ("只改一个标点", "请把这段代码重构一下!"),
    ]

    base_tokens = fake_tokenize(base)
    print("[2] 相似 prompt 的缓存命中情况(逐 token 精确前缀匹配)")
    print(f"    基准:       {base!r}")
    print(f"    基准 token: {' | '.join(base_tokens)}  (共 {len(base_tokens)} 个)")
    for name, text in cases:
        tokens = fake_tokenize(text)
        hit = common_prefix_len(base_tokens, tokens)
        if hit == min(len(base_tokens), len(tokens)) == len(tokens):
            where = "前缀完全一致(命中全部基准 token)"
        else:
            where = f"第 {hit + 1} 个 token 起失效"
        print(f"    {name:<16} 命中 {hit:>2} token / 本句共 {len(tokens):<2} 个   {where}")
        print(f"                     本句 token: {' | '.join(tokens)}")
    print("    -> 改动点之前照常命中, 之后全部重算; 越长越靠后改, 越划算")
    print()


# ------------------------------------- 实验三: 缓存 key 长什么样 + 显存估算

def experiment_key() -> None:
    prefix = "你是运维助手。工具: get_disk_usage/restart_service。"
    tokens = fake_tokenize(prefix)
    digest = hashlib.sha256(repr(tokens).encode()).hexdigest()[:16]

    print("[3] 缓存 key 是什么")
    print(f"    前缀:      {prefix!r}")
    print(f"    token id:  {' | '.join(tokens)}")
    print(f"    分块哈希:  sha256(前缀 token 序列)[:16] = {digest}")
    print("    改变其中任何一处都会换 key: 分词结果 / 工具定义与顺序 / 消息边界 / 模型版本")
    print()

    # KV cache 显存估算: 2(K,V) × 层数 × 头数 × 每头维度 × 字节数
    for name, layers, heads, head_dim in [
        ("LLaMA-2-7B", 32, 32, 128),
        ("LLaMA-2-13B", 40, 40, 128),
    ]:
        per_token = 2 * layers * heads * head_dim * 2  # FP16
        for ctx in (4096, 32768):
            print(f"    {name:<12} 上下文 {ctx:>6}: KV cache ≈ "
                  f"{per_token * ctx / 1024**3:5.2f} GB"
                  f"   (每 token {per_token / 1024:.0f} KB)")
    print("    -> 省下的是计算时间, 付出的是显存/存储, 所以各家缓存都有 TTL")
    print()


def main() -> None:
    t0 = time.time()
    experiment_cost()
    experiment_prefix()
    experiment_key()
    print(f"全部完成, 耗时 {time.time() - t0:.2f}s")


if __name__ == "__main__":
    main()
