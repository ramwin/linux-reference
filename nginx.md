*Xiang Wang @ 2017-03-14 14:10:44*

## 安装
* [下载](http://nginx.org/)
* [编译](http://nginx.org/en/docs/configure.html)

## 为什么这么快
为什么快，我觉得nginx可以什么都不处理啊。仅仅是一个路由器，能不快吗
* [多进程+异步非阻塞IO事件模型](https://www.jianshu.com/p/6215e5d24553)
* [一个请求只由一个worker进程来处理](https://zhuanlan.zhihu.com/p/108031600)
* 每个worker又都是异步的, IO 多路复用
