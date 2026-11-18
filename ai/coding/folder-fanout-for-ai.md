# 一个目录该放多少文件：7–10 的业界惯例，和 AI 时代该给的数

```{contents}
```

"一个文件夹下最多放多少个文件/子目录"这个问题，Google 的 C++、Java、TypeScript 规范都不回答，PEP 8 不回答，Rust 和 Go 也不回答。真正给出数字的只有前端那套 LIFT 规范：**7 个开始考虑拆，10 个就该拆了**。

但那是给人眼和 GUI 定的数。AI 读目录的成本结构和人完全不一样——它不靠"扫一眼"，它靠"一次列举 + 名字判别"。所以到了 2026 年，这个数字既不该照抄 7，也不该放任到几百。下面先给结论，再解释为什么。

**结论先放这儿：**

| 目录角色 | 建议值 | 超过就该动手 |
| --- | --- | --- |
| 仓库根目录 | ≤ 12 项 | 20 项 |
| 手写源码目录 | ≤ 15 项 | 20 项 |
| 同构文件目录（测试/素材/迁移/图标） | ≤ 50 项 | 100 项 |
| 目录深度（从仓库根算） | ≤ 3 层 | 4 层 |
| 单文件行数 | ≤ 400 行 | 800 行 |

一句话版本：**宽度按"一次列举能不能覆盖"定，深度按"要不要多花一次工具调用"定。**

## 一、业界规范里到底写了什么

把几个主流规范翻一遍，会得到一个挺意外的结论：绝大多数规范根本不管目录项数，只管文件内部的写法。

| 规范 | 有没有规定目录项上限 | 原文/要点 |
| --- | --- | --- |
| Angular 官方 Style Guide | **有，软性** | "**Consider** creating sub-folders when a folder reaches seven or more files."；"when a folder has ten or more files, it may be time to create subfolders" |
| John Papa Angular Style Guide（LIFT） | **有，软性** | Y143："Keep a flat folder structure as long as possible. When you get to 7+ files, begin considering separation." 并加了一句"anything deeper than 2 should take serious consideration"；Y152："When a folder grows to contain more than 7 files, start to consider creating a folder for them." |
| Angular 官方（文件粒度） | 有 | "**Consider** limiting files to 400 lines of code." |
| Google TypeScript Style Guide | **没有** | 全文不出现 folder 相关的条目数规定，只规定命名、导入、类型 |
| Go Code Review Comments | **没有** | 只有约定"一个目录 = 一个 package" |
| PEP 8 | **没有** | 只管缩进、命名、空行 |
| Linux kernel CodingStyle | **没有** | 只管代码风格，`drivers/` 下上千个文件的目录照样存在 |

所以"业界规范说最多 N 个"这个前提本身就不成立。**7–10 这个数字只出自 Angular/LIFT 这一支，而且明确写了 "there is no hard and fast number rule"**——它不是规范，是一个有理由的经验值。

