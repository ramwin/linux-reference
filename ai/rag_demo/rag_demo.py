"""最小 RAG: 分块 -> 向量化(TF-IDF) -> 索引 -> 检索 -> 拼进 prompt。零依赖, 直接 python3 rag_demo.py"""
import math
import re


def chunk(text, size=40, overlap=10):
    """按句切, 滑窗分块, 块间保留 overlap 个字的重叠上下文"""
    chunks, cur = [], ""
    for s in re.findall(r"[^。;]+[。;]?", text.strip()):
        if len(cur) + len(s) > size and cur:
            chunks.append(cur)
            cur = cur[-overlap:]          # 尾部重叠, 防止答案恰好被切断
        cur += s
    if cur.strip():
        chunks.append(cur)
    return chunks


def tokenize(doc):
    # 演示级分词: 英文按单词, 中文按单字。生产里换成正经分词器/embedding 模型
    return re.findall(r"[a-zA-Z]+", doc.lower()) + re.findall(r"[\u4e00-\u9fff]", doc)


class Store:
    """向量库: 文档入库时统计词频, 查询时套用同一份 IDF 表, 按余弦相似度取 top-k"""

    def __init__(self):
        self.docs, self.df = [], {}

    def _vec(self, tokens, n):
        tf = {}
        for w in tokens:
            tf[w] = tf.get(w, 0) + 1
        return {w: c * math.log((n + 1) / (self.df.get(w, 0) + 1)) for w, c in tf.items()}

    def add(self, doc):
        self.docs.append(doc)
        for w in set(tokenize(doc)):
            self.df[w] = self.df.get(w, 0) + 1

    def search(self, query, k=2):
        qv = self._vec(tokenize(query), len(self.docs))
        scored = [cosine(qv, self._vec(tokenize(d), len(self.docs))) for d in self.docs]
        top = sorted(enumerate(scored), key=lambda x: x[1], reverse=True)[:k]
        return [(self.docs[i], round(s, 3)) for i, s in top]


def cosine(a, b):
    dot = sum(v * b.get(w, 0) for w, v in a.items())
    na = math.sqrt(sum(v * v for v in a.values()))
    nb = math.sqrt(sum(v * v for v in b.values()))
    return dot / (na * nb) if na and nb else 0.0


KNOWLEDGE = """
公司报销制度(2025 版): 差旅住宿一线城市每晚不超过 500 元, 二线城市不超过 350 元。
交通费按职级补贴, 总监以下每月 800 元, 总监及以上每月 1500 元。
发票必须在费用发生后 30 天内提交, 超期不予受理。
年假按工龄计算, 满 1 年 5 天, 满 10 年 10 天, 满 20 年 15 天。
服务器部署规范: 生产环境所有变更必须走工单审批, 变更窗口为每周三凌晨。
数据库慢查询超过 2 秒的必须提交优化说明, 由 DBA 团队复核。
"""

QUESTION = "住宿费报销标准是多少?"

store = Store()
for c in chunk(KNOWLEDGE):
    store.add(c)

hits = store.search(QUESTION)

print("== 知识库分块 ==")
for i, d in enumerate(store.docs):
    print(f"[{i}] {d}")

print("\n== 检索结果 (top-2) ==")
for doc, score in hits:
    print(f"{score:.3f}  {doc}")

prompt = f"""根据以下资料回答用户问题, 资料里没有的就直说不知道。

资料:
{chr(10).join(doc for doc, _ in hits)}

问题: {QUESTION}
"""
print("== 拼好的 prompt(传给 LLM 的就是它) ==")
print(prompt)
