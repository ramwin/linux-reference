# markdown
```
前面3个` {include} file.md
```

* 测试引用  
我是引用  

```
ok
```

> 有些人活着,他已经死了

```
ok
```

>有些人活着,他已经死了.


* 测试链接

## 图片
![fishy](img/fun-fish.png)

## 列表
* 代办事项
代办事项不同于restructed的TODO, 它可以展示完成未完成的状态. restructed不支持这个特性

    * [ ] todo
    * [x] done

```{todo}
TODO
```

```{note}
TODO
```

## 图表
end是group里的end,不能随便用

### [流程图](https://mermaid.js.org/syntax/flowchart.html)

通过`:::`可以设置类， `(){},<>,>/,可以设置框外观`  
通过subgraph可以添加组
```{mermaid}
flowchart TB;
    Start --> check{校验是\n否橙色}
    Start ~~~ 隐藏的线
    check --> |是| orange:::orange
    check --> |否| red:::red
    red & orange --> tooltip --> End
    subgraph "tooltip"
        a --> b
        b --> c
    end
    classDef orange fill:#f96
    classDef red color: #f00
```

```{toctree}
./mermaid/flowchart.md
./mermaid/gant.md
./mermaid/usecase.md
```

## 稳定锚点: 防止外部链接失效 {#stable-anchor}

### 问题

很多渲染器默认按标题出现顺序生成锚点(`#id22` 这样)。文档里增删一个标题, 它后面的所有锚点重新编号, 指向它们的的外部链接全部失效。

三种锚点的稳定性对比:

| 锚点类型 | 例子 | 增删其他标题时 | 修改标题文字时 | 是否可控 |
|----------|------|----------------|----------------|----------|
| 顺序号 | `#id22` | 全部移位 | 侥幸不变 | 不可控 |
| 文本 slug | `#需求编号与优先级` | 稳定 | 失效 | 不可控 |
| 手工锚点 | `{#req-structure}` | 稳定 | 稳定 | 完全可控 |

### 方案一: 给被外链的标题手工指定锚点(最可靠)

MyST / Pandoc 语法, 本项目已启用 `attrs_inline`, 可直接用:

```markdown
## 需求编号与优先级 {#req-structure}
```

GFM(GitHub 等)不支持 `{#id}` 语法, 用内联 HTML, 几乎所有渲染器都会保留:

```markdown
<a id="req-structure"></a>
## 需求编号与优先级
```

规则: **对外只链接手工锚点, 自动生成的锚点永远不进入 URL**。

### 方案二: 锚点即接口, 发布后 immutable

- 手工锚点一旦发布, 不改名、不删除; 标题文字随便改, 锚点不动;
- 章节废弃时保留空占位 `<a id="old-anchor"></a>`, 而不是直接删掉;
- 新增锚点只加不改, 旧链接自然一直有效。

### 方案三: 渲染器能配就配成文本 slug 模式

- Sphinx/MyST: `myst_heading_anchors = 7`(本项目 conf.py 已配置), 锚点由标题文字生成, 与出现位置无关, 增删标题不再连锁失效; 手工 `{#id}` 优先级更高, 两者可共存;
- GitHub/GitLab 天然就是文本 slug;
- 如果发布平台强制 `#id22` 且提供配置, 找 slug / permalink 类的开关;
- 如果平台既强制顺序号、又剥离自定义 HTML 锚点, 锚点层面无解, 用方案四缓解。

### 方案四: 平台不可救时的缓解

- 外链尽量指向文件而不是标题: `doc.md` 比 `doc.md#id22` 活得久;
- 大文档拆小, 让"指向某小节"变成"指向某文件";
- 发布时用脚本导出"标题 → 锚点"映射, 外部链接由脚本批量生成, 编号变了也能整体重刷。

### 方案五: 内部链接自动化检查

外链的稳定性只能靠上面的"锚点契约"保证, 内部链接可以让工具把关:

- `sphinx-build -b linkcheck . _build/linkcheck` 检查外部 URL 可达性;
- MyST 对失效的内部锚点引用会发出 `myst.xref_missing` 警告——本项目 conf.py 里把它 suppress 了, 想启用检查就从 `suppress_warnings` 中移除。
