# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

- 顶层 `.md` 文件是各主题的正文 (如 `git.md`、`vim.md`、`software.md`)
- 子目录 (如 `linux/`、`mysql/`、`redis/`、`nginx/`) 内包含更细粒度的主题文档
- `shellprogramming/` — Shell 编程教程
- `restructed/` — reStructuredText 语法参考
- `_static/` — 静态资源 (CSS、图片等)
- `img/` — 文档图片

## 文件命名

所有文件名和目录名均使用英文，文档内容为中文。Markdown 文件名与主题对应 (如 `git.md` → git 相关内容)。

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
