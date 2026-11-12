# 个人知识库分层：memory-repo、life、linux-reference 各放什么

```{contents}
```

## 一句话结论

按「**谁在什么时候读**」分层，而不是按「内容是不是技术」分层：

| 层 | 位置 | 放什么 | 谁读 / 何时进上下文 |
| --- | --- | --- | --- |
| 规则层 | `memory-repo/global/AGENTS.md` + `kb/` + `projects/` | 稳定约定、环境事实、操作手册 | AI 每会话注入 AGENTS（≤64KB）；`kb/` 按需 Grep |
| 事实层 | `memory-repo/memory/` | 一句话偏好、事实、硬约束 | AI 每会话自动注入索引（≤4KB） |
| 个人档案层 | `life/` | 生活记录、决策过程、使用体验 | 人看（Sphinx 站），AI 按需翻 |
| 通用知识层 | `linux-reference/` | 可公开复用的教程、原理、排坑 | 人看（公开站），AI 按需翻 |
| 凭据层 | `secret/` | 密码、token、域名/端口/账号 | 只按需读，永不入库到别处 |

## 四层各自的判据

### 1. 规则层：改行为的东西

「以后都这么干」的约定放这里：提交信息格式、发布流程、目录结构、
「开源仓不放个人配置」这类硬规则。**人写、可评审**，AI 不擅自改。

### 2. 事实层：下次开新会话就该在的东西

一句话能说清、不需要检索、跨工作区复用——例如「装 dsh-mobile-ui，
不要音乐播放器」「米饭只吃 1/4」。写进 `memory/`，`memory_write`
复用同名原地更新；`feedback` 类型正文带 `**Why:**` / `**How to apply:**`。

判断口诀：**这条信息需要被搜索后阅读吗？** 需要 → 文档；不需要 → 记忆。

### 3. 个人档案层：life 是「我」的账本

适合放：设备/软件的使用记录、这次为什么这么选、踩了什么坑、体验如何、
和家庭/健康/出行/消费相关的决策。**读者是人**，所以要有背景、步骤、
结论，按主题归档（`数码/`、`家居/`、`育儿/`…）。

### 4. 通用知识层：linux-reference 是「可公开的怎么做」

适合放：安装教程、原理讲解、通用排坑、对比选型。**读者是任何人**，
所以只放通用配置和占位符（`postgres://user:password@host:5432/db`），
个人域名/账号/端口/部署路径一律不进仓。

> 「linux-reference 里也有很多技术配置」——对，但那些是**通用示例**，
> 不是「我这台机器怎么配」。后者属于 `secret/` 或 `memory-repo/kb/`。

## 实例：这次「dsh-mobile-ui」偏好怎么分流

| 内容 | 落点 | 形态 |
| --- | --- | --- |
| 「装 dsh-mobile-ui，不要 dsh-music-player」 | `memory-repo/memory/_user/dsh-plugin-preferences.md` | 一句话偏好，自动注入 |
| 本机实际装了哪些插件、bundle 顺序 | `memory-repo/dsh/profiles/web/package.json` | 可执行快照（`apply.sh` 铺回） |
| 安装步骤、和 hide-left-sidebar 的关系、验证命令 | `life/数码/dsh-mobile-ui移动端插件安装-2026-11-12.md` | 个人使用记录 |
| 这篇分层方法论 | `linux-reference/ai/tools/knowledge-base-layering.md` | 通用文章 |

四份内容不重复：记忆只留「结论」，文档留「过程」。

## 常见误区

1. **「技术偏好 = 技术文档 → 放 linux-reference」**。错。偏好是「我这个
   人要什么」，属于事实层；linux-reference 放的是「任何人都能照着做」的
   方法。两者混在一起，开源仓会混进私人配置，记忆仓会膨胀成文档堆。
2. **「memory 能当文档用」**。记忆注入的是索引，正文要 `memory_read`
   才看得到；而且 4KB 预算挤掉一条就少一条。步骤类一律进文档。
3. **「life 是技术知识库」**。life 记录的是「我」的生活与决策；纯技术
   排坑放 linux-reference，跨项目操作手册放 `memory-repo/kb/`。
4. **「AGENTS.md 已有的规则再写一条 memory」**。重复记录会挤占注入预算，
   而且两处会漂移。AGENTS 写死的东西，记忆里只留指针。

## 可照抄的模板

```text
# 记忆（memory_write，user 作用域，description ≤60 字）
dsh-plugin-preferences：装 dsh-mobile-ui，不要 dsh-music-player；
新机器用 memory-repo/dsh/apply.sh --install 装齐。

# 个人档案（life/数码/<主题>-<日期>.md）
背景 → 本机环境表 → 操作步骤（可粘命令）→ 验证 → 与已有方案的关系 → 版本记录

# 通用知识（linux-reference/ai/tools/<english-name>.md）
问题 → 结论表 → 逐层解释 → 判定口诀 → 实例 → 常见误区 → 版本记录
```

## 版本记录

- v1（2026-11-12）：初版。回答「技术偏好放 memory-repo 还是 life /
  linux-reference」的分层问题。使用模型：DeepSeek Harness（deepseek-flash）。
  本次会话消耗（定稿时统计）：输入 155,537 / 输出 26,423 / 缓存读 4,321,792，
  总计 4,503,752 tokens。
