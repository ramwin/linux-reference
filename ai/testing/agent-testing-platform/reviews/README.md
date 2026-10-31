# 外部校对记录

```{contents}
```

## 一、这里放什么

每条校验记录 = **一条可证伪的断言 + 外部模型的表态 + 内部模型的表态 + 裁决**。和 [../qa/](../qa/README.md) 的区别:问答记"问什么",这里记"对不对"。

- 一次校验一个文件:`YYYY-MM-DD-短标题.md`,模板见 [_TEMPLATE.md](./_TEMPLATE.md);
- 排队等外部校对的断言统一放 [pending.md](./pending.md),状态在那里维护;
- 机制与提问模板见 [../external-review.md](../external-review.md)。

## 二、当前状态

| 日期 | 校验对象 | 外部模型 | 结果 | 记录 |
|---|---|---|---|---|
| 2026-10-25 | 平台定位与四条立论 | DeepSeek | 同意,补了失效条件 | [qa/0001](../qa/0001-通用DAG能否替代测试平台.md) |
| — | openJiuwen 复用策略 | 待 Kimi/Claude | 排队 | [pending.md#openjiuwen](./pending.md) |
| — | 方案三启动阈值「消费方 ≥3」 | 待 | 排队 | [pending.md](./pending.md) |

## 三、跑一次自动校对

凭据恢复后(Kimi `kimi` → `/login`;Claude 见 [../external-review.md](../external-review.md)),在专题目录下:

```bash
./external_review.sh architecture.md "七阶段契约是否过度设计"
```

脚本会把指定文档 + 提问模板丢给可用的外部 CLI,输出落到本目录 `YYYY-MM-DD-*.md`。**脚本只负责取回原话,裁决必须人工/主模型来做**——不要让外部模型的输出直接改写正文。

## 版本记录

| 版本 | 日期 | 变更 | 使用模型 |
|---|---|---|---|
| v1 | 2026-10-25 | 建立状态表与脚本用法 | DeepSeek(deepseek-flash) |
