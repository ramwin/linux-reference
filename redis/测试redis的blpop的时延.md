### 测试redis的blpop的时延

#### 方案
一个进程, 不断地给list push进程的时间
另外一个进程, 不断地pop. 并对比当前时间和pop出的时间.

#### 脚本
```{literalinclude} ./测试redis的blpop的时延.py
```

#### 结论
* 本地使用redis的blpop, rpush需要144us
* 直接用list
