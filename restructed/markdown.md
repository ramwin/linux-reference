# markdown
```{contents}
```

```{include} ./echarts.html
```

```{toctree}
./table.md
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
```{toctree}
./mermaid.md
```
end是group里的end,不能随便用


## 列表待办列表
- [ ] 未处理
- [x] 已处理
