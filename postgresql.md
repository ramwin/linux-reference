**Xiang Wang @ 2021-01-26 10:29:47**

### 基础
[安装](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-ubuntu-16-04)  

### Tutorial
1. [Getting Started](https://www.postgresql.org/docs/current/tutorial-start.html)
```
sudo apt install postgresql postgresql-contrib
sudo -i -u postgres
psql
sudo -u postgres psql
createuser --interactive
createdb [<databasename>] default name is the username
dropdb <databasename>
psql <databasename>
```

2. The SQL Language
    1. Introduction
    ```
    cd ..../src/tutorial
    make
    cd ..../toturial
    psql -s mydb
    mydb=> \i basics.sql
    ```
    3. [创建表](https://www.postgresql.org/docs/current/tutorial-table.html)
    ```
    CREATE TABLE weather (
        city    varchar(80),
        temp_lo int,
        temp_hi int,
        prcp    real,
        date    date
    )
    ```
3. Advanced Features
    2. Views
    ```
    CREATE VIEW myview AS SELECT city, temp_lo, temp_hi, location FROM weather, cities WHERE city = name;
    SELECT * FROM myview;
    ```

### The SQL Language
#### 数据定义
* 约束
    * check约束
    ```
    create table weather ( temp_lo int CHECK (temp_lo > 0) );
    ```
#### 数据类型
1. Numeric Types
    1. Integer Types

### [PostgreSQL Administration](https://www.postgresqltutorial.com/postgresql-administration/)
* [展示所有table](https://www.postgresqltutorial.com/postgresql-show-tables/)  `\dt`
* 展示所有数据库 `\l`

### 权限
* 允许用户创建表
```sql
ALTER USER <username> CREATEDB
```
