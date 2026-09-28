"""检索质量怎么评: 同一知识库 + 同一套标注问题, 两套向量化方案对比 HitRate@k。
零依赖, 直接 python3 eval_rag.py
结论由实测输出说话: 词袋方案对口语/同义改写开始漏检, 就是生产要换 embedding 模型的证据。"""
import math
import re


def chunk(text, size=40, overlap=10):
    """与 rag_demo.py 同一套分块参数, 保证对比只反映向量化方案的差异"""
    chunks, cur = [], ""
    for s in re.findall(r"[^。;]+[。;]?", text.strip()):
        if len(cur) + len(s) > size and cur:
            chunks.append(cur)
            cur = cur[-overlap:]
        cur += s
    if cur.strip():
        chunks.append(cur)
    return chunks


def unigram(doc):
    """单字分词: 与 rag_demo.py 相同, 词袋方案的地板"""
    return re.findall(r"[a-zA-Z]+", doc.lower()) + re.findall(r"[\u4e00-\u9fff]", doc)


def bigram(doc):
    """双字分词: 把 差旅/住宿/报销 当一个整体, 词袋家族里最便宜的一种"理解" """
    words = re.findall(r"[a-zA-Z]+", doc.lower())
    zh = re.findall(r"[\u4e00-\u9fff]", doc)
    return words + ["".join(p) for p in zip(zh, zh[1:])]


class Store:
    """与 rag_demo.py 相同的 TF-IDF + 余弦检索, 只是分词器可换"""

    def __init__(self, tokenizer):
        self.tok, self.docs, self.df = tokenizer, [], {}

    def _vec(self, tokens, n):
        tf = {}
        for w in tokens:
            tf[w] = tf.get(w, 0) + 1
        return {w: c * math.log((n + 1) / (self.df.get(w, 0) + 1)) for w, c in tf.items()}

    def add(self, doc):
        self.docs.append(doc)
        for w in set(self.tok(doc)):
            self.df[w] = self.df.get(w, 0) + 1

    def ranked(self, query):
        """全量排序, 返回 [(块号, 相似度), ...]"""
        n = len(self.docs)
        qv = self._vec(self.tok(query), n)

        def cos(a, b):
            dot = sum(v * b.get(w, 0) for w, v in a.items())
            na = math.sqrt(sum(v * v for v in a.values()))
            nb = math.sqrt(sum(v * v for v in b.values()))
            return dot / (na * nb) if na and nb else 0.0

        scored = [cos(qv, self._vec(self.tok(d), n)) for d in self.docs]
        return sorted(enumerate(scored), key=lambda x: x[1], reverse=True)


KNOWLEDGE = """
公司报销制度(2025 版): 差旅住宿一线城市每晚不超过 500 元, 二线城市不超过 350 元。
交通费按职级补贴, 总监以下每月 800 元, 总监及以上每月 1500 元。
发票必须在费用发生后 30 天内提交, 超期不予受理。
年假按工龄计算, 满 1 年 5 天, 满 10 年 10 天, 满 20 年 15 天。
服务器部署规范: 生产环境所有变更必须走工单审批, 变更窗口为每周三凌晨。
数据库慢查询超过 2 秒的必须提交优化说明, 由 DBA 团队复核。
采购报销: 5000 元以下由部门经理审批, 需附采购清单与发票原件。
客户招待: 来访客户住宿由行政部统一预订, 标准参照差旅住宿执行。
考勤制度: 迟到 30 分钟内每次扣 50 元, 当月累计 3 次按事假半天计。
加班可申请调休, 调休有效期 6 个月, 过期自动作废。
办公用品申领: 每人每月限领 1 套, 超出部分走采购报销流程。
差旅借款: 出差前可预借 3000 元, 返岗后 7 天内凭发票冲销借款。
"""

# 标注评测集: (问题, 答案必须包含的文字)。
# 前 5 题是字面提问; 后 7 题是口语/同义改写, 且知识库里故意放了
# 发票x3、住宿x2、过期x2 这类干扰块 —— 比的就是"语义"而不是"共同用字"
TEST_SET = [
    ("住宿费报销标准是多少?", "每晚不超过 500 元"),
    ("交通补贴总监每月多少?", "1500 元"),
    ("工作满十年有几天年假?", "满 10 年 10 天"),
    ("生产环境变更是什么时候?", "每周三凌晨"),
    ("慢查询优化说明谁复核?", "DBA 团队复核"),
    ("出差住酒店最多能报多少?", "每晚不超过 500 元"),
    ("发票过期了还能报销吗?", "超期不予受理"),
    ("去年的发票现在还能报吗?", "超期不予受理"),
    ("加班没休的假期会作废吗?", "过期自动作废"),
    ("买办公用品超额怎么办?", "采购报销流程"),
    ("出差前能预支多少钱?", "预借 3000 元"),
    ("客户来了住哪里谁负责?", "行政部统一预订"),
]

KS = (1, 3)
chunks = chunk(KNOWLEDGE)
print(f"== 知识库分块: {len(chunks)} 块(与 rag_demo 同参数); 评测集 {len(TEST_SET)} 题 ==")
print("== HitRate@k = 正确块进 top-k 的题目占比 ==\n")

for name, tok in [("单字分词", unigram), ("双字分词", bigram)]:
    store = Store(tok)
    for c in chunks:
        store.add(c)
    hits_at = {k: 0 for k in KS}
    for q, gold in TEST_SET:
        rank = store.ranked(q)
        gold_rank = next(i + 1 for i, (bi, _) in enumerate(rank) if gold in chunks[bi])
        marks = " ".join(f"{'√' if gold_rank <= k else '×'}@{k}" for k in KS)
        for k in KS:
            hits_at[k] += gold_rank <= k
        hit1 = " ".join(chunks[rank[0][0]].split())[:20]
        note = "" if gold_rank == 1 else f"   <- 正确块实际排第 {gold_rank}, top1 是块{rank[0][0]}: {hit1}..."
        print(f"  [{marks}]  {q:<18} top1=块{rank[0][0]}({rank[0][1]:.3f}){note}")
    print(f"  => HitRate " + "  ".join(f"@{k}={hits_at[k]}/{len(TEST_SET)}" for k in KS) + f"  ({name})\n")
