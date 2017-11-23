#### Xiang Wang @ 2017-11-22 11:18:53

### 命令大全
* `GRANT ALL ON <databasename>.* TO '<username>'@'<host>';`
* `CREATE DATABASE menagerie;`
* `CREATE TABLE <tablename> (column, column);`
* `DESCRIBE <table>;`
* INSERT [官方参考](https://dev.mysql.com/doc/refman/5.7/en/insert.html)
    ```mysql
    INSERT INTO pet VALUES ('Puffball', 'Diane', 'hamster', 'f', '1999-03-30', NULL);
    ```
* LOAD [官方链接](https://dev.mysql.com/doc/refman/5.7/en/load-data.html)
    * `\N`代表了空置`NULL`
    * example:
    ```mysql
    LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet;
    LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet LINES TERMINATED BY '\r\n';
    ```
* mysql --help
* `mysql -h host -u user -p[passwoed] [<databasename>]`
* SELECT  
    * A条件 AND B条件 OR C条件, AND的优先级比较高，但是为了不弄混，还是加括号()比较好
    * DISTINCT是针对结果的。结果数据一致就算是一致
    ```mysql
    SELECT [DISTINCT] what_to_select FROM which_table WHERE conditions_to_satisfy ORDER BY which_column;
    ```
* SHOW DATABASES; SHOW TABLES;
* UPDATE
    ```mysql
    UPDATE pet SET birth = '1989-08-31' WHERE name = 'Bowser';
    ```
* USE <databasename>


### 函数大全
* 普通函数
    * `CURRENT_DATE`: 当前日期
    * `CURRENT_TIME`: 当前时间（不带日期）
    * `DATABASE()`: 当前数据库
    * `NOW()`: 当前时间
    * `USER()`: 当前用户
    * `VERSION()`: 查看版本

* 数学函数
    * `PI()`: 3.141592
    * `SIN`: sin三角函数


### 数据类型
* [官方参考](https://dev.mysql.com/doc/refman/5.7/en/data-types.html)


### 过滤
* 基础: `WHERE species = 'dog'`
* `IN`: `SELECT * FROM pet WHERE species IN ('dog', 'cat');`
