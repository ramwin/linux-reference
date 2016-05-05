
# MySQL
## 查看用户的权限
    show grants for <username>;
## 开启数据库远程连接
    grant all PRIVILEGES on *.* To 'root'@'%' IDENTIFIED BY 'mypassword' WITH GRANT OPTION;
    flush privileges;

## 开启部分功能
    grant select, insert, on *.* to abc@www identified by 'we';

## 修改root密码
    mysqladmin -u root password lodpass "newpass"  
