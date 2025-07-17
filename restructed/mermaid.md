# 测试mermaid

## 顺序图
```{mermaid}
sequenceDiagram
    participant A as Alice<br/>[复杂的名字]
    A->>John: Hello John, how are you?
    John-->>A: Great!
    A-)John: See you later!
```

## 流程图
通过`:::`可以设置类， `(){},<>,>/,可以设置框外观`  
通过subgraph可以添加组
```{mermaid}
flowchart TB;
%%{init: {'flowchart' : {'curve' : "basis"}, 'theme': 'dark'}}%%
    Start --> check{校验是\n否橙色}
    Start --> 箭头 --> End
    Start --- 连线 --- End
    Start ==> 加粗箭头 ==> End
    Start -- 纯文字 --- 加框 --- End
    箭头 ~~~ 隐藏线用来给箭头备注 ~~~ 箭头
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

## 甘特图
```{mermaid}
%%{init: {'gantt': {'displayMode': 'compact'}}}%%
gantt
    dateFormat  YYYY-MM-DD
    title       Adding GANTT diagram functionality to mermaid
    excludes    weekends
    %% (`excludes` accepts specific dates in YYYY-MM-DD format, days of the week ("sunday") or "weekends", but not the word "weekdays".)

    section A section
    Completed task            :done,    des1, 2014-01-06,2014-01-08
    Active task               :active,  des2, 2014-01-09, 3d
    Future task               :         des3, after des2, 5d
    Future task2              :         des4, after des3, 5d

    section Critical tasks
    Completed task in the critical line :crit, done, 2014-01-06,24h
    Implement parser and jison          :crit, done, after des1, 2d
    Create tests for parser             :crit, active, 3d
    Future task in critical line        :crit, 5d
    Create tests for renderer           :2d
    Add to mermaid                      :until isadded
    Functionality added                 :milestone, isadded, 2014-01-25, 0d

    section Documentation
    Describe gantt syntax               :active, a1, after des1, 3d
    Add gantt diagram to demo page      :after a1  , 20h
    Add another diagram to demo page    :doc1, after a1  , 48h

    section Last section
    Describe gantt syntax               :after doc1, 3d
    Add gantt diagram to demo page      :20h
    Add another diagram to demo page    :48h

```
