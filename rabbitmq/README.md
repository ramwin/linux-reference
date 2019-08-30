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

