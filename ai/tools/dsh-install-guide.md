# 不会装 Python 和 npm，怎么用上 DeepSeek Harness

```{contents}
```

写给一个「只会用软件、不会配开发环境」的朋友：想用能直接操作你电脑文件的 DeepSeek，
但一看到 npm、Python、命令行就头大。这篇就是为你写的，**全程只需要下载、双击、粘贴一串字符**。

---

## 〇、先分清两个「DeepSeek」

别装错了，这是两件不同的东西：

| 你想要 | 该装什么 | 需要本文吗 |
|---|---|---|
| 像微信一样聊天、问问题 | **DeepSeek 官方 App**（手机应用商店搜 DeepSeek，或 [deepseek.com](https://www.deepseek.com/)） | 不需要 |
| 让它读你的文件、改代码、跑命令、装插件 | **DeepSeek Harness**（命令行命令叫 `dsh`） | 就是本文 |

DeepSeek Harness 是一个「跑在你自己电脑上的 AI 助手外壳」：模型还是 DeepSeek 的模型，
但它的手伸得到你的文件夹——读文档、整理表格、改代码、批量改文件名，都能干。

而它的**桌面端安装包，自带 Node.js、Python、pnpm 三套运行时**。
也就是说：网上那些「先装 Python 3.11、再装 Node、再 npm install」的教程，你**一律可以跳过**。
你只需要装一个像 QQ 一样的东西。

---

## 一、三条路线，先选一条

```{mermaid}
flowchart TD
    A["你想在哪用？"] --> B["自己的 Windows 电脑"]
    A --> C["自己的 Mac"]
    A --> D["Linux / 服务器 / Intel 老 Mac"]

    B --> E["路线 A：桌面端<br/>双击安装，零命令行 ⭐推荐"]
    C --> F{"Apple 芯片<br/>（M1 及以后）？"}
    F -- 是 --> E
    F -- 否 --> D

    D --> G["路线 B：命令行 + 浏览器界面<br/>要装一次 Node.js"]
    E --> H["以后也想在终端里敲 dsh？<br/>桌面端菜单一键注册"]
    G --> H
```

三条路线对比：

| | 路线 A 桌面端 | 路线 B 命令行 Web 版 |
|---|---|---|
| 要装什么 | 一个安装包 | Node.js（唯一要装的「环境」，双击安装） |
| 要敲命令吗 | 完全不用 | 一条 |
| 支持的平台 | Windows x64、macOS（Apple 芯片，macOS 13+） | Windows / macOS / Linux 全都行 |
| 装插件 | 界面里点「安装」，自带 pnpm | 界面里点安装，但要先 `npm i -g pnpm` |
| 升级 | 应用内「检查更新」 | 重新跑一条命令 |
| 关掉窗口会停吗 | 不会，后台继续跑（Windows 有托盘图标） | 会，那个终端窗口关了服务就停了 |

> 官方下载页目前只提供 Windows 和 Apple 芯片 macOS 两版桌面端。
> Intel 芯片的 Mac、以及 Linux，请走路线 B，效果一样，只是多一步装 Node.js。

---

## 二、路线 A：桌面端（推荐，约 5 分钟）

### 第 1 步：下载

打开官方下载页 [deepseek.com/download](https://www.deepseek.com/download/)，在「DeepSeek Harness 全新桌面端」那一块点下载：

| 系统 | 直链 |
|---|---|
| Windows x64 | <https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe> |
| macOS（Apple 芯片） | <https://download.deepseek.com/desktop/dsh-latest-macos-arm64.dmg> |

安装包认准 `download.deepseek.com` 这个域名。别从搜索引擎里随手点「高速下载」，那多半是套壳。

### 第 2 步：安装

- **Windows**：双击 `.exe`，一路「下一步」。如果弹出蓝色的「Windows 已保护你的电脑」，
  点「更多信息」→「仍要运行」。装完桌面和开始菜单会有个鲸鱼图标的应用。
- **macOS**：打开 `.dmg`，把鲸鱼图标拖进「应用程序」。
  第一次打开若提示「无法验证开发者」，去 **系统设置 → 隐私与安全性**，页面下方点「仍要打开」。

### 第 3 步：拿到 API Key

DeepSeek Harness 本身是免费的壳，**干活要花 API 的钱**（按用量计费，日常对话很便宜）。

1. 浏览器打开 <https://platform.deepseek.com/>，用手机号或微信注册/登录；
2. 左侧找到 **API keys**（<https://platform.deepseek.com/api_keys>）→「创建 API key」；
3. 名字随便写，比如 `我的电脑`，创建后会得到一串 `sk-` 开头的字符；
4. **立刻复制保存**——这串东西只会完整显示一次，关掉页面就再也看不到（只能删了重建）。

如果余额是 0，先去「充值」充一点。没有余额时，助手会报错但不告诉你原因，很容易误以为是软件坏了。

### 第 4 步：首次打开，把 Key 粘进去

打开应用，会看到欢迎界面，里面有一个「**添加 API Key**」的输入框。
（预览版里「登录」按钮可能还是灰的——账号体系还在迭代，用 Key 进门就行。）
把那串 `sk-...` 粘进去、保存。

> 小提示：Key 存在本机 `~/.dsh/.credentials.yaml`（Windows 是 `C:\Users\你的用户名\.dsh\`），
> 只用来向 DeepSeek 官方接口证明身份。别把这个文件、或者 `sk-` 开头的字符串发给别人。

### 第 5 步：选一个「工作区」文件夹

助手只能动你**指定**的文件夹。所以在磁盘上先建一个空文件夹，比如：

- Windows：`D:\dsh-work`
- macOS：`~/Documents/dsh-work`（文稿里新建个 dsh-work）

然后在界面里点「选择工作区」，选中它。以后放的资料、让它改的文件，都在这个文件夹里。

### 第 6 步：说第一句话

在对话框里输入（界面里也有示例提示可以点）：

> 帮我看看这个文件夹里有什么，列个清单

或者更贴近日常的：

> 把这个文件夹里的图片按拍摄日期重命名

界面会弹审批，问你要不要允许读文件、要不要允许执行命令，点允许即可。
**默认任何有风险的操作（删文件、跑命令、装插件）都会先问你**，不点就不会动。

到这一步就算装完了。剩下的时间都是「你想让它干什么」。

### 桌面端的三个隐藏福利

1. **菜单里的「Manage dsh Command…」**：可以把 `dsh` 命令注册到系统里。
   以后想在终端里敲 `dsh`（比如用它的命令行模式），不用 `npm install -g`，点这里装上就行。
2. **关窗口 ≠ 退出**：Windows 会留一个托盘图标，Mac 留在 Dock。长任务在后台继续跑。
   不会自动停，也就不会把你跑到一半的任务掐掉。
3. **左下角能看到更新**：有新版本时账户那一栏会出现提示，点一下就能升级，不用重装。

---

## 三、路线 B：命令行 + 浏览器界面（Intel Mac / Linux / 想折腾）

如果你在 Intel Mac 或 Linux 上，或者就是喜欢浏览器里开一堆标签页，走这条。
它比想象中简单：**只有一个安装包**。

### 第 1 步：装 Node.js（这是唯一要装的「环境」）

打开 <https://nodejs.org/>，下载 **LTS** 版本，双击安装、一路下一步。装完打开终端验证：

```sh
node -v      # 看到 v22.x / v24.x 之类的版本号就对了
npm -v
```

`npm` 不用单独装——它是 Node.js 自带的。很多教程让人「安装 npm」，其实装 Node 就一起装上了。

### 第 2 步：跑起来

在终端里任意目录执行：

```sh
npx @deepseek-ai/dsh web
```

第一次会下载两百多兆的依赖，等两三分钟。跑完后它会自动打开浏览器（打不开就手动访问
`http://127.0.0.1:3080`）。如果是通过 SSH 登录的机器，它只打印一个网址，需要你自己做端口转发。

**第一次启动的 URL 里带 `?token=...`**。这个 token 相当于门禁卡，别把带 token 的地址截图发人。
换浏览器或清空 cookie 后，要回到终端复制当前进程打印的那个地址。

### 第 3 步：填 API Key

界面里 **设置 → 模型 → DeepSeek**，把 `sk-...` 粘进去保存。保存后立刻可用，不用重启。

### 第 4 步：想装插件，再补一条命令

界面里装插件靠的是 `pnpm`，Node 自带的 npm 不算。补一条：

```sh
npm install -g pnpm
```

不装 pnpm 的话，插件安装会失败并提示「没有找到 pnpm，无法安装」。桌面端不用管这一步，它自带 pnpm。

### 第 5 步（国内网络建议）

如果下载卡住或者插件装不动，换国内镜像，一条命令的事：

```sh
npm config set registry https://registry.npmmirror.com
```

DSH 的插件安装也会自动在官方源连不上时退到 `registry.npmmirror.com`，
界面里也能手动选「中国大陆镜像源」。

### 提示：想常用就全局装一次

`npx` 每次都检查最新版，慢一点。想固定在本地：

```sh
npm install -g @deepseek-ai/dsh
dsh web
```

升级则是 `npm install -g @deepseek-ai/dsh@latest`。注意：**升级 DSH 可能让第三方插件失效**
（插件要声明自己兼容哪个版本），见后文「插件的三条硬规矩」。

---

## 四、插件：DSH 的灵魂

### 4.1 一句话：这个软件「连自己都是插件」

DSH 的架构口号是 **everything is a plugin**——模型接入、工具、界面、侧边栏、主题皮肤，
全都是挂载在宿主进程里的插件。所以「插件」在这里不是锦上添花，而是**扩展能力的唯一方式**：

| 插件能给你什么 | 例子 |
|---|---|
| 新工具（让它能碰以前碰不到的东西） | 连 MySQL、查 Jira、读公司 Confluence、发企业微信 |
| 新界面（侧边栏、面板、皮肤） | 文件树 + 内置编辑器、改动对比面板、主题皮肤 |
| 新模型入口 | Kimi / Claude / 本地模型的订阅或接口接入 |
| 省钱与观测 | 会话花了多少钱、token 统计、请求日志 |
| 玩法本身 | 多 Agent 团队协作、多模型评审会议室、定时任务 |
| 趣味 | 回合结束播放提醒音、桌面挂个宠物 |

一个插件说到底是**一个 npm 包**，装进你的 profile 目录，宿主启动时把它挂上。
它和「skill」不是一回事：**插件是可执行代码，skill 只是给模型看的说明书**。
两者区别的完整对照见 [DSH 插件 与 Claude Skill 的区别](./plugin-vs-skill.md)。

### 4.2 去哪里找插件

| 渠道 | 地址 | 适合 |
|---|---|---|
| 内置插件市场 | 装 `dshmarket` 插件后，**插件**页多一个「插件市场」标签 | 新手首选，能搜、能看中文介绍、一键装 |
| 精选清单 | <https://awesome-dsh-plugin.com>、[GitHub 仓库](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin) | 已收录数千个插件，有中文描述和分类 |
| GitHub topic | <https://github.com/topics/dsh-plugin> | 看源码、看 star 数 |
| 让助手自己找 | 装 `dsh-find-plugin` 插件后，直接说「帮我找个任务结束发微信通知的插件」 | 懒得翻网页 |

### 4.3 三种安装方式

**方式一：界面安装（推荐，桌面端和 Web 版都行）**

1. 打开左侧边栏的「**插件**」页（新版也可能在 **设置 → 插件** 里；界面文字会随版本变，
   找不到就找「插件」两个字）；
2. 点「**添加插件**」；
3. 在输入框里填一个「安装源」，三种写法都行：

   ```text
   dsh-cost-meter                      # npm 包名（推荐，最稳）
   github:awesome-dsh-plugin/dsh-find-plugin   # GitHub 仓库
   /home/you/my-plugin                 # 本机目录（自己写插件时才用）
   ```

4. 如果下载卡住，把「安装源」从「npm 官方源」切到「**中国大陆镜像源**」再试；
5. 点安装，等进度跑完。多数插件会提示「更改将在下次启动生效」——重启 DSH 就好。

**方式二：一条命令（适合路线 B，或想批量装）**

```sh
dsh plugin --profile web add dsh-cost-meter
```

桌面端用户注意：桌面端用的是**它自己的 profile**（不叫 `web`），
所以这条命令在装了桌面端的机器上会「装到另一个 profile 里」，界面里并不会出现。
桌面端请一律用界面安装。

**方式三：直接让助手装（它自己就有这个工具）**

对话里说：

> 帮我装 dsh-cost-meter 这个插件

它会调 `plugin_manager` 工具完成安装，并在装之前告诉你这个插件是干什么的。
有风险的操作仍然会让你审批。

### 4.4 装完在哪看、怎么关

- **插件页**：已装的插件、每个插件包含哪些组件、运行中/已停用/异常状态，都能看到，也能一键卸载。
- **设置 → 内置插件**：DSH 自带的插件清单，只读，用来排查「这个功能是哪个插件提供的」。
- **开关单个组件**：不想全卸载但想临时关掉某个能力，就在插件详情里关掉那一行。
- 插件**要手动升级**：新版插件页对可升级的插件提供「更新」入口；老版本没有这个入口时，卸载再装新版。官方内置插件跟着 DSH 版本走，升级 DSH 即可。

### 4.5 值得先装的几个（都不需要写代码）

| 包名 | 作用 | 说明 |
|---|---|---|
| `dshmarket` | 内置插件市场 | 装完在插件页多一个「插件市场」标签，之后装别的东西就是搜索 + 点安装 |
| `dsh-cost-meter` | 花了多少钱 | 每次会话的成本、当日累计、历史记录，支持多厂商模型计价。新手最该先装的一个 |
| `dsh-better-sidebar` | 文件树 + 编辑器 + 改动面板 | 不用切到 VSCode 就能看它改了哪个文件的哪一行 |
| `dsh-find-plugin` | 让助手帮你找插件 | 「帮我找个能读 Excel 的插件」，它去 GitHub 搜给你 |
| `dsh-auto-memory` | 跨会话记忆 | 自动把「你是做什么的、偏好什么」记下来，下个会话还认得你 |
| `dsh-turn-music` | 回合结束提示音 | 长任务跑完「叮铃」一声，你就可以去干别的了 |

进阶玩法（装之前先确认它声明兼容你的 DSH 版本）：

| 包名 | 作用 |
|---|---|
| `@nanmicoder/dsh-agent-teams` | 把一个会话变成一支多 Agent 团队：队长拆任务、分派、汇总 |

再往上还有多模型交叉评审、定时任务、语音输入这类插件，社区里都有人在做，
等前几个用顺了再去插件市场翻，不容易被花哨功能带偏。

### 4.6 插件的三条硬规矩

1. **插件是代码，以你的权限运行。**
   它不是「配置文件」，装进来就能读写你的文件、访问你的网络。
   安装界面会明确提示「请确认插件来源可信」。判断标准很朴素：GitHub 有源码、有 star、有更新记录。
   来路不明的 `.tgz` 或者群里发的「破解版」插件，别装。
2. **版本要对得上。**
   插件会声明自己兼容的 DSH 版本区间。不兼容的插件默认**装不上**（会直接拒绝，而不是装完崩）。
   升级 DSH 之后，第三方插件可能要等作者适配；急着用有风险的强制放行方式（版本豁免），
   但那意味着接受「可能崩溃或丢数据」。
3. **装错了不会报废。**
   插件页里卸载即可，配置写在 profile 目录，删掉插件不会动你的工作区文件。
   真出了启动问题，DSH 还有「安全模式」的 profile 可以救（命令行加 `--from-default-profile` 另起一个干净 profile）。

---

## 五、常见问题（先看这里，能省一半时间）

| 现象 | 原因 / 怎么办 |
|---|---|
| 打开是空白页或一直转圈 | 服务还在启动，等 30 秒；还不行就完全退出再打开 |
| Windows 报「已保护你的电脑」 | SmartScreen 对没有大量下载量的新软件都会报，点「更多信息 → 仍要运行」 |
| Mac 报「无法验证开发者」 | 系统设置 → 隐私与安全性 → 仍要打开 |
| 对话一发就报错，说额度/余额 | API 余额不足，去 platform.deepseek.com 充值；或 Key 粘贴时多了空格 |
| 报 401 / 令牌无效 | Key 被删了或复制不全，重新建一个 |
| 终端里 `npx` 命令找不到 | Node.js 没装好，或装完没重开终端；`node -v` 先验证 |
| 端口 3080 被占用 | `npx @deepseek-ai/dsh web --port 3081` |
| 插件安装失败「没有找到 pnpm」 | 路线 B 用户执行 `npm install -g pnpm`；桌面端不用管 |
| 插件安装卡在下载 | 安装源切「中国大陆镜像源」；GitHub 地址需要能直连 GitHub，装不上就改用 npm 包名 |
| 插件装完界面没变化 | 需要重启：完全退出 DSH（Windows 从托盘右键退出）再打开 |
| 桌面端里装了插件却不显示 | 你可能是在终端里用 `dsh plugin --profile web` 装的，桌面端用自己的 profile；用界面重装 |
| 关了窗口任务还在跑吗 | 桌面端在后台继续；路线 B 关掉终端就停 |
| 装完发现想卸载 | 桌面端走系统卸载；路线 B 执行 `npm uninstall -g @deepseek-ai/dsh`（当初用 `npx` 跑的本来就没装进系统）。配置和数据全在 `~/.dsh`，想彻底清掉连这个目录一起删 |

---

## 六、一页速查

**给「只想快点用起来」的朋友**：

1. 下载 <https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe>
2. 一路下一步装完，打开
3. 去 <https://platform.deepseek.com/api_keys> 建一个 `sk-` 开头的 Key，粘进欢迎页
4. 建一个空文件夹当工作区，选它
5. 说「帮我看看这个文件夹里有什么」

**命令速查（路线 B / 桌面端终端）**：

| 目的 | 命令 |
|---|---|
| 临时跑 Web 版 | `npx @deepseek-ai/dsh web` |
| 全局安装 | `npm install -g @deepseek-ai/dsh` |
| 升级 | `npm install -g @deepseek-ai/dsh@latest` |
| 装插件 | `dsh plugin --profile web add <包名>` |
| 换国内镜像 | `npm config set registry https://registry.npmmirror.com` |
| 启动但不自动开浏览器 | `dsh web --no-open` |

**关键路径**：

| 内容 | 位置 |
|---|---|
| 配置 / 凭据 / 会话 | `~/.dsh/`（Windows：`C:\Users\你的用户名\.dsh\`） |
| API Key | `~/.dsh/.credentials.yaml` |
| 某个 profile 装了哪些插件 | `~/.dsh/profiles/<名字>/package.json` |
| 插件与面板配置 | `~/.dsh/profiles/<名字>/cordis.patch.yml` |
| 桌面端的本地设置 | Windows `%APPDATA%\@deepseek-ai\dsh-desktop\`；macOS `~/Library/Application Support/@deepseek-ai/dsh-desktop/` |

---

## 参考

- [DeepSeek Harness 官方仓库](https://github.com/deepseek-ai/deepseek-harness)（README 里的 `npx` 用法、桌面端说明）
- [DeepSeek Harness 文档站](https://deepseek-harness.github.io/deepseek-harness/)
- [官方下载页](https://www.deepseek.com/download/)
- [DeepSeek 开放平台（API Key、充值）](https://platform.deepseek.com/)
- [精选插件清单 awesome-dsh-plugin](https://awesome-dsh-plugin.com)
- 本库相关笔记：[DSH 插件 与 Claude Skill 的区别](./plugin-vs-skill.md)、[DSH 内网部署实践](./dsh-intranet/README.md)

## 版本记录

| 版本 | 日期 | 模型 | 说明 |
|---|---|---|---|
| v1 | 2026-10-28 | deepseek-flash | 初稿：三条安装路线（桌面端 / 命令行 / Linux）、插件机制与安装方式、6 个推荐插件、FAQ 与速查表 |

本次消耗（截至成稿，按请求累加）：input 11.9 万 tokens、output 4.2 万 tokens、cache 读取 269.8 万 tokens，合计约 285.9 万 tokens。
