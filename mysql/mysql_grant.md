**Xiang Wang @ 2017-06-23 09:29:22**

* [官方参考](https://dev.mysql.com/doc/refman/8.0/en/)

## 基础

```
修改 /etc/mysql/mysql.conf.d/mysqld.cnf
设置 bind-address = 0.0.0.0
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'mypassword' WITH GRANT OPTION;  # 5.7
GRANT ALL ON *.* TO 'wangx'@'localhost' WITH GRANT OPTION;  # 8.0
```

* 查看权限
```sql
select * from SCHEMA_PRIVILEGES;
```
