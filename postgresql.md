# postgresql
## 基础
[安装](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-ubuntu-16-04)  

## [Tutorial](https://www.postgresql.org/docs/current/tutorial.html)
### [1. Getting Started](https://www.postgresql.org/docs/current/tutorial-start.html)
```shell
sudo apt install postgresql postgresql-contrib
sudo -i -u postgres
psql
sudo -u postgres psql
createuser --interactive
createdb [<databasename>] default name is the username
dropdb <databasename>
psql <databasename>
```

#### 内置函数
* version
```sql
SELECT version(), current_date, 2+2;
```

### 2. The SQL Language
1. Introduction
```
cd ..../src/tutorial
make
cd ..../toturial
psql -s mydb
mydb=> \i basics.sql
```
### 2.3 [创建表](https://www.postgresql.org/docs/current/tutorial-table.html)
```
CREATE TABLE weather (
    city    varchar(80),
    temp_lo int,  -- 后面是注释
    temp_hi int,
    prcp    real,
    date    date
)
```

### 2.4 插入数据
```sql
INSERT INTO cities VALUES ('San Francisco', '(-194.0, 53.0)');  /* 一定要用单引号 */
INSERT INTO weather (city, temp_lo, temp_hi, prcp, date)
    VALUES ('San Francisco', 43, 57, 0.0, '1994-11-29');

COPY weather FROM '/home/user/weather.txt';
```

### 2.5 查询表
```SQL
SELECT city, (temp_hi+temp_lo)/2 AS temp_avg, date FROM weather;
```

### 2.7 Aggregate Functions 聚合数据
```SQL
SELECT max(temp_lo) FROM weather;
SELECT city FROM weather WHERE temp_lo = max(temp_lo);     WRONG, where里面不能用聚合属性
SELECT city FROM weather
    WHERE temp_lo = (SELECT max(temp_lo) FROM weather);
```

### 2.8 更新表
```SQL
UPDATE weather
  SET temp_hi = temp_hi - 2, temp_lo = temp_lo - 2
  WHERE date>'1994-11-28';
```

### 3.2 Advanced Features -- Views
```SQL
CREATE VIEW myview AS SELECT city, temp_lo, temp_hi, location FROM weather, cities WHERE city = name;
SELECT * FROM myview;
```

### 3.3 外键
```
CREATE TABLE cities (
    name varchar(80) primary key,
    location point
);
CREATE TABLE weather (
    city varchar(80) reference cities(name),
);
```

## The SQL Language
### 数据定义 Data 
* 约束
    * check约束
    ```
    create table weather ( temp_lo int CHECK (temp_lo > 0) );
    ```

### [5.7 Privileges 权限](https://www.postgresql.org/docs/current/ddl-priv.html)
* 更改表的权限
```sql
ALTER TABLE <table_name> OWNER TO <role_name>;  /* 变更表，数据库的owner*/
GRANT SELECT ON <table_name> TO <role_name>;  /* 允许某个用户查询某个表 */
REVOKE ALL ON role2_s_table FROM wangx;  /* 不允许wangx操作role2_s_table */
REVOKE DELETE ON <table_name> TO <role_name>;  /* 删除用户的DELETE权限 */
```
* 查看表的权限
r是select权限
a是insert权限
w是update权限
d是delete权限
```
\dp role2_s_table;
wangx=# \dp role2_s_table;
                                   存取权限 架构模式 |     名称      |  类型  |         存取权限          | 列特权 | 策略
----------+---------------+--------+---------------------------+--------+------
 public   | role2_s_table | 数据表 | postgres=arwdDxt/postgres+|        |
          |               |        | noper=r/postgres          |        |
```

### 数据类型
1. Numeric Types
    1. Integer Types

* point 位置坐标
```
CREATE TABLE cities (
    name            varchar(80),
    location        point
);
INSERT INTO cities VALUES (
    'San Francisco', '(-194.0, 53.0)');
```

## Sever Administration 服务器管理

* [查看当前连接数](https://stackoverflow.com/questions/27435839/how-to-list-active-connections-on-postgresql):
```
select datname from pg_stat_activity;
```

* [查看各个表的尺寸](https://stackoverflow.com/questions/21738408/postgresql-list-and-order-tables-by-size)
```
select
  table_name,
  pg_size_pretty(pg_total_relation_size(quote_ident(table_name))),
  pg_total_relation_size(quote_ident(table_name))
from information_schema.tables
where table_schema = 'public'
order by 3 desc;
```

#### basic
* 修改用户密码
```sql
ALTER USER user_name WITH PASSWORD 'new_password';
```

* 允许用户查询某个数据表
```sql
GRANT CONNECT ON DATABASE <db> TO <role>;
GRANT USAGE ON SCHEMA public TO <role>;
GRANT SELECT ON ALL TABLES IN SCHEMA public to <role>;
```

### Database Roles
```sql
CREATE ROLE <name>;
DROP ROLE <name>;
SELECT rolname FROM pg_roles;
```

### Back Up and Restore

#### 数据库导出
```
pg_dump \
    --host localhost \
    --no-owner \
    --if-exists \
    --no-acl \
    --schema-only \
    --table some \
    --exclude-schema=\
    -f <outputfie>.sql
    <dbname>
```

## [PostgreSQL Administration](https://www.postgresqltutorial.com/postgresql-administration/)
* [展示所有table](https://www.postgresqltutorial.com/postgresql-show-tables/)  `\dt`
* 展示单个表
```shell
\d+ users
```

* 展示所有数据库 `\l`
* 执行sql语句
```
\i lesson1.sql
```

* 展示所有连接
```
select usename, client_addr from pg_stat_activity;
SHOW max_connections;
```

### 权限
* 允许用户创建表
```sql
ALTER USER <username> CREATEDB
```

## Reference

### [ALTER USER](https://www.postgresql.org/docs/current/sql-alteruser.html)
```sql
CREATE USER <username> WITH PASSWORD '密码';
ALTER USER <username> WITH PASSWORD '新密码';
```

### [ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html)
```sql
ALTER TABLE students ALTER age integer;
ALTER TABLE students DROP age;
```

### CREATE DATABASE
```
CREATE DATABASE people WITH OWERN 'pg4e';
```

### [Create Table 创建表](https://www.postgresql.org/docs/current/sql-createtable.html)
* 添加自增主键
```sql
create table students (
    id integer primary key generated by default as identity,
    name char(3)
);
insert into students values (default, '1');  /* 1 */
insert into students values (2, '1');
insert into students values (default, '1');  /* 报错, 因为2存在了 */
```

### PostgreSQL Client Applications - PSQL命令工具
[官网](https://www.postgresql.org/docs/current/app-psql.html)
* `\h`查看SQL帮助
* `\?`查看命令相关帮助
* `\q`退出
* `\dt` 查看所有的数据表
* `\dS+ <tablename>` 查看某个数据表
* `\timing` 显示语句执行时间
* `\r` 重置输入的内容

## 配置
* 允许远程登录
1. 编辑postgresq.conf
```
listen_addresses = '*'  # 或者改成IP地址
```
2. 编辑pg_hba.conf
```
host    <数据库>     <用户>             <fromIP>/32                 scram-sha-256
```
3. 刷新登录权限
```sql
select pg_reload_conf();  /* 执行这个语句更新登录权限 */
```

## 多数据库管理
### TableSpaces
```sql
-- 利用额外的硬盘创建tablespace空间
CREATE TABLESPACE table_03 LOCATION '/ssd1/postgresql/data';
-- create database table
create database db_02 TABLESPACE=tablespace_02;
```
