# 用 Git 管理 AI Memory 的方案

```{contents}
```

> 适用工具：Claude Code、Kimi Code CLI、DSH（DeepSeek Harness）。
> 核心思路：**memory 就是 markdown 文件，git 仓库是唯一事实来源**，通过软链/导入机制分发到各工具的约定位置。

## 三层划分

| 层级 | 作用域 | 放什么 | 在 git 仓里的位置 |
|---|---|---|---|
| **全局（用户级）** | 所有项目 | 个人偏好、沟通风格、通用工作流（如"回复用中文"、"提交信息格式"） | `global/` |
| **工作区（项目级）** | 单个项目 | 项目架构、构建/测试命令、代码规范、踩坑记录 | `projects/<项目名>.md`，或直接放在项目仓库里 |
| **个人整理（知识库）** | 跨项目沉淀 | 从会话中提炼的文档、笔记、方案（如本仓库的 `ai/`、`article/`） | 整个仓库本身就是 |

优先级共识：**工作区 > 全局**（项目级覆盖个人级），个人整理层不自动注入，由 AI 按需检索（Grep/Read）或人工引用。

## 各工具的 memory 机制与利弊

### Claude Code（CLAUDE.md 体系）

四级层级，启动时自动加载，层级高的先加载：

| 级别 | 位置 |
|---|---|
| 企业策略 | Linux: `/etc/claude-code/CLAUDE.md` |
| 项目（团队共享） | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` |
| 用户（全局） | `~/.claude/CLAUDE.md` |
| 项目（个人本地） | `./CLAUDE.local.md`（已废弃，官方建议改用 import） |

关键特性：
- **`@path` 导入**：CLAUDE.md 里写 `@~/memory/global.md` 即可引入外部文件，可递归，最深 5 层。这是接 git 仓的关键机制。
- **向上递归查找**：在子目录启动时会一路向上读各级 CLAUDE.md，monorepo 友好。
- **`#` 快捷追加**：输入以 `#` 开头，直接选择写入哪个 memory 文件。
- **`/memory`** 编辑、`/init` 生成项目初版。

**利**：层级最完整、import 机制让"git 仓集中管理 + 各项目按需引用"最自然；`#` 追加极大降低沉淀成本。
**弊**：`CLAUDE.md` 是私有文件名，与跨工具通用的 `AGENTS.md` 标准不兼容（需软链变通）；import 最多 5 层，深层知识库引用要控制深度。

### Kimi Code CLI（AGENTS.md 体系）

两级，均为 `AGENTS.md`：

| 级别 | 位置 |
|---|---|
| 全局（Kimi 专用） | `~/.kimi-code/AGENTS.md`（随 `KIMI_CODE_HOME` 移动） |
| 全局（跨工具通用） | `~/.agents/AGENTS.md` |
| 工作区 | 项目根的 `AGENTS.md`（也支持子目录级，按需加载） |

**利**：直接用 `AGENTS.md` 开放标准，与 Codex、DSH 等工具天然兼容，**一份文件多工具通吃**；`~/.agents/AGENTS.md` 是所有支持该标准的工具共享的全局层。
**弊**：没有 `#` 快捷追加、`/memory` 这类内置 memory 管理命令，沉淀要靠口头指令（"把这个写进 AGENTS.md"）；没有 `@import` 语法，引用外部文件只能靠会话中用 `@路径` 手动附带。

### DSH / DeepSeek Harness

- **工作区**：以运行命令时所在目录为 workspace 根，加载适用的 `AGENTS.md` 或 `CLAUDE.md`，**渲染预算上限 65,536 字节（64KB）**——超长会被截断，这是三者中唯一有硬性大小限制的。
- **全局/机器级**：没有独立的全局 memory 文件，全局偏好写在 home 级配置 `$DSH_HOME/cordis.patch.yml`（如 `personaPrefix` 字段，每轮注入），对所有 profile（web/headless）生效。
- **插件生态**：有大量第三方 memory 插件（长期记忆库、自动沉淀、跨会话 recall 等），如 `dsh-plugin-memory`、`dsh-memory-eternal`，可 `dsh plugin --profile web add <包>` 安装。

