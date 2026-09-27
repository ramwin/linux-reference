# DSH 插件 与 Claude Skill 的区别

```{contents}
```

这两个词经常被混着用, 其实它们根本不在一个层次上:

> **skill 是给模型的说明书, plugin 是给宿主的插件板。**

- **DSH 插件**是一个被挂载进宿主进程的 npm 包——**可执行代码**, 能注册工具、服务、界面;
- **skill** 是一个带 frontmatter 的 `SKILL.md` 文本文件——**只是提示词**, 模型读了照着做。

最容易混的地方在于: **两边各自都有一套「插件 + skill」**。所以正确的对照不是「DSH 插件 vs Claude skill」, 而是:

| 对照关系 | DSH | Claude Code |
|---|---|---|
| 扩展宿主本身 | 插件 (Cordis 包) | 插件 (`.claude-plugin/plugin.json`) |
| 扩展模型行为 | skill (`SKILL.md`) | skill (`SKILL.md`) |

而这两个「插件」也是貌合神离的: DSH 的插件是**代码**, Claude 的插件是**内容容器**(清单 + 一堆声明式文件, 见 [Claude 插件组件文档](https://code.claude.com/docs/en/plugins/components.md))。

## 一、DSH 插件: 宿主的一部分

DSH 是 Cordis 依赖注入容器。一个插件就是 package.json 里带 `dsh` 字段的 npm 包, 用 `dsh plugin --profile <name> add <pkg>` 装进 profile, 再被写进 profile 的 bundle 列表, 由 Loader 挂载。

以本机的 `@nanmicoder/dsh-agent-teams` 为例, 它的 `dsh` 字段:

```json
{
  "name": "@nanmicoder/dsh-agent-teams",
  "dsh": {
    "bundle": { "patch": "./cordis.patch.yml" },
    "client": { "platform": "web", "inject": ["@deepseek-ai/dsh-client-ui-conversation", "..."] }
  },
  "peerDependencies": { "@deepseek-ai/cordis": "^4.0.2", "@deepseek-ai/dsh-agent": "..." }
}
```

三个字段各代表一种能力:

| 字段 | 作用 |
|---|---|
| `bundle.patch` | 一个 YAML patch 文件, **直接改宿主的配置树**(按 id 覆盖配置、禁用行、插入新行) |
| `client` | 挂浏览器端代码: 往 Web GUI 里注入界面(AgentTeams 的树状监控就是这样来的) |
| `peerDependencies` | 声明它依赖宿主的哪些包, 版本不满足时安装被拦下 |

它的 patch 文件长这样, 注释直说了自己在干什么:

```yaml
# mounts the agent-teams plugin into the host composition of a dsh profile.
# The plugin registers its `agent_teams_*` tools into the shared `tools`
# registry and one usage section into the global system prompt ...
- insert:
    - id: agent-teams
      name: '@nanmicoder/dsh-agent-teams'
      config:
        stateDir: .agent-teams
```

**「把工具注册进 tools 注册表、往系统提示词里插一段」——这句话 skill 永远说不出来。**

插件的能力清单大致是:

- 注册服务(`ctx.skills.registerProvider(...)`)、注册工具、追加系统提示词段落;
- 通过 `dsh.client` 提供浏览器端 UI;
- 用 patch 改配置树, 连基础层的行都能覆盖或禁用;
- 生命周期由 Loader 管: `pending` / `loading` / `active` / `failed`, 失败非致命。

## 二、skill: 提示词包

一个目录, 里面一个 `SKILL.md`, frontmatter 的 `description` 常驻上下文, 正文按需加载。DSH 的 skill 格式(用 `~/.dsh/skills/` 举例):

```markdown
---
name: deploy-check
description: 上线前按团队清单逐项核对
whenToUse: 用户说"要上线了""发版"
disable-model-invocation: false
user-invocable: true
---

1. 跑测试 ...
2. 检查 migrations ...
```

它没有代码。所谓「能力」全部来自 frontmatter 里的声明式开关:

| 字段 | 作用 | 谁实现这个行为 |
|---|---|---|
| `description` | 什么时候该用它 | 模型自己判断 |
| `whenToUse` | 补充的使用时机 | 模型自己判断 |
| `user-invocable` | 能不能 `/name` 调 | 宿主读 frontmatter |
| `disable-model-invocation` | 允不允许模型自己调 | 宿主读 frontmatter |

DSH 的实现细节(来自 `@deepseek-ai/dsh-skill-filesystem`):

- 格式: `<root>/<name>/SKILL.md` 或平铺 `<root>/<name>.md`, **刻意不支持** `**/SKILL.md` 递归发现;
- `name` 必须 kebab-case, `description` 必填;
- 扫描根与优先级: 项目 `.dsh/skills`(100) > 项目 `.agents/skills`(200) > 自定义目录(300) > 用户 `~/.dsh/skills`(400) > `~/.agents/skills`(500);
- 目录条目和正文分开: 发现只解析 frontmatter, 每次加载重读正文, 所以改正文不用重启;
- 目录变了会追加一份**完整替换**的目录, 空目录用来停用旧名字。

注意 DSH 的 frontmatter 键是 kebab-case, 写成 `userInvocable` 这类驼峰会**让整个 skill 被丢弃**并只留一条警告——源码里专门有函数拒绝旧拼写。

## 三、Claude skill: 同一个思路, 多了几件武器

Claude Code 的 skill 遵循 [Agent Skills 开放标准](https://agentskills.io), 基础字段就是 `name` / `description` / `license` / `compatibility` 那几个; 下面这些是 Claude Code 自己的扩展(来源: [Claude Skills 文档](https://code.claude.com/docs/en/skills.md)):

| 扩展 | 作用 | 代价 |
|---|---|---|
| `allowed-tools` | 调用这一轮临时预授权工具, 免弹窗 | 项目里的 skill 能给自己发权限, 仓库里的 skill 要先看再跑 |
| `context: fork` | 丢进子 agent 隔离执行 | 子 agent 看不到对话历史, 指令必须自洽 |
| `` !`cmd` `` 动态注入 | **渲染时由宿主执行命令**, 输出内联进提示词 | 命令失败会让整次调用中止; 受 `disableSkillShellExecution` 管控 |
| `$ARGUMENTS` / `$0` / `$1` | 参数替换 | — |
| `skillOverrides` 设置 | 不改文件就调整可见性: `on` / `name-only` / `user-invocable-only` / `off` | — |

另外 Claude 的 skill 来源除了文件, 还有从 claude.ai 账号同步下来的那一份(`~/.claude/skills/synced/`)。

## 四、唯一的例外: 动态注入

上面说 skill 里没有代码, 有一个例外必须点出来:

```markdown
## 当前改动
!`git diff HEAD`
```

`` !`cmd` `` 是**宿主替模型跑命令**, 把输出替换进正文。这确实是「执行」, 但它和插件是两个方向:

- 动态注入: 宿主执行 → **输出文本给模型看**, 模型拿不到新工具、新服务、新界面;
- 插件: 宿主执行 → **在宿主里留下一个常驻能力**, 之后的每一步都能用。

所以动态注入是把 skill 的「提示词」做成了活的, 不是把 skill 变成了插件。

## 五、一张表总结

| | DSH 插件 | skill (DSH / Claude 通用) |
|---|---|---|
| 本质 | npm 包 + Cordis 插件 | 一个 `SKILL.md` 文本文件 |
| 宿主会不会执行它 | **会**, `require()` 进进程 | **不会**, 只是塞进上下文 |
| 形态 | 代码 + patch + 可选的浏览器端代码 | 自然语言 |
| 新增能力 | 工具、服务、UI、路由、提示词段落 | 无, 只能影响模型决策 |
| 改宿主状态 | 能(注册表、配置树) | 不能 |
| 权限模型 | 宿主 peer 版本校验 + 装机审批 | frontmatter 的 `allowed-tools` + 用户权限规则 |
| 分发 | `dsh plugin add`(pnpm 装进 profile) | 放进 `.dsh/skills` / `.claude/skills` / 插件里 |
| 热更新 | 改配置树可 live reload, 失败的 fiber 非致命 | 改正文立即生效, 无需重启 |
| 出错的样子 | fiber 被拒 / 插件加载失败 | frontmatter 非法则整个 skill 被静默跳过 |

## 六、动手验证

`ai/plugin_vs_skill_demo/` 下有一个**零依赖纯 Python** 的小实验, 不信上面的结论就直接跑——它读本机真实的安装目录, 数「哪些组件是要被执行的代码」:

```bash
python3 ai/plugin_vs_skill_demo/plugin_vs_skill.py            # 完整对照
python3 ai/plugin_vs_skill_demo/plugin_vs_skill.py --json     # 机器可读
```

它做的事:

1. 扫 profile 的 `node_modules`, 凡是 `<pkg>/package.json` 里有 `dsh` 字段、且 `main`/`exports` 指向**真实存在的 .js 文件**的, 就判定为「可能被执行的插件」;
2. 扫各个 skill 根, 解析 `SKILL.md` 的 frontmatter, 统计授权工具数、动态注入命令数、`fork` 标记;
3. 把两边并排打印, 并说明分界线在哪。

本机实测输出(有截断):

```
一、DSH 插件: 有 dsh 字段 + 有可执行入口
包名                                  版本      可执行入口  lib 的 js 数  改配置树  浏览器 UI  宿主 peer
@nanmicoder/dsh-agent-teams         0.1.21  是      33          是     是       24
@smalltailqwq/dsh-client-ui-skin-…  0.1.6   是      2           是     是       2
dsh-better-sidebar                  0.21.1  是      7           是     是       18
dsh-cost-meter                      1.7.39  是      29          是     是       2
dshmarket                           1.66.2  是      47          是     是       3

共 8 个插件。

二、skill: 只有 SKILL.md, 没有可执行入口
skill                         体系      模型可调  用户可调  授权工具数  动态注入  fork 子代理
claude-automation-recommend…  claude  是     是     4      0     -
claude-security               claude  是     是     23     2     -
...

共 31 个 skill。

三、结论
  插件   8 个: 8 个有可执行入口, lib 下共 151 个 .js 文件
  skill  31 个: 10 个声明了工具授权, 2 个含动态注入命令
```

```{note}
脚本的判定标准是「宿主会不会 require 它」, 这是一个可机械核对的客观事实, 它不评价插件好不好用。`lib 的 js 数` 只是规模, 不代表能力边界。
```

## 七、怎么选

| 你想干的事 | 写什么 |
|---|---|
| 加一个模型能调用的新工具 / 新数据源 | **插件**(skill 表达不了) |
| 改 Web GUI、加一个面板或侧边栏 | **插件** |
| 改宿主的加载组合、覆盖某一行配置 | **插件 + patch** |
| 让模型按固定流程做事、写规范、做检查清单 | **skill** |
| 把一段反复粘贴的指令固化下来 | **skill** |
| 把一组 skill/hook/agent 打包分发 | Claude 那边是**插件**; DSH 那边是**插件包自带 `skills/`** |

最后提醒两个容易踩的坑:

1. **`CLAUDE.md` 对 DSH 无效**。那是 Claude Code 的项目记忆机制; DSH 走 `AGENTS.md` 和 `.dsh/skills`。仓库里放一份 `CLAUDE.md` 并不会被 DSH 读作项目指令。
2. **DSH 和 Claude 的 skill 字段不完全兼容**。两边都有 `disable-model-invocation`, 但 Claude 写 `user-invocable`, DSH 也写 `user-invocable`——而 DSH 对 `name` 要求 kebab-case, 对拼写错误零容忍。跨工具复用一份 `SKILL.md` 时, 先确认字段在两边都合法。

## 参考资料

- [Claude Code: Extend Claude with skills](https://code.claude.com/docs/en/skills.md) — skill 的 frontmatter、动态注入、fork、权限模型
- [Claude Code: Add components to a plugin](https://code.claude.com/docs/en/plugins/components.md) — Claude 插件能装哪些组件
- [Agent Skills 开放标准](https://agentskills.io) — skill 的跨工具通用字段
- 本机源码: `@deepseek-ai/dsh`(启动器与 profile)、`@deepseek-ai/dsh-skill-filesystem`(本地 skill 发现)、`@deepseek-ai/dsh-skill`(skill 注册表)、`@deepseek-ai/dsh-tool-skill`(面向模型的目录与加载工具)、`@deepseek-ai/dsh-host-plugin-inventory`(插件清单投影)
- 本机实例: `~/.dsh/profiles/web/package.json`(profile 的 bundle 列表)、`@nanmicoder/dsh-agent-teams`(典型插件)
