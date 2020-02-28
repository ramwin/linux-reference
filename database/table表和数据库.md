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
## 删除字段
    alter table <table> drop <column>
