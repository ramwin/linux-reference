[参考](http://www.cnblogs.com/itech/archive/2011/02/09/1950226.html)

```
# /etc/crontab
# m h dom mon dow user command
* * * * * root wangx.sh
# 分钟 小时 天 月 星期 以什么用户 执行什么代码
*   代表了任意的数字
/n  每5个单位
a-b 从a单位到b单位
a,b,c a,b,c的时候执行
/10 这样的话会怎么样

# 本来也3分钟一次的，我在运行以后改成7分钟一次
# 结果在 00 07 14 21 28 35 42 49 56 运行了，之后又是00的时候运行了

# 我写成每10分钟运行一次
```
