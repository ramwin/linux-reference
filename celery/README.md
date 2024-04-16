# celery

## 基础
[官网](https://docs.celeryproject.org/en/stable/getting-started/introduction.html)

```
terminal1: cd test && celery -A tasks worker --loglevel=info --concurrency=1
terminal2: cd test && python3 test_tasks.py
```
* 只能支持可序列化的参数,不支持自定义class
* [测试代码](./测试内存/tasks.py) [测试脚本](./测试内存/test_tasks.py)
* 不需要启动多个celery, 因为celery本身就是多线程的. 并且里面的变量是共享的
* 如果启动了多个celery, 一个请求过去只有一个celery的里面一个线程会收到任务
* 默认启动了4个worker, 所以如果是4个以内的请求,耗时为一倍, 5个到8个耗时为2倍
* celery使用rabbitmq也会遇到一样的问题，是round-robin的.　需要配置`worker_prefetch_multiplier`
* 内存分析
    * 多线程对于大变量内存影响不大．所以celery应该是多个concurrency共享内存变量的

程序|线程|大内存变量|VIRT|RES|备注
----|----|---------------------------------|---|---|---
python|1|0|17884|9992|大型变量用list(range(100000))
python|1|1|21836(+3952)|14012(+4020)|和没有变量相比
python|1|2||
celery| 1|0|50428(+32544)|28988(+18996)|和python_1_0相比
celery| 2|0|52896(+2468) |37280(+8292)|和celery_1_0相比
celery| 4|0|52908(+2480) |37108(+8210)|和celery_1_0相比
celery| 8|0|52924(+2496) |37232(+8244)|和celery_1_0相比
celery|16|1|53220(+2792) |37212(+8824)|和celery_1_0相比
celery|1|1|57100(+6672)|41212(+12224)|和celery_1_0相比
celery|1|2|61172(+10744)|45084(+16096)|和celery_1_0相比
celery|4|1|52904|37248|和celery_1_0相比
celery|4|4|69228|53024|和celery_1_0相比


## 起步
### Choose a broker
不管你怎么设置，只要broker都是`amqp://guest@localhost//`, 那么他们在rabbitmq的queue都是celery。但是在celery启动的时候，会额外产生两个queue
```
Timeout: 60.0 seconds ...
Listing queues for vhost / ...
name    messages
celery@manjaro.celery.pidbox    0
celery  0
celeryev.76bb7ea5-4b5e-4c4b-9c8f-8179984fa8b6   0
```

## Config

* [logging](https://docs.celeryq.dev/en/stable/userguide/configuration.html#logging)

    * celery会关闭root的logger, 所以不能设置
