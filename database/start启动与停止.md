# MySQL启动停止
    /etc/init.d/mysql start|stop

# MySQL docker
## 启动
    docker run --name mysql -e MYSQL_ROOT_PASSWORD=wangxiang -p 3306:3306 -d mysql
## 进入
    docker exec -ti mysql /bin/bash
