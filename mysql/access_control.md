## [Access Control](https://dev.mysql.com/doc/refman/8.0/en/access-control.html)
### 用户管理
用户名字, 密码问题. 如何添加删除用户. 如果使用角色概念. 如何修改密码. 安全引导.

### User Names and Passwords 用户名和密码的使用

```bash
mysql --user=finley --password db_name
mysql -u finley -p db_name
mysql -u finley -ppassword db_name  # 不安全
```

### Adding User Accounts 添加用户
* 创建管理帐号
    * 案例


```sql
mysql> CREATE USER 'finley'@'localhost' IDENTIFIED BY 'password';
mysql> GRANT ALL PRIVILEGES ON *.* TO 'finley'@'localhost'
    ->     WITH GRANT OPTION;
mysql> CREATE USER 'finley'@'%' IDENTIFIED BY 'password';
mysql> GRANT ALL PRIVILEGES ON *.* TO 'finley'@'%'
    ->     WITH GRANT OPTION;
```

* 在开启匿名登录的情况下, 必须存在 'finley'@'localhost' 用户. 因为如果没有这条语句, 当用户本地匿名登录, 使用了finley当作username的话, 因为存在localhost, 就会被当作匿名用户来处理了 finley@localhost 优先判断成 '%'@'localhost' 而不是 'finley'@'%'.
* 'admin'@'localhost' 只能被本地的admin用户登录
* dummp用户只能被本地访问

* 查看用户权限  

```
mysql> SHOW GRANTS FOR 'admin'@'localhost';
     > Grants for admin@localhost
     > GRANT RELOAD, PROCESS ON *.* TO 'admin'@'localhost'
mysql> SHOW CREATE USER 'admin'@'localhost'\G
>> 1. row
CREATE USER for admin@localhost: CREATE USER 'admin'@'localhost'
IDENTIFIED WITH 'mysql_native_password'
AS '*67ACDEBDAB923990001F0FFB017EB8ED41861105'
REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK
```

* 创建普通帐号

    ```sql
    mysql> CREATE USER 'custom'@'localhost' IDENTIFIED BY 'password';
    mysql> GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP
        ->     ON bankaccount.*
        ->     TO 'custom'@'localhost';
    mysql> CREATE USER 'custom'@'host47.example.com' IDENTIFIED BY 'password';
    mysql> GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP
        ->     ON expenses.*
        ->     TO 'custom'@'host47.example.com';
    mysql> CREATE USER 'custom'@'%.example.com' IDENTIFIED BY 'password';
    mysql> GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP
        ->     ON customer.*
        ->     TO 'custom'@'%.example.com';
    ```

### [删除用户](https://dev.mysql.com/doc/refman/8.0/en/drop-user.html)
Removing User Accounts

    DROP USER 'jeffrey'@'localhost';
