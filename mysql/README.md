*Xiang Wang @ 2017-11-22 11:18:53*

[官方文档](https://dev.mysql.com/doc/refman/8.0/en/)

# 启动
```
docker run -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -ti mysql
```

# tutorial 命令大全
* `GRANT ALL ON <databasename>.* TO '<username>'@'<host>';`

* ## CREATE
**表的名称绝对不能有引号**  
_最后一行千万不要有逗号_  
    * 示例
    ```
        CREATE DATABASE menagerie character set utf8mb4;
        CREATE TABLE <tablename> (column, column);
        create table user ( 
            id SMALLINT unsigned not null auto_increment primary key,
            name VARCHAR(50) comment '用户名',  -- comment来写注释
            )
        CREATE TABLE shop (
            article INT(4) UNSIGNED ZEROFILL DEFAULT '0000' NOT NULL,
            dealer  CHAR(20)                 DEFAULT ''     NOT NULL,
            price   DOUBLE(16,2)             DEFAULT '0.00' NOT NULL,
            `title` varchar(31) COLLATE utf8mb4_unicode_ci NOT NULL
        )
    ```
    * 参考
        * DEFAULT: 默认值
        * NOT NULL: 不能为空
        * COLLATE: 编码

## Drop
```
    drop table <table>; --表整个删除
    delete from table;  -- 保留表的结构
```

## DESCRIBE
`DESCRIBE <table>;`
* INSERT [官方参考](https://dev.mysql.com/doc/refman/8.0/en/insert.html)
```mysql
INSERT INTO pet VALUES ('Puffball', 'Diane', 'hamster', 'f', '1999-03-30', NULL);
INSERT INTO pet VALUES ('Puffball', 'Diane'), ('Puffball', 'Diane')  # 一次新插入多个数据
```
    * insert最后一个数据后面不能加逗号
* mysql --help
* `mysql -h host -u user -p[passwoed] [<databasename>]`

## SELECT  

* A条件 AND B条件 OR C条件, AND的优先级比较高，但是为了不弄混，还是加括号()比较好
* DISTINCT是针对结果的。结果数据一致就算是一致
* ORDER BY birth [DESC]; 对某个列进行排序
    * ORDER BY name 按照名字排序（不分大小写）
    * ORDER BY BINARY name 按照名字排序（区分大小写）
    * ORDER BY name, birth DESC; 按照几个字段排序
* NULL 的查询
    * SELECT name FROM pet WHERE death is null;
### [正则查询](https://dev.mysql.com/doc/refman/8.0/en/pattern-matching.html), 默认不区分大小写
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
* [...to be continued](https://dev.mysql.com/doc/refman/8.0/en/regexp.html)


### COUNT:  
`COUNT(*)` 求和。 `COUNT(field)` 会排除field为null的数据  
如果 `SET sql_mode = 'ONLY_FULL_GROUP_BY'` 那COUNT后面必须有group by, 如果 `SET sql_mode = ''` 那COUNT后面可以没有group by  


    SELECT [DISTINCT] field FROM table WHERE conditions_to_satisfy ORDER BY column [DESC];


### 用户自定义变量:


    select @min_price:=MIN(price) from shop;
    select @min_price;
    select * FROM shop WHERE price=@min_price;

### 使用外键


    CREATE TABLE shirt (
        id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
        style ENUM('t-shirt', 'polo', 'dress') NOT NULL,
        color ENUM('red', 'blue', 'orange', 'white', 'black') NOT NULL,
        owner SMALLINT UNSIGNED NOT NULL REFERENCES person(id),
        PRIMARY KEY (id)
    );

## SHOW
* SHOW DATABASES;
* SHOW TABLES;
* SHOW CREATE TABLE pet;
* SHOW INDEX FROM pet;
* SHOW CREATE TABLE pet\G;  # \G 可以让代码变整洁，具体意思以后再看
* `show full columns from group_group`; 查看所有的信息

## [UPDATE 更新数据](https://dev.mysql.com/doc/refman/8.0/en/update.html)
```mysql
UPDATE pet SET birth = '1989-08-31' WHERE name = 'Bowser';
```
## USE <databasename>
## batch


    mysql < batch-file > outfile

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

# Installing and Upgrading MySQL
### Postinstallation Setup and Testing
* Securing the Initial MySQL Account
```
mysql> ALTER USER 'root@localhost' IDENTIFIED BY 'new_password';
```

# Tutorial
## Creating and Using a Database
* [Loading Data into a Table](https://dev.mysql.com/doc/refman/8.0/en/loading-tables.html)
见SQL Statements - Data Manipulation Statements - LOAD DATA Statement

# SQL Statements
## Data Definition Statements
### CREATE TABLE Statements
#### [ ] [FOREIGN KEY Constraints](https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html)
* 示例

```sql
CREATE TABLE child (
    id INT,
    parent_id INT,
    INDEX par_ind (parent_id),
    FOREIGN KEY (parent_id)
        REFERENCES parent(id)
        ON DELETE CASCADE
)
```

* reference的字段，必须需要index
* 如果外键的字段有重复。只要里面一条数据被删除了，那么整个表里面的关联数据都会被删除。
#### [ ] [CHECK Constraints](https://dev.mysql.com/doc/refman/8.0/en/create-table-check-constraints.html)
```
[CONSTRAINT [symbol]] CHECK (expr) [[NOT] ENFORCED]
CREATE TABLE t1
(
  CHECK (c1 <> c2),
  c1 INT CHECK (c1 > 10),
  c2 INT CONSTRAINT c2_positive CHECK (c2 > 0),
  c3 INT CHECK (c3 < 100),
  CONSTRAINT c1_nonzero CHECK (c1 <> 0),
  CHECK (c1 > c3)
);
CREATE TABLE people (
  id int,
  birth date,
  death date,
  CONSTRAINT mycheck CHECK(death > birth)
);
```

## Data Manipulation Statements
* [ ] [DELETE](https://dev.mysql.com/doc/refman/8.0/en/delete.html)
```
DELETE FROM tbl_name 
    WHERE where_condition
    ORDER BY ...
    LIMIT row_count
```
* [LOAD DATA Statement](https://dev.mysql.com/doc/refman/8.0/en/load-data.html)
    * 例子


        LOAD DATA
            INFILE 'file_name'
            INTO TABLE tbl_name
            FIELDS TERMINATED BY ','
            ENCLOSED BY """
            IGNORE number {LINES | ROWS}

    * `\N`代表了空置`NULL`
    * example:


        LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet;
        LOAD DATA LOCAL INFILE '/path/pet.txt' INTO TABLE pet LINES TERMINATED BY '\r\n';

### SELECT Statement

* [basic 基础](https://dev.mysql.com/doc/refman/8.0/en/select.html)
* [SELECT ... INTO STATEMENT 导出数据](https://dev.mysql.com/doc/refman/8.0/en/select-into.html)

* [JOIN](https://dev.mysql.com/doc/refman/8.0/en/join.html)
    * LEFT JOIN

        ```
        SELECT * from pet LEFT JOIN event ON pet.name = event.name;
        找出每个动物。存在事件就插进去。最多可能pet的行数 x event的行数  
        ```

    * RIGHT JOIN

        ```
        SELECT * FROM pet RIGHT JOIN event ON pet.name = event.name;
        找出所有的事件，如果有对应的动物，就插进去。如果对应多个，就插入多个。所以最多的行数等于pet的行数 x event的行数
        ```

    * INNER JOIN

        ```
        SELECT * FROM pet INNER JOIN event ON pet.name = event.name;
        找出所有的匹配，然后只看里面pet.name == event.name. 如果没匹配上，就不显示。所以最多显示的数量是 pet的数量 × event的数量
        ```

    * 案例

        ```
        SELECT pet.name TIMESTAMPDIFF(YEAR, birth, date) AS age, remark FROM pet INNER JOIN event ON pet.name = event.name WHERE event.type = 'litter';
        ```

    * INNER JOIN: *把两个表格里面合并起来，只有on的条件满足了才会一起出现，否则就不显示*


* [ ] UNION Clause


# Security 安全机制

## General Security Issues 基本安全 [官网](https://dev.mysql.com/doc/refman/8.0/en/general-security-issues.html)


1. Security Guidelines
    * 不要给任何用户(除了root)拥有`user`表的权限
    * 学习 MySQL Access Privilege System, 使用 GRANT 和 REVODE来下发权限, 不要给更多的权限. 不要把权限给所有的hosts
    * 不要保存明文密码, 使用SHA2或者其他方法保存密码到数据库, 防止别人用彩虹表, 所以要hash加盐再hash
    * 密码不要用word, 因为有break passwords的programs(我都是用python随机生成的)
    * 使用防火墙, 把mysql放在demilitarized zone(DMZ) `telnet server_host 3306`
    * 任何由用户生成的数据都是不可靠的, 需要防止sql注入
    * 不要直接链接, 使用SSL或者SSH协议, 或者通过SSH隧道来创建communication `sudo tcpdump -l -i enp4s0 -w - src or dst port 3306 | strings`
2. Keeyping Passwords Secure  
如何保证密码的安全, 避免泄露密码. `validate_password` 插件可以保证密码的强度 [6.5.3 Password Validation Component](https://dev.mysql.com/doc/refman/8.0/en/validate-password.html)
    1. End-User方面
        * 使用`mysql_config_editor`工具,参见 4.6.7 mysql_config_editor
        * 使用 `-pyour_pass` 或者 `--password=your_pass`参数来链接
        这个很方便但是不安全, 因为 使用ps命令或者看bash_history可以看到
        * 使用`-p`或者`--password`参数, 但是不输入密码
        这样mysql会提示你输入密码, 这样比较安全, 但是只能用在交互模式上. 不然程序会卡住
        * 把密码放在.my.cnf文件, 然后用--defaults-file使用这个文件
        注意把文件设置成600模式, 具体参见 4.2.7 Using Option Files
        * 把密码保存到 MYSQL_PWD 环境变量
        这个及其不安全, 谁都能看到. 
        * 其他
        在unix系统, mysql会保存命令日志, 所以使用CREATE USER 或者ALTER User的时候, 会记录下来. 所以要使用restrictive access model. 和之间.my.cnf文件一样  
        一些.bash_history也应该只能自己看到
    2. Administrator方面
    MySQL保存密码到mysql.user表, 不能给任何人权限访问
    3. [ ] Passwords和Logging
    log日志因为会保存, 所以要保证log table和log file不能让别人访问. 在master和slave之间尤其要注意. log日志在哪目前还不知道, 但是默认肯定是root才能访问的.
3. Making MySQL Secure Against Attackers  
直接链接,别人都会检测到. 所以需要使用加密的SSL链接
    * 保证所有账户都要有个密码
    * 只有运行mysqld的账户(一般是root, mysql)才能进入mysql的目录
    * 永远不要使用root用户去执行MySQL. 因为会创造出一些 ~root/.bashrc
    所以默认这是mysqld的运行账户是mysql
    * 不要把文件授权给别的用户
    也要防止mysql可以直接读取类似`/etc/passwd`的文件, 参见 5.1.8 Server System Variables
    * 不要把PROCESS或者SUPER权限给非管理员用户. 
    * 不要允许表的symlinks
    * Stored programs和views需要控制
    * GRAND的时候, 如果你不信任你的DNS, 最好使用IP而不是DNS. 如果使用通配符必须格外小心
    * 限制用户的max user connections
    * 要防止plugin directory是writable

## [Access Control](https://dev.mysql.com/doc/refman/8.0/en/access-control.html)

### 用户管理

用户名字, 密码问题. 如何添加删除用户. 如果使用角色概念. 如何修改密码. 安全引导.

### User Names and Passwords 用户名和密码的使用


```sql
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
```mysql
mysql> SHOW GRANTS FOR 'admin'@'localhost';
>> Grants for admin@localhost
>> GRANT RELOAD, PROCESS ON *.* TO 'admin'@'localhost'
mysql> SHOW CREATE USER 'admin'@'localhost'\G
>> 1. row
CREATE USER for admin@localhost: CREATE USER 'admin'@'localhost'
IDENTIFIED WITH 'mysql_native_password'
AS '*67ACDEBDAB923990001F0FFB017EB8ED41861105'
REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK
```
* 创建普通帐号
```
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

### Removing User Accounts

## Using Encrypted Connections
## Security Components and Plugins
## FIPS Support

# [数据类型 Data Types](https://dev.mysql.com/doc/refman/8.0/en/data-types.html)
## [Data Type Overview]()
## [数字类型]()
    * 基础: INT(2)
    * 可用参数: `UNSIGNED, ZEROFILL, AUTO_INCREMENT`
    * `ALTER TABLE tb1 AUTO_INCREMENT = 100;`  # 不是自动加1,而是自动加100
    * YEAR(4)

## [时间和日期](https://dev.mysql.com/doc/refman/8.0/en/date-and-time-types.html)
* TIMESTAMP 时间戳类型
插入的时候，会把时间变成时间戳保存，取出的时候，会自动根据链接的时区变成datetime


    CREATE TABLE `test7` (
      `n` int DEFAULT NULL,
      `updateat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )

## [字符串类型]()

### [枚举类 ENUM TYPE](https://dev.mysql.com/doc/refman/8.0/en/enum.html)
```sql
CREATE TABLE shirts (
    name VARCHAR(40),
    size ENUM("x-small", "small", "medium", "large", "x-largs")
)
ALTER TABLE shirts MODIFY size ENUM("small", "big");
ERROR 1265 (01000): Data truncated for column 'size' at row 2;  # 如果enum不存在就报错了
```
* 实际上数据库用1个字节来保存这个数据，所以速度会快很多
* 注意排序，会根据ENUM的顺序来排序


## [Spatial Data Types空间类型](https://dev.mysql.com/doc/refman/8.0/en/spatial-types.html)
* [创建空间类型列](https://dev.mysql.com/doc/refman/8.0/en/creating-spatial-columns.html)
```mysql
    CREATE TABLE geom (g GEOMETRY);
```
* [获取空间数据][fetching-Spatial-data]
```mysql
    SELECT ST_AsText(g) from geom;
    > | POINT(1 1) |
    SELECT ST_AsBinary(g) from geom;
    > | 010010000 |
```
## [JSON Data Type][json-type-url]
* 插入数据
```
insert into testjson values (JSON_ARRAY(1,2,3));
```
* [过滤](https://dev.mysql.com/doc/refman/8.0/en/json.html#json-paths)
```
select *, JSON_EXTRACT(json, '$.key1') b from testjson where JSON_EXTRACT(json, '$.key1') is not null;
```

# [Functions and Operators](https://dev.mysql.com/doc/refman/8.0/en/functions.html)  
通用的函数和操作
## [Date and time](https://dev.mysql.com/doc/refman/8.0/en/date-and-time-functions.html)
时间操作相关
* [ ] CURTIME
* DATE
从datetime里面或者他的日期
    ```
    select DATE('2003-12-31 01:02:03');
    -> '2003-12-31'
    ```
* [ ] `DATE_ADD`


# 过滤
* 基础: `WHERE species = 'dog'`
* `IN`: `SELECT * FROM pet WHERE species IN ('dog', 'cat');`

# [backup and restore 备份与恢复](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)
## outfile
    ```
    SELECT a,b,a+b INTO OUTFILE '/tmp/result.text'
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    FROM test_table;
    ```

## [mysqldump](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)
* 示例代码
```
mysqldump -u root -p test --extended-insert=FALSE > test.sql  # windows下不正确，因为windows用了UTF-16
mysqldump -u root -p test --extended-insert=FALSE --result-file=test.sql
```
* 选项
    * `--extended-insert`: 是否把所有数据的insert写成一句，默认True
    * `--complete-insert`: insert语句里面是否带上columns的参数，默认False
* Performance and Scalability Considerations 性能和企业数据要考虑
> It's recommended to use mysqlbackup command of MySQL Enterprise Backup product, 因为mysqldump要考虑索引，io，处理大型数据会很慢

## 恢复
    ```
    mysql -h localhost -u root -p < ./test.sql  # 处理dump出来的
    mysql> LOAD DATA LOCAL INFILE 'dump.txt' INTO TABLE mytbl  # 处理outfile的结果
      -> FIELDS TERMINATED BY ':'
      -> LINES TERMINATED BY '\r\n';
    ```

# [Optimization 性能优化](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
## [Optimization and Indexes 索引](https://dev.mysql.com/doc/refman/8.0/en/optimization-indexes.html)
1. [How MySQL Uses Indexes](https://dev.mysql.com/doc/refman/8.0/en/mysql-indexes.html)
    * If there is a choice between multiple indexes, MySQL normally uses the index that find the smallest number of rows(most selective index)
    * multiple-column index can be used by the leftmost prefix of the index, (col1, col2, col3) 的联合索引可以用于 (col1), (col1, col2), (col1, col2, col3)
    * If a query uses from a table only columns that are included in some index, the selected values can be retrieved from the index tree for greater speed.
2. [Primary Key Optimization 主键优化](https://dev.mysql.com/doc/refman/8.0/en/primary-key-optimization.html)
    * set primary key not null 设置成非null
    * With the InnoDB storage engine, the table data is physically organized to do ultra-fast lookups 主键非常快
    * if it does not have an obvious column or set of columns to use as a primary key, create a separate column with auto-increment 必要要有主键
3. [ ] SPATIAL Index Optimization
4. [ ] Foreign Key Optimization
5. [ ] Column Indexes
6. [ ] Multiple-Column Indexes
7. [ ] Verifying Index Usage
8. [ ] InnoDB and MyISAM Index Statistics Collection
9. [ ] Comparison of B-Tree and Hash Indexes
10. [ ] Use of Index Extensions
11. [ ] Optimizer Use of Generated Column Indexes
12. [ ] Invisible Indexes
13. [ ] Descending Indexes

## to be continued
* [ ] Optimization Overview
* [ ] Optimizing SQL Statements
* [ ] Database Structure
* [ ] Optimizing for InnoDB Tables
* [ ] Optimizing for MyISAM Tables
* [ ] Optimizing for MEMORY Tables
* [ ] Understand the Query Execution Plan
* [ ] Controlling the Query Optimizer
* [ ] Buffering and Caching
* [ ] Optimizing Locking Operations
* [ ] Optimizing the MySQL Server
* [ ] Measuring Performance
* [ ] Examining Thread Information

# SQL Statement Syntax
## Data Definition Statements
* [ALTER TABLE Syntax](https://dev.mysql.com/doc/refman/8.0/en/alter-table.html)
ALTER TABLE score smallint unsigned not null; this will set the **default value** 0
    * [案例](https://dev.mysql.com/doc/refman/8.0/en/alter-table-examples.html)
    ```sql
    alter table <table> add <column> <data-type> [after <column>]
    ALTER TABLE t1 RENAME t2;
    ALTER TABLE t2 MODIFY a TYNYINT NOT NULL, CHANGE b c CHAR(20);
    ALTER TABLE t1 RENAME COLUMN hometown_match TO hometown_match2;  -- 重命名
    ALTER TABLE t2 ADD d TIMESTAMP;
    ALTER TABLE t2 ADD INDEX (d), ADD UNIQUE (a);
    ALTER TABLE t2 DROP COLUMN c;  删除列
    ALTER TABLE t2 ADD c INT UNSIGNED NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (c);
    ```
    * Performance and Space Requirements
    ALTER TABLE use one the the following algorithms (COPY, INPLACE(before 8.0), INSTANT(new in 8.0.12 default))
    ALTER 的时候，会复制原先的数据表，此时数据库处于只读状态，不能改写或插入(除非是把一个table移动到另外一个文件夹的RENAME TO操作)
* [CREATE INDEX Syntax](https://dev.mysql.com/doc/refman/8.0/en/create-index.html)
    * 不能够加双引号，加了会导致报错
    ```
    CREATE INDEX t1_hometown_match_28b57695 ON t1 (hometown_match);
    SELECT INDEX_NAME FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = 'test' AND TABLE_NAME="t1";
    DROP INDEX index_name on tbl_name
    ```

# 有待整理
* [data 基础操作](./database/data.md)
* [和数据库, 表有关的操作](./database/table表和数据库.md)

# 配置
* [utf8与utf8mb4的问题](https://mathiasbynens.be/notes/mysql-utf8mb4)
    1. ALTER DATABASE database_name CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
    2. ALTER TABLE table_name CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    3. ALTER TABLE table_name CHANGE column_name column_name VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    4. SHOW VARIABLES WHERE Variable_name LIKE 'character\_set\_%' OR Variable_name LIKE 'collation%';
* [`utf8mb4_unicode_ci`和`utf8mb4_general_ci`](http://wing.uoogre.com/mysql%E8%A6%81utf8mb4%E7%BC%96%E7%A0%81utf8mb4_unicode_ci%E4%B8%8Eutf8mb4_general_ci%E7%9A%84%E5%8C%BA%E5%88%AB/)
尽量用前面的
```
`id` varchar(31) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;
alter table group_groupapply convert to character set utf8mb4 collate utf8mb4_unicode_ci;
```

# 性能问题
* [参考链接](https://zhuanlan.zhihu.com/p/113917726)
    1. mysql使用B+树，是因为磁盘上一次读取的信息很多，只存一个节点有点亏。多以干脆多存几个，减少层级数
    2. mysql的innodb是直接在叶子节点存了数据(聚集索引)，如果对其他的key做索引，会有回表再次查询的问题（为了节约空间）。所以每个表必须要有主键。但是mysql的叶子节点数据也有物理地址啊。给其他的字段创建索引时为什么不直接用物理地址呢？这个物理地址会变化吗
        * 主键不要太长，因为其他的索引数据就太大了
    3. myisam则是保存了物理地址。索引查到数据后直接能读取数据


[fetching-Spatial-data]: https://dev.mysql.com/doc/refman/8.0/en/fetching-spatial-data.html
[json-type-url]: https://dev.mysql.com/doc/refman/8.0/en/json.html