（[Angular styleguide 源文件](https://github.com/angular/angular/blob/17.3.0/aio/content/guide/styleguide.md)、[angular.dev/style-guide](https://angular.dev/style-guide)、[johnpapa/angular-styleguide](https://github.com/johnpapa/angular-styleguide/blob/master/a1/README.md#style-y143)）

那 7 这个数是怎么来的？John Papa 给的理由很具体：**"Nobody wants to search 7 levels of folders to find a file"**、**"A flat structure is easy to scan"**。它优化的是人眼在文件管理器/IDE 树里的一次扫描，以及"别为了拆目录把层级搞太深"这个反面风险。这两件事，恰好都是人特有的约束。

## 二、AI 读目录的成本，和人不是一回事

人看目录：注意力成本。扫 30 个文件名会累，扫 300 个会直接放弃，改用搜索。

AI 看目录：**token 成本 + 轮次成本 + 判别成本**。这三项可以量，而且和人关心的东西不一样。

### 2.1 token：一次列举，全部计入上下文

agent 要决定"改哪个文件"，第一步几乎总是列目录或 glob。这些路径会原样进上下文，而且往往不止一次（每轮重新确认）。

拿本仓实测：

| 场景 | 条目数 | 字符数 | 估算 token |
| --- | --- | --- | --- |
| `ai/coding/`（12 项，短英文名） | 12 | 245 | ~70 |
| 50 条 `.md` 相对路径 | 50 | 1,354 | ~380 |
| `shellprogramming/`（31 项，中文名） | 31 | 343 | **~330** |

前两行按 ASCII 字符 ÷ 3.5 估算；第三行是重点：**同样 343 个字符，中文文件名的 token 数接近 ASCII 路径的 3 倍**（中文基本按 1 字 ≈ 1 token 计）。也就是说：

- 一个 100 项、英文短名的目录，列举一次约 700–800 tokens，agent 还能接受；
- 一个 100 项、中文长名的目录，同样的列举要 1,500 tokens 以上，而且 grep/glob 的每一行匹配都在重复付这笔钱。

对比一下 AI 时代的其他预算：Claude Code 建议单个 `CLAUDE.md` 控制在 200 行以内，子目录按需加载的文件超过 40,000 字符就只加载开头（[Claude Code memory 文档](https://code.claude.com/docs/zh-CN/memory.md)）。目录列举本身不该成为"最大的那一笔上下文开销"——它只是导航，不是内容。

### 2.2 轮次：每深一层，多一次工具调用

人不怕深目录：IDE 的树是展开的，点三下就到。

agent 是逐层走的：`ls src` → `ls src/features` → `ls src/features/order` → 才看到文件。**每多一层就是一次工具调用、一轮模型往返**。四层目录找一个文件，光导航就烧掉 3 次调用；如果那个文件根本不在猜测的分支上，还要回退重试。

这就是为什么"深度"比"宽度"更该被限制。宽度只花一次列举的 token，深度花的是**串行延迟 × 次数**。

### 2.3 判别：名字是 agent 唯一的免费索引

人和 AI 都靠文件名判断相关性，但人还能靠"我记得那个文件旁边有个图标"这种界面记忆，agent 只有字符串。

于是有两种失败：

- **同质化名字**：`utils.ts`、`helpers.ts`、`common.ts`、`misc.ts` 并排躺在同一个目录里。人还能点开看看，agent 只能靠猜或者全部读一遍——这是最贵的失败。
- **异质化大目录**：一个目录里既有 `order_service.py` 又有 `legacy_2023_migration_v2.py`、`test_tmp.py`。名字无法形成模式，agent 每次都要重新推理。

反过来的成功条件很清楚：**同一目录里的条目应该是同一类东西，且名字能压缩出语义**（`user_service.py` / `order_service.py` / `payment_service.py`）。这种目录哪怕有 40 个文件，agent 看名字就知道该 grep 哪个。

顺带一条常被忽略的：`Lost in the Middle` 这类长上下文实验反复说明，相关信息落在长上下文中段时模型利用率最低（[arXiv:2307.03172](https://arxiv.org/abs/2307.03172)）。目录列举越长，真正有用的那几行越容易被稀释——这不是玄学，是上下文越长、单位信息密度越低的直接后果。

## 三、还有两个硬约束，跟规范无关

**平台截断。** GitHub 的网页目录列表只展示 1,000 个条目，超出的直接省略（"we had to truncate this directory to 1,000 files"，[community discussion #136892](https://github.com/orgs/community/discussions/136892)）。人在网页上翻不到，agent 抓 HTML 也抓不全。

**工具上限。** agent 侧的 glob/grep 普遍有返回条数上限。以本仓使用的 DSH 工具为例：`glob` 最多返回 100 条路径，`grep` 最多 250 条匹配。**目录一旦超过 100 项，agent 拿到的就不是"完整列表"而是"前 100 条"**——它会以为剩下的不存在，或者被迫用更窄的模式分页试探，这比慢更糟：它会让模型基于不完整的信息下结论。

**文件系统反而不是瓶颈。** ext4/XFS/APFS 单目录百万级条目也能跑，FAT32 才是那个例外（单目录 65,534 项）。所以"拆目录"的理由从来不是文件系统扛不住，而是人、工具、上下文扛不住。

## 四、推荐数字：为什么是 15–20 而不是 7

把上面三条成本合起来，能推出一个和 7 不同的最优区间。

**下界由"人"决定，约 10–15。** 低于 10 就开始拆，会造出大量"只有 2–3 个文件的目录"，深度迅速超过 4 层。Angular 自己都写了 "keep a flat folder structure as long as possible"——拆目录是有代价的。

**上界由"一次列举"决定，约 20。** 20 项英文短名的列举约 150–250 tokens，便宜到 agent 可以每轮重复；人也能一屏扫完。超过 20，agent 开始倾向"先 grep 再列"，多一轮；人开始滚屏。

**同构目录放宽到 50。** 测试文件、迁移脚本、图标素材、i18n 词条有天然模式（`test_*.py`、`2026*_*.sql`、`ic_*.svg`），agent 可以用通配符一次收全，不需要一条条判断相关性。这类目录可以到 50，但**必须能被一个通配符覆盖**——如果 `tests/` 下混着 `test_order.py` 和 `order_test_helper.py` 和 `conftest_backup.py`，那它就不算同构，按 20 算。

**深度上界 4 层。** 仓库根算第 0 层，`src/features/order/` 是第 3 层，已经够表达"领域/模块/能力"三件事。到第 5 层基本说明前面某一层承载了不该承载的东西。

**单文件 400 行、上限 800 行。** 400 是 Angular 的数，也是"一次读完整文件还能留出推理空间"的经验值。800 行代码约 6k–8k tokens，agent 读一个文件就吃掉小半个工作窗口；超过这个量级，应该先按符号（函数/类）定位再读局部，而不是整文件灌进去。这一条和目录无关，但它和目录一起决定了"agent 处理一个 feature 要付多少上下文"。

## 五、从简单到复杂：五档方案

| 档位 | 做法 | 成本 | 主要收益 | 局限 |
| --- | --- | --- | --- | --- |
| **L0 写进规则** | 在 `AGENTS.md`/`CLAUDE.md` 里写死"单目录 ≤20、深度 ≤4"，靠 review 提 | 10 分钟 | 零工具，先有共识 | 半年后没人记得，规则退化成摆设 |
| **L1 本地检测** | 跑 `script/check-fanout.py`，或挂 pre-commit | 1 小时 | 有数字、可讨论，能看趋势 | 只提示，不阻止 |
| **L2 CI 门禁** | CI 里跑 `--strict`，先 warning 三个月再改 error | 半天 | 给存量设一条地板，不再退化 | 存量目录要豁免清单，否则第一天就红 |
| **L3 结构重构** | feature-first 垂直切分；根目录只留入口+配置+主题；补一份"目录地图" | 数天 | 检索准确率质变，agent 一次列举就能定位 | 有 merge 冲突成本，别在大迭代中间做 |
| **L4 为 agent 建索引** | 目录地图 + 符号索引（ctags/tree-sitter）+ 关键层 README；超大仓拆包/拆仓 | 数周 | 大仓也能被当小仓用 | 索引要跟着代码变，维护成本真实存在 |

**建议：默认走 L2，只在"agent 反复找错文件"的那几个目录局部做 L3。** 不要一上来全量重构——目录重构的收益是渐进的，冲突成本是一次性的，顺序反了会让人恨这套规范。

判断该升到哪一档，先看三个数（都能量）：

- **导航轮次**：一次任务里 agent 平均调用几次 `ls`/`glob` 才找到目标文件。>3 就该先治深度。
- **列举 token 占比**：会话里目录列举消耗的 token / 总输入 token。>10% 说明目录太宽或名字太贵。
- **找错率**：agent 读错文件（读了不相干的实现）的比例。高，说明名字不可判别，或者同层选项太多。

## 六、落地：一个脚本、一张地图、三条 lint

### 6.1 检测脚本

本仓新增了 `script/check-fanout.py`，无依赖，直接跑：

```bash
python3 script/check-fanout.py .                 # 人看
python3 script/check-fanout.py . --max 15        # 收紧阈值
python3 script/check-fanout.py . --strict        # CI 用，越界退出码 1
python3 script/check-fanout.py . --json          # 灌进看板/趋势图
```

拿本仓自己跑的结果（`--max 20`）：

```text
目录总数: 74，单目录上限: 20，深度上限: 4

条目超限（>20）: 2 个目录
    51  .
    31  shellprogramming

深度超限（>4）: 无
```

两条都真实可解释：根目录把 Sphinx 工程文件、主题目录、历史遗留目录全堆在一起；`shellprogramming/` 是一整套教程章节。前者该收敛（根目录的理想状态是"入口 + 配置 + 主题目录"十几项），后者属于"同构目录"，按放宽档 50 处理即可——这正是分档的意义，一个数字管不了所有目录。

挂进 pre-commit：

```yaml
- repo: local
  hooks:
    - id: fanout
      name: 目录扇出检查
      entry: python3 script/check-fanout.py --strict
      language: system
      pass_filenames: false
```

存量仓库第一天必然红，所以 CI 里先只 warning，并把"允许超限"的目录写进豁免清单，逐季清理。

### 6.2 一张目录地图（比 100 个 README 划算）

在根 `AGENTS.md` 里放一张 20 行以内的地图，agent 读一次就知道"该往哪走"，省掉最贵的前几轮探索：

```markdown
## 目录地图

| 路径 | 放什么 | 不该放什么 |
| --- | --- | --- |
| `src/api/` | HTTP handler、路由注册 | 业务逻辑 |
| `src/domain/` | 实体、值对象、领域服务 | 框架/ORM 代码 |
| `src/infra/` | 数据库、消息队列、外部 SDK 适配 | 领域规则 |
| `tests/` | 单元测试，与 `src/` 镜像 | 测试数据、fixture 大文件 |
| `script/` | 一次性运维脚本 | 被应用 import 的代码 |
```

关键在"不该放什么"这一列——**排除项比包含项更能减少误判**。

### 6.3 三条现成的 lint

- `eslint`：`max-lines`（400）、`max-lines-per-function`（75）、`max-depth`（4，这个管的是嵌套层级不是目录，别混用）。
- `dependency-cruiser`：禁止跨 feature 目录直接 import，顺带把"目录边界"变成可执行约束。
- `ruff`：`PLR0915`（语句过多）、`C901`（圈复杂度过高），管住单文件内部的膨胀。

三条都不是目录规则，但它们管的是同一件事：**让"一个单元有多大"始终可度量**。目录项数只是这个问题的外圈。

## 七、六个常见误区

**把 7 当硬规定。** 于是出现 `features/user/`、`features/user/hooks/`、`features/user/hooks/v2/` 各两个文件的"俄罗斯套娃"。拆目录的收益是"减少同层选项"，代价是"增加一层导航"，两者必须权衡。

**为拆而拆，深度爆炸。** 深度每加一层，agent 多一次调用。5 层以上基本等于把检索成本翻倍，而信息量没增加。

**测试目录一刀切按 20 算。** 几百个 `test_*.py` 拆成 `tests/unit/order/create/`、`tests/unit/order/update/`……不如老老实实平铺 200 个文件 + 一个固定命名规则。同构文件的"可通配覆盖"比"条目数"更重要。

**按"类型"横切而不是按"功能"纵切。** `models/`、`services/`、`controllers/`、`views/` 各一个大目录，改一个功能要跳 4 个目录——这正好是 agent 最不擅长的操作：跨目录聚合上下文。feature-first 对人和 AI 都更友好。

**文件名用中文长句或带空格。** token 更贵（中文约 1 字 1 token）、shell 要转义、grep 模式难写、跨平台编码出问题的概率也高。目录/文件名用短 ASCII（`db-config.md` 而不是 `数据库配置说明文档.md`），正文用中文——本仓就是这么定的。

**只列目录，不给"这一层放什么"。** 名字能救 80% 的判别，剩下的 20% 靠一句说明。一张 20 行的目录地图能省掉几千次试错，投入产出比极高。

## 八、结语：数字要跟着成本函数走

7 这个数字没有错，它只是对"人在文件树里找文件"这件事最优。当读代码的主体从人变成 agent，成本函数就换了：**人的成本是注意力，agent 的成本是 token 和轮次**。前者怕多，后者怕散和深。

所以真正该记住的不是某个数字，而是三个问题：

1. **一次列举能不能覆盖这一层的全部选项？**（宽度，建议 ≤20，同构放宽到 50）
2. **到达目标文件要下钻几次？**（深度，建议 ≤3，硬顶 4）
3. **只看名字，能不能判断哪几个相关？**（判别性，靠命名和目录地图）

三个都答"能"，目录就有 30 个文件也无所谓；任何一个答"不能"，哪怕只有 8 个文件也该重构。**规范给的是起点，不是终点。**

## 参考资料

- Angular 官方 Style Guide（"Consider creating sub-folders when a folder reaches seven or more files."）：[angular.dev/style-guide](https://angular.dev/style-guide)，源文件 [angular/angular@17.3.0 styleguide.md](https://github.com/angular/angular/blob/17.3.0/aio/content/guide/styleguide.md)
- John Papa Angular Style Guide，LIFT 的 Y143（Flat）/ Y152（Folders-by-Feature）：[johnpapa/angular-styleguide](https://github.com/johnpapa/angular-styleguide/blob/master/a1/README.md)
- Google TypeScript Style Guide（不含目录项数规定，全文检索 folder 无相关条目）：[google.github.io/styleguide/tsguide.html](https://google.github.io/styleguide/tsguide.html)
- Go Code Review Comments（一个目录一个 package）：[go.dev/wiki/CodeReviewComments](https://go.dev/wiki/CodeReviewComments)
- GitHub 目录列表 1,000 条截断："we had to truncate this directory to 1,000 files"，[community discussion #136892](https://github.com/orgs/community/discussions/136892)
- Claude Code 记忆/指令文件的体量上限（CLAUDE.md 建议 ≤200 行、按需加载文件 40,000 字符上限）：[code.claude.com/docs/zh-CN/memory.md](https://code.claude.com/docs/zh-CN/memory.md)
- Lost in the Middle：长上下文中段信息利用率下降，[arXiv:2307.03172](https://arxiv.org/abs/2307.03172)
- FAT32 单目录条目上限 65,534（Microsoft 文件系统规范）

**未核实/经验判断（本文中标注为估算的部分）：**

- token 数是按"ASCII 字符 ÷3.5、中文按 1 字符 ≈1 token"估算的，未用具体分词器实测；不同模型的分词器差异会让数值上下浮动 15% 左右。
- "20 项以内 agent 倾向直接判断、超过后倾向改用 grep"是经验观察，没有公开的对照实验数据支撑。
- 表格中的 12/15/20/50/100 是工程折中值，不是任何标准的原文。

## 版本记录

| 版本 | 日期 | 使用模型 | 主要变动 |
| --- | --- | --- | --- |
| v1 | 2026-11-18 | deepseek-flash（DSH Web） | 初稿：业界规范原文梳理（Angular/John Papa 的 7–10，Google/Go/PEP 8 的"不规定"）、AI 三项成本（token/轮次/判别）与本仓实测数据、平台与工具硬上限、分档推荐值、L0–L4 五档方案与对比、落地脚本 `script/check-fanout.py`、目录地图模板、六个误区 |

v1 定稿时本会话消耗（口径：`inputTokens` 不含缓存命中；统计自 DSH 会话日志 `session.v4.jsonl.zstd` 的 `assistant/message.usage`）：

| 指标 | 数值 |
| --- | --- |
| assistant 消息数 | 37 |
| 非缓存输入 token | 50,301 |
| 输出 token | 23,379 |
| 缓存读取 token | 2,036,992 |
| 工具调用 | bash 28、web_search 4、web_fetch 3、write 2、edit 2、read 1、memory_read 1 |

构建验证：`sphinx-build -b html . _build/html` 成功，新增页面零警告（全站仍有 2 条历史警告，来自 `ai/coding/requirements-prompting.md` 的 plantuml lexer 与 `article/ip-login-auth-security.md` 的 http lexer，与本次改动无关）。