**利**：同时认 `AGENTS.md` 和 `CLAUDE.md`，接入成本低；插件生态提供超出"静态文件"的动态记忆（自动沉淀、检索召回）。
**弊**：64KB 渲染预算要求 memory 文件保持精简；全局层是 YAML 配置不是 markdown，不适合放大段知识，且在家目录配置里不便随 git 仓同步（只能软链整个 patch 文件）；插件质量参差，内网环境装不了插件时只剩静态文件一条路。

## 推荐落地方案

### 目录结构（一个 git 仓管全部）

```
memory-repo/
├── global/
│   └── AGENTS.md            # 全局通用偏好（三工具共享的事实来源）
├── projects/
│   ├── linux-reference.md   # 各项目的 curated memory
│   └── some-project.md
├── kb/                      # 个人整理层：沉淀的知识文档（本仓库的 ai/、article/ 即此角色）
└── sync.sh                  # 分发脚本（软链到各工具约定位置）
```

### 分发方式

```bash
# 全局层：一份文件，三处软链
ln -sf ~/memory-repo/global/AGENTS.md ~/.agents/AGENTS.md        # Kimi 等通用标准
ln -sf ~/memory-repo/global/AGENTS.md ~/.kimi-code/AGENTS.md     # Kimi 专用全局（可选，与上行二选一）
ln -sf ~/memory-repo/global/AGENTS.md ~/.claude/CLAUDE.md        # Claude 全局

# 工作区层：在每个项目根目录
ln -sf ~/memory-repo/projects/some-project.md /path/to/project/AGENTS.md
cd /path/to/project && ln -sf AGENTS.md CLAUDE.md                # Claude 兼容（Kimi/DSH 直接认 AGENTS.md）
```

DSH 的全局偏好（personaPrefix）内容少，直接在 `~/.dsh/cordis.patch.yml` 里写一句"先读 ~/memory-repo/global/AGENTS.md"，让它每轮从 git 仓取最新内容，避免维护两份。

### 日常工作流（AI + git 闭环）

1. **沉淀**：会话中产生值得记住的内容时，直接对 AI 说"把这个写进 memory"——Claude 用 `#` 前缀，Kimi/DSH 口头指令即可。写完文件就在 git 仓里（软链），`git diff` 一目了然。
2. **审阅**：memory 是 AI 的"自我暗示"，写错了会反复带偏。**每次提交前人工过一遍 diff**，宁缺毋滥。
3. **同步**：`git commit && git push`，其他机器 `git pull` 即生效（软链指向仓内文件，无需再分发）。
4. **整理**：定期让 AI 把 `projects/*.md` 中沉淀的通用经验提炼到 `kb/`（个人整理层），保持 memory 文件精简——这对 DSH 的 64KB 预算尤其重要。

### 注意事项

- **不要入库密钥/内网地址**：memory 文件会被注入每次会话并可能随会话导出，敏感信息一律不放。
- **控制体积**：DSH 64KB 硬上限、Claude import 5 层深度，都指向同一原则——memory 文件放"指针和规则"，细节放知识库文档，用路径引用。
- **AGENTS.md 是最大公约数**：三工具都认它（Claude 靠软链 `CLAUDE.md -> AGENTS.md`），新内容默认写 AGENTS.md 体系。
- **个人整理层不进上下文**：知识库靠 AI 按需 Grep，不要全部塞进 memory 文件，否则挤占对话上下文、拖慢每次请求。

## 参考来源

- [Claude Code Memory 官方文档](https://docs.claude.com/en/docs/claude-code/memory)
- [Kimi Code CLI 数据目录（含全局 AGENTS.md）](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/data-locations.html)
- [dsh CLI 行为参考（AGENTS.md 加载与 64KB 预算）](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.zh.md)
