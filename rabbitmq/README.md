**Xiang Wang @ 2019-08-30 15:27:30**

[Tutorials](https://www.rabbitmq.com/getstarted.html)

# [安装](https://www.rabbitmq.com/install-debian.html#managing-service)
* 启动服务
```
sudo systemctl start rabbitmq  # manjaro
sudo service rabbitmq-server start|stop  # ubuntu
sudo rabbitmq-diagnostics ping
sudo rabbitmq-diagnostics status
```
* 关闭服务
```
sudo rabbitmqctl stop
```
* change password  
````
rabbitmqctl change_password <username> <password>  # changepassword
rabbitmqctl set_permissions -p / rabbit ".*" ".*" ".*"  # allow access
````
* 查看当前消息队列
```
sudo rabbitmqctl  list_queues
```

# 链接
```
credentials = pika.PlainCredentials('wangx', 'wangxiangno')
connection = pika.BlockingConnection(pika.ConnectionParameters(credentials=credentials, virtual_host="qa1"))
```
# 发送消息
```
channel = connection.channel()
channel.queue_declare(queue="hello")
channel.basic_publish(exchange="", routing_key="hello", body=message)
```
# 接收消息
```
channel.start_consuming()
```

# [01-Hello-World](https://www.rabbitmq.com/tutorials/tutorial-one-python.html)
```
python hello_world_send.py
python hello_world_receive.py
python hello_world_send.py
python hello_world_send.py
```

# [02-Work-Queues](https://www.rabbitmq.com/tutorials/tutorial-two-python.html)
```
python work_queue_receive.py
python work_queue_receive.py
python work_queue_receive.py
python work_queue_send.py First message.
python work_queue_send.py Second message..
python work_queue_send.py Third message...
python work_queue_send.py Fourth message....
python work_queue_send.py Fifth message.....
```
## Round-robin dispatching
默认情况下`调用代码里的run1`, rabbitmq会使用round-robin轮寻处理. 每个work都会收到差不多一样多的消息

## Message acknowledgment
如果一个work处理了很久并且die了, 那么message都会消失
`调用代码里的run2`
* 如果不小心忘记添加basic_ack, 会导致message永远存在, rabbitmq会吃越来越多的内存.
```
rabbitmqctl list_queues name messages_ready messages_unacknowledged
```
`messages_ready`: 当前收到的消息(还没分发)数量
`messages_unacknowledged`: 当前收到的消息(已分发, 但是还没处理结束)的数量

## Message durability
```
channel.queue_declase(queue='task_queue', durable=True)
```
* 目前情况下所有的message, 在服务器重启后, 就会丢失. 为了使数据持久话, 我们需要创建queue的时候, 设定durable为True. 但是hello这个queue已经设定了非持久化, 不能更改了. 所以我们重新创建一个`task_queue`的持久话队列(`run3`)
* 为了使消息持久话, 我们在publish的时候,也要添加消息的持久话属性
```
channel.basic_publish(exchange='',
                      routing_key="task_queue",
                      body=message,
                      properties=pika.BasicProperties(
                         delivery_mode = 2, # make message persistent
                      ))
```
**注意这个durability并不是100%的, 也有可能rabbitmq server收到消息后, 还没来得及保存就断开了. 但是对于简单的项目来说仍然够用了. 如果你真的要做到100%的分发, 使用publisher confirms**

## Fair dispatch
目前的round-robin还不够智能, 可能造成一个worker一直很忙, 另外的worker一直很闲. 所以我们可以告诉rabbitmq, 不要把message发送给一个很忙的worker(`run4`)
```
channel.basic_qos(prefetch_count=1)  # 这一局一定要在basic_consume之前哦
channel.basic_consume(queue="task_queue", on_message_callback=callback)
```

## Production [Non-]Suitability Disclaimer
目前为止所有的代码还不能用在生产环境中, 为了简单而抛弃了很多东西. 如果要应用在生产环境, 请**务必**阅读剩下的文档. 
* [documentation](https://www.rabbitmq.com/documentation.html)
* [Consumer Acknowledgements and Publisher Confirms](https://www.rabbitmq.com/confirms.html)
* [Production Checklist](https://www.rabbitmq.com/production-checklist.html)
* [Monitoring](https://www.rabbitmq.com/monitoring.html)

# [ ] [Publish Subscribe](https://www.rabbitmq.com/tutorials/tutorial-three-python.html)

# Server Documentation
## rabbitmqctl  
[官网](https://www.rabbitmq.com/rabbitmqctl.8.html)

##  Replication

## 用户管理 User Management
* `add_user`
```
rabbitmqctl add_user <username> <passwd>
```
* [ ] `authenticate_user`

## Authorisation 权限管理 Access Control
[测试代码](./permission/)
* `set_permissions`
```
rabbitmqctl set_permissions --vhost <hostname>  <username> ".*" ".*" ".*" 最后三个是conf write read
```

## 虚拟主机
* `add_vhost`: 创建虚拟主机
```
rabbitmqctl add_vhost dynamic  # 不能用中文
```

## [ ] Configuration

## 其他

* `list_queues`  
展示queues
* `stop_app`
* `start_app`
* `reset`
清空所有的队列
```
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app
```
