# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 公开仓红线（先读这条）

**本仓是公开仓库**：GitHub `ramwin/linux-reference` 是 public，站点
<https://linux-reference.ramwin.com> 匿名可读。写任何内容前先假定它会被全网看到。

**禁止写入的真实信息**（一律用占位符代替）：

| 类别 | 占位写法 |
| --- | --- |
| 磁盘/文件系统 UUID | `UUID=11111111-1111-1111-1111-111111111111` |
| 真实挂载点、磁盘布局、阵列成员 | `/mnt/data`、`/dev/sdX` |
| 个人家目录、用户名 | `/home/user`、`/run/media/user` |
| 内网 IP、内网域名、主机名 | `192.0.2.10`、`host.example.com` |
| 账号、密码、token、私钥 | `user`、`password`、`$TOKEN` |

真实的机器信息（挂载点、UUID、主机名、内网地址、账号）只记在私有仓
`~/github/个人/life` 或 `~/github/secret`，不进本仓。

**归档归属**：用户在哪里提问，解答就归档到那个工作区对应的仓。在 `life`
工作区问的运维操作 → 记进 life 仓，不要顺手搬到本仓。本仓只沉淀可公开的通用知识。

发现本仓已有真实信息泄露时，改成占位符并在 commit message 里说明。

## 项目概述

这是个人的 Linux 知识参考库，使用 Sphinx 构建为静态文档站点，托管于 Read the Docs。内容为中文，涵盖 Linux 命令、系统管理、数据库、软件配置等。

## 常用命令

```bash
# 安装依赖
pip install -r requirements.txt

# 本地开发服务器 (带热重载, 端口 18002)
./run_server.sh

# 手动构建 HTML
make html
# 或
sphinx-build . _build/html/

# 发布到线上 https://linux-reference.ramwin.com
# 线上由服务器 systemd timer 自动部署(docs-autodeploy@linux-reference.timer,
# 每 5 分钟 git pull origin/master,有新提交才跑仓内 自动发布.sh 构建)
# 所以 push 后最多 5 分钟自动上线;想立刻上线再跑 ./发布.sh
./发布.sh [要校验的页面路径, 默认 ai/]

# 构建其他格式
make latexpdf
make epub

# 查看 Makefile 支持的所有 target
make help
```

## 架构

- **源文件格式**: 同时支持 `.rst` (reStructuredText) 和 `.md` (Markdown)，通过 `myst_parser` 扩展实现 Markdown 解析。
- **入口文件**: `index.rst` 是文档根节点，通过 `toctree` 指令组织各章节。
- **Sphinx 配置**: `conf.py` — 主题为 `sphinx_rtd_theme`，语言为 `zh_CN`，启用了 `myst_parser`、`sphinx_design`、`sphinxcontrib.mermaid` 等扩展。
- **构建输出**: `_build/` 目录 (已加入 `.gitignore`)。
- **Read the Docs**: `.readthedocs.yaml` 配置了自动构建流程，Python 3.11 环境。

## 内容组织

- 根目录保留 Sphinx 工程文件、仓库说明和 `database.md`、`software.md` 等主题聚合页，具体正文放入对应子目录
- `index.rst` — 首页，只列主要章节 (`:maxdepth: 1`)
- `contents.md` — **完整目录页**，按主题用 `{toctree}:glob:` 汇总全部文档；新增顶层目录时要在里面加一条 glob
- 每篇文档标题下放一条 `{contents}`（`.md`）或 `.. contents::`（`.rst`），生成页内目录，参考 `ai/fundamentals/local-ai-service.md`
- 主题目录包括 `ai/`、`article/`、`database/`、`linux/`、`network/`、`software/` 等；`git/README.md`、`vim/README.md` 等同时作为对应主题的入口
- `shellprogramming/` — Shell 编程教程，通用 Shell 配置在 `shellprogramming/config/`
- `restructed/` — reStructuredText 与 Markdown 语法参考
- `script/` — 通用脚本；各主题自己的配置和示例放在对应目录
- `_static/` — 静态资源 (CSS、图片等)

## 文件命名

新增 Sphinx 源文件和目录使用英文，正文使用中文；`article/` 随笔及已有历史文件可以保留中文名。Markdown 文件名与主题对应。

## MyST Markdown 特有语法

```markdown
```{toctree}
:maxdepth: 2
./subpage.md
```

```{note}
这是一个提示框 (由 sphinx_design 扩展提供)
```
```

## 注意事项

- 不要在 conf.py 的 `suppress_warnings` 列表中添加新的警告抑制项，除非有充分理由。
- `stderr.log` 和 `stdout.log` 是 root 拥有的日志文件，不应提交或操作它们。
- 项目没有自动化测试，验证文档正确性的方式是 `make html` 构建成功且无警告。
