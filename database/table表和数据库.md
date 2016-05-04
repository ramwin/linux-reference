# sqlite
创建数据库
    sqlite3 test.db
创建表
    CREATE TABLE "dbxd" (
    "id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, 
    "time" datetime NOT NULL, 
    "contentid" varchar(32) NOT NULL,
    "charge1" integer NOT NULL, 
    "channel" varchar(32) NOT NULL);

# Mysql
创建数据库
    create database scrapy character set utf8;
创建表
    create table user (
        id SMALLINT unsigned not null auto_increment primary key,
        name VARCHAR(50) comment '用户名',  # comment来写注释)
删除表
    drop table <tablename>;
查看表
    show full columns from user;
