[参考](http://www.cnblogs.com/itech/archive/2011/02/09/1950226.html)

# crontab
定时任务脚本, 默认路径就是`~`. 所以可以直接运行home下的文件, 也可以用`~`

## 基础语法
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

## 日志重定向
```
// 不输出日志, mail, 日志文件都没有
* * * * * python3 test.py 1>/dev/null 2>&1
// 都输出到logpath
把日志输出到 logpath, 如果报错了(状态为2)有错误日志, 等同于输出到1. mail永远无数据
* * * * * python3 /home/wangx/test1.py >>logpath 2>&1
// 错误日志输出, 正确的日志还是默认用mail
* * * * * python3 ~/test2.py 2>>logpath
```

## 启动时自动运行
```
@reboot <command>
```
