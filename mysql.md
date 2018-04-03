*Xiang Wang @ 2017-11-22 11:18:53*

# tutorial 命令大全
* `GRANT ALL ON <databasename>.* TO '<username>'@'<host>';`

* ## CREATE
    * 示例
    ```
        CREATE DATABASE menagerie;
        CREATE TABLE <tablename> (column, column);
        CREATE TABLE shop (
            article INT(4) UNSIGNED ZEROFILL DEFAULT '0000' NOT NULL,
            dealer  CHAR(20)                 DEFAULT ''     NOT NULL,
            price   DOUBLE(16,2)             DEFAULT '0.00' NOT NULL,
        )
    ```
    * 参考
        * DEFAULT: 默认值
        * NOT NULL: 不能为空
* `DESCRIBE <table>;`
* INSERT [官方参考](https://dev.mysql.com/doc/refman/5.7/en/insert.html)
    ```mysql
    INSERT INTO pet VALUES ('Puffball', 'Diane', 'hamster', 'f', '1999-03-30', NULL);
    ```
* [JOIN](https://dev.mysql.com/doc/refman/5.7/en/multiple-tables.html)
    * 案例
    ```
    SELECT pet.name TIMESTAMPDIFF(YEAR, birth, date) AS age, remark FROM pet INNER JOIN event ON pet.name = event.name WHERE event.type = 'litter';
    ```
    * INNER JOIN: *把两个表格里面合并起来，只有on的条件满足了才会一起出现，否则就不显示*
* LOAD [官方链接](https://dev.mysql.com/doc/refman/5.7/en/load-data.html)
    * `\N`代表了空置`NULL`
    * example:
    ```mysql
    LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet;
    LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet LINES TERMINATED BY '\r\n';
    ```
* mysql --help
* `mysql -h host -u user -p[passwoed] [<databasename>]`

* ## SELECT  
    * A条件 AND B条件 OR C条件, AND的优先级比较高，但是为了不弄混，还是加括号()比较好
    * DISTINCT是针对结果的。结果数据一致就算是一致
    * ORDER BY birth [DESC]; 对某个列进行排序
        * ORDER BY name 按照名字排序（不分大小写）
        * ORDER BY BINARY name 按照名字排序（区分大小写）
        * ORDER BY name, birth DESC; 按照几个字段排序
    * NULL 的查询
        * SELECT name FROM pet WHERE death is null;
    * ### [正则查询](https://dev.mysql.com/doc/refman/5.7/en/pattern-matching.html), 默认不区分大小写
        * `SELECT name FROM pet WHERE name like 'b%'`: b开头
        * `SELECT name FROM pet WHERE name like '_____'`: 5个字母
        * `SELECT name FROM pet WHERE name REGEXP/RLIKE '^b'`: b开头
        * '%fy': fy结尾
        * '%w%': 包含w
        * '_': 一个任意字符
        * 区分大小写: `SELECT name FROM pet WHERE name like binary '%w'`;
        * `.`: 匹配任意单个字符串
        * `[abc]`: abc中任意一个
        * `*`: 任意数量
        * `{5}`: 指定5个
        * [...to be continued](https://dev.mysql.com/doc/refman/5.7/en/regexp.html)
    * COUNT:  
        `COUNT(*)` 求和。 `COUNT(field)` 会排除field为null的数据
        如果 `SET sql_mode = 'ONLY_FULL_GROUP_BY'` 那COUNT后面必须有group by, 如果 `SET sql_mode = ''` 那COUNT后面可以没有group by
    * 示例
    ```mysql
    SELECT [DISTINCT] field FROM table WHERE conditions_to_satisfy ORDER BY column [DESC];
    ```
    * ### 用户自定义变量:
    ```
        select @min_price:=MIN(price) from shop;
        select @min_price;
        select * FROM shop WHERE price=@min_price;
    ```
    * ### 使用外键
    ```
    CREATE TABLE shirt (
        id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
        style ENUM('t-shirt', 'polo', 'dress') NOT NULL,
        color ENUM('red', 'blue', 'orange', 'white', 'black') NOT NULL,
        owner SMALLINT UNSIGNED NOT NULL REFERENCES person(id),
        PRIMARY KEY (id)
    );
    ```

* ## SHOW
    * SHOW DATABASES;
    * SHOW TABLES;
    * SHOW CREATE TABLE pet;
    * SHOW INDEX FROM pet;
    * SHOW CREATE TABLE pet\G;  # \G 可以让代码变整洁，具体意思以后再看
* ## UPDATE
    ```mysql
    UPDATE pet SET birth = '1989-08-31' WHERE name = 'Bowser';
    ```
* ## USE <databasename>
* ## batch
    ```
    mysql < batch-file > outfile
    ```


# tutorial 函数大全
* 普通函数
    * `CURDATE`: 当前日期
    * `CURRENT_DATE`: 当前日期
    * `CURRENT_TIME`: 当前时间（不带日期）
    * `DATABASE()`: 当前数据库
    * `DATE_ADD(CURDATE(), INTERVAL 1 MONTH)`: 返回下个月的今天。1月29, 30, 31的结果都一样
    * `DAYOFMONTH`: 返回日期
    * `LAST_INSERT_ID`: 最后一次插入的数据
    * `MAX(column)`: 最大值
    * `MOD(MONTH(CURDATE()), 12) + 1`: MOD去模，用来返回下个月的月份
    * `MONTH`: 返回月份
    * `NOW()`: 当前时间
    * `TIMESTAMPDIFF(YEAR, birth, CURDATE())`: 年份。直接比较时间戳去尾，如果跨过了闰年的2月29号，就要和366天比，否则和365天比
    * `USER()`: 当前用户
    * `VERSION()`: 查看版本

* 不常用函数
    * `BIT_OR`: 
* 数学函数
    * `PI()`: 3.141592
    * `SIN`: sin三角函数


# [Data Types 数据类型](https://dev.mysql.com/doc/refman/5.7/en/data-types.html)
## [Data Type Overview]()
## [数字类型]()
    * 基础: INT(2)
    * 可用参数: `UNSIGNED, ZEROFILL, AUTO_INCREMENT`
    * `ALTER TABLE tb1 AUTO_INCREMENT = 100;`  # 不是自动加1,而是自动加100
    * YEAR(4)
## [时间和日期]()
## [字符串类型]()
## [Spatial Data Types空间类型](https://dev.mysql.com/doc/refman/5.7/en/spatial-types.html)
* [创建空间类型列](https://dev.mysql.com/doc/refman/5.7/en/creating-spatial-columns.html)
```mysql
    CREATE TABLE geom (g GEOMETRY);
```
* [获取空间数据](https://dev.mysql.com/doc/refman/5.7/en/fetching-spatial-data.html)
```mysql
    SELECT ST_AsText(g) from geom;
    > | POINT(1 1) |
    SELECT ST_AsBinary(g) from geom;
    > | 010010000 |
```
* [...to be continued]()
## [...to be continued]()


# 过滤
* 基础: `WHERE species = 'dog'`
* `IN`: `SELECT * FROM pet WHERE species IN ('dog', 'cat');`

# 备份与恢复
## mysqldump
* 示例代码
```
mysqldump -u root -p test --extended-insert=FALSE > test.sql
mysqldump -u root -p test --extended-insert=FALSE --result-file=test.sql
```
* 选项
    * `--extended-insert`: 是否把所有数据的insert写成一句，默认True
    * `--complete-insert`: insert语句里面是否带上columns的参数，默认False

# 有待整理
* [file backup restore 和文件相关的操作](./database/file脚本数据交互.md)
* [data 基础操作](./database/data.md)
* [和数据库, 表有关的操作](./database/table表和数据库.md)
