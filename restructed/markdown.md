# markdown
```{contents}
```

```{toctree}
./mermaid.md
```

## include

1. include代码
使用
```
`` `
{literalinclude} ./be_include.py
`` `
```
可以把代码展示出来

```{literalinclude} ./be_include.py
```

2. include markdown文件, 这样会导致层级比较大,注意被include的文件要比较小哦
```{include} ./be_include.md
```

## 图片
当前目录下可以直接用`![](./fish.png)`

![](./fish.png){w=890px}  
![](../test.png)[width=30]  
![](../test.png){width=10}

## 文字格式
```{note}
我是笔记
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
%%{init: {'flowchart' : {'curve' : "basis"}}}%%
    Start --> check{校验是\n否橙色}
    Start ~~~ 隐藏的线
    check --> |是| orange:::orange
    check --> |否| red:::red
    red & orange --> tooltip --> End
    tooltip --> bigblock4:::big
    subgraph "tooltip"
        a --> b
        b --> c
        c --> d@{ shape: tag-rect, label: "Tagged process"}
    end
    classDef orange fill:#f96
    classDef big fontsize:100
    classDef red color: #f00
    classDef orange,big,red font-size:12pt;
```


## 列表待办列表
- [ ] 未处理
- [x] 已处理
