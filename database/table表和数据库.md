# sqlite
## 查看表的详细信息
    .schema <table>
## 创建数据库
    sqlite3 test.db
## 创建表
    CREATE TABLE "dbxd" (
    "id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, 
    "time" datetime NOT NULL, 
    "contentid" varchar(32) NOT NULL,
    "charge1" integer NOT NULL, 
    "channel" varchar(32) NOT NULL);  

## 导入其他的数据库
```
    attach "filename" as <dbname>;
```


# Mysql
## 创建数据库  
    create database scrapy character set utf8;
## 创建表  
**表的名称绝对不能有引号**  
_最后一行千万不要有逗号_  

    create table user ( 
        id SMALLINT unsigned not null auto_increment primary key,
        name VARCHAR(50) comment '用户名',  -- comment来写注释
        )
## 删除表
    drop table <table>; --表整个删除
    delete from table;  -- 保留表的结构
## 重命名表
    alter table <table> rename <table2>
## 查看表
    desribe <tablename>;
    show full columns from user;
## 插入字段
    alter table <table> add <column> <data-type> [after <column>]
## 删除字段
    alter table <table> drop <column>
