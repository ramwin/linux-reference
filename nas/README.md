# NAS

家庭 / 自建 NAS 资料索引。目前主要是**绿联 NAS（UGOS Pro 系统）**的官方文档入口、文档大纲，
以及几个高频问题的结论。后续再问 NAS 相关问题，先从这里找入口和数据。

```{contents}
```

## 官方帮助文档入口

绿联的文档分两套，别搞混：

| 名称 | 地址 | 特点 |
| --- | --- | --- |
| **教程中心**（文档教程） | <https://www.ugnas.com/tutorial-list> | 服务端渲染的静态页，正文直接可抓。单篇形如 `/tutorial-detail/id-164.html`。**查内容优先用这个** |
| **知识中心** | <https://support.ugnas.com/knowledgecenter/#/> | 新版 FAQ / 知识库，SPA，正文走 `api.ugnas.com` 接口。内容更新，适合查新功能 |
| 功能兼容参考列表 | <https://comp-list.ugnas.com/pages/compatibility> | 硬盘 / 内存 / UPS 兼容型号 |
| RAID 计算器 | <https://www.ugnas.com/raid-calculator> | 算可用容量 |
| 下载中心 | <https://www.ugnas.com/support/download> | 固件、各端客户端 |
| 开发者平台 | <https://developer.ugnas.com/> | |
| 社区 | <https://club.ugnas.com/> | 新手入门版有官方客服（ID：吉伊⭐）回帖，硬件类问题常在这里被确认 |
| 在线体验 | <https://www.ugnas.com/experience/#/pc-pro-exp> | 不接设备就能点 UGOS Pro 界面 |

### 抓取备忘（给自己下次用）

知识中心是 Vue SPA，页面 HTML 里没有正文，要直接打接口：

```bash
# 搜索：keyword 必填；language 必填（zh-CN），漏了会报「语种不能为空」
curl -s 'https://api.ugnas.com/api/system/knowledge_center/sa/base/search?keyword=外部存储&pageSize=10&pageNum=1&language=zh-CN' \
  -H 'Referer: https://support.ugnas.com/'

# 取正文：注意参数名是 articleInfoId（不是 id），值取自搜索结果的 articleInfoId 字段
curl -s 'https://api.ugnas.com/api/system/knowledge_center/sa/base/article/info?articleInfoId=254&language=zh-CN' \
  -H 'Referer: https://support.ugnas.com/'

# 分类/筛选项（也就是知识中心的大纲，带每类文章数）
curl -s 'https://api.ugnas.com/api/system/knowledge_center/sa/base/category?language=zh-CN' \
  -H 'Referer: https://support.ugnas.com/'
```

几个坑：

- `language` 必须传 `zh-CN`，传 `zh_cn` 会返回空列表。
- 搜索是多词模糊匹配，别拿长句当关键词，两三个词就够。
- 同一篇在 PC / 手机 / TV 端各有一条结果（`articleInfoId` 相同），去重后才是真实篇数。
- 教程中心的 `/tutorial-detail/id-N.html` 是静态页，`curl` 下来就能读，不需要接口。

## 知识中心大纲

按场景（`domainOptions`，2026-11 抓取，括号内为文章数）：

| 场景 | 篇数 | 场景 | 篇数 |
| --- | --- | --- | --- |
| Docker玩法 | 34 | Docker工具类 | 26 |
| 文件服务 | 24 | 网络设置 | 24 |
| 存储管理 | 19 | 同步与备份 | 19 |
| 影视刮削 | 19 | 容器应用 | 18 |
| 账号与权限 | 16 | 新机使用指南 | 16 |
| 硬件与电源 | 13 | Docker娱乐类 | 12 |
| 连接与访问 | 10 | 快速入门指南 | 9 |
| 新手引导 | 7 | Docker笔记类 | 7 |
| SMB | 6 | 相册玩法 | 6 |
| 重置设备和密码 | 5 | RAID | 3 |
| UPS | 3 | 设备安全 | 3 |
| 格式支持 | 2 | Docker阅读类 | 1 |

按应用（`moduleOptions`，主要几个）：

