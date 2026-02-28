# 甘特图

* 设置主题, 可以

```{mermaid}
---
title: Frontmatter Example
---
%%{init: {'theme': 'forest'}}%%
gantt
    section Waffle
        Iron  : 1982, 3y
        House : 1986, 3y
```

* 使用gantt内的设置字体, 可以

```{mermaid}
---
title: Frontmatter Example
---
%%{init: {'theme': 'forest', 'gantt': {'fontSize': '40'}}}%%
gantt
    section Waffle
        Iron  : 1982, 3y
        House : 1986, 3y
```

* 使用init内的设置字体, 不行

```{mermaid}
---
title: Frontmatter Example
---
%%{init: {'theme': 'forest', 'fontSize': 40}}%%
gantt
    section Waffle
        Iron  : 1982, 3y
        House : 1986, 3y
```
