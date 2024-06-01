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
```{mermaid}
graph LR;
    Start --> process --> End
```
