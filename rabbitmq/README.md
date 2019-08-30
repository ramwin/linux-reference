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
* change password  
````
rabbitmqctl change_password <username> <password>  # changepassword
rabbitmqctl set_permissions -p / rabbit ".*" ".*" ".*"  # allow access
````
* 查看当前消息队列
```
sudo rabbitmqctl  list_queues
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
默认情况下, rabbitmq会使用round-robin轮寻处理. 每个work都会收到差不多一样多的消息

## Message acknowledgment
如果一个work处理了很久并且die了, 那么message都会消失
