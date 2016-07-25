#### Xiang Wang @ 2016-07-18 10:03:16

* ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock' (2)
    1. 重启mysql服务，这是因为/var/run/mysql/mysqld.sock文件被删除了，重启mysql的话会重新创建这个文件
