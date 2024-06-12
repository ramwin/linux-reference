# markdown

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
    Start --> check{校验是\n否橙色} --> |是| orange:::orange
    check --> |否| red:::red
    red & orange --> group --> End
    subgraph group "tooltip"
        a --> b
        b --> c
    end
    classDef orange fill:#f96
    classDef red color: #f00
```