| 应用 | 篇数 | 应用 | 篇数 |
| --- | --- | --- | --- |
| 控制面板 | 115 | Docker | 76 |
| 应用中心 | 62 | 存储管理 | 38 |
| 文件管理 | 35 | 影视中心 | 33 |
| 同步与备份 | 21 | 保险箱 | 18 |
| 虚拟机 | 17 | 相册 | 12 |
| SAN Manager | 12 | 网盘工具 | 10 |
| UGOS Pro 桌面 | 10 | 快照 | 7 |
| 音乐 | 5 | 任务管理器 / 全局搜索 | 2 / 2 |
| DLNA / 下载中心 | 2 / 2 | 安全管家 / 日志中心 / 文本编辑 / 在线文档 / 文件版本管理 | 各 1 |

按客户端：PC 460 条、手机/平板 138 条、TV 5 条。

## 教程中心大纲

「来源」维度：用户指南 125、应用教学 127、常见问题 123、产品使用手册 11、
产品介绍 7、功能原理 4、发行说明 1、开发人员指南 1、法律文件 1。

「系统」维度：UGOS Pro、UGOS。

「应用」维度（篇数）：控制面板 28、文件管理器 25、存储管理器 7、影视中心 7、
同步与备份 7、安全管家 5、相册 5、虚拟机 5、应用中心 4、下载中心 3、设备管理 3、
日志中心 2、任务管理器 2、DLNA 2、网络服务 2、全局搜索 1、文本编辑器 1、操作系统 1。

正文按来源 + 系统 + 应用三个条件过滤，24 页、约 144 篇。

## 常用文章直达

| 主题 | 链接 |
| --- | --- |
| 外部存储介绍（挂载、格式化、弹出、高级设置、支持格式） | <https://www.ugnas.com/tutorial-detail/id-164.html> |
| 外部存储管理（知识中心新版，含第三方系统盘只读/读写） | <https://support.ugnas.com/knowledgecenter/detail/article/zh-CN/254> |
| 设置普通用户对外部存储的访问权限 | <https://www.ugnas.com/tutorial-detail/id-19.html> |
| 共享文件夹权限使用说明（禁止访问/读写/只读、显性优先） | <https://www.ugnas.com/tutorial-detail/id-40.html> |
| 硬盘管理介绍 | <https://www.ugnas.com/tutorial-detail/id-165.html> |
| 硬盘管理和休眠设置 | <https://www.ugnas.com/tutorial-detail/id-222.html> |
| 创建存储池和存储空间 | <https://www.ugnas.com/tutorial-detail/id-166.html> |
| 存储空间如何选择文件系统（Btrfs vs ext4） | <https://support.ugnas.com/knowledgecenter/detail/article/zh-CN/662> |
| 共享文件夹只读/读写/禁止访问怎么设 | <https://www.ugnas.com/tutorial-detail/id-137.html> |
| 共享文件夹下单个子文件夹禁止访问 | <https://www.ugnas.com/tutorial-detail/id-138.html> |
| 共享文件夹 NFS 权限 | <https://www.ugnas.com/tutorial-detail/id-118.html> |
| SMB 设置教程 | <https://www.ugnas.com/tutorial-detail/id-199.html> |
| 文件服务概览与高级设置 | <https://www.ugnas.com/tutorial-detail/id-194.html> |
| 创建用户 / 用户组 | <https://www.ugnas.com/tutorial-detail/id-204.html> / <https://www.ugnas.com/tutorial-detail/id-196.html> |
| 终端机（SSH/Telnet） | <https://www.ugnas.com/tutorial-detail/id-190.html> |
| UGOS 切 UGOS Pro 后从外部存储找旧文件 | <https://www.ugnas.com/tutorial-detail/id-64.html> |
| Docker 的 PUID / PGID | <https://www.ugnas.com/tutorial-detail/id-228.html> |

## 本仓问答

- [绿联 NAS 插硬盘柜后的权限控制，以及 ext4 能不能直接插](./ugreen-nas-external-storage-permissions.md)

## 版本记录

- v1（2026-11-12）：初稿。整理官方帮助文档入口、抓取接口、知识中心与教程中心大纲、
  常用文章直达。使用模型 DeepSeek（deepseek-flash），本次会话约 308 万 tokens
  （含缓存读取 296 万，实际输入 8.2 万 / 输出 3.3 万）。
