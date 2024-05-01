[sqlite tutorial 官网](http://www.sqlitetutorial.net/)  
[sqlite org](https://sqlite.org/index.html)  

* [如果命令写错了怎么办](https://unix.stackexchange.com/questions/291083/sqlite3-command-line-how-do-you-cancel-a-command)  
用3个***故意写个错误的语法
```
sqlite> select * from todos'
   ...> '
   ...> *** I made a mistake
   ...> ;
Error: near "*": syntax error
sqlite>
```

* [比较所有表的尺寸](https://stackoverflow.com/questions/27572387/query-that-returns-the-size-of-a-table-in-a-sqlite-database)
```sql
SELECT name ,SUM(pgsize)/1024 table_size  FROM "dbstat" GROUP BY name ORDER BY table_size desc;
```

* 查看所有表
```sql
select * from sqlite_master;
```

### 9. 修改数据
#### [insert 插入数据](https://www.sqlitetutorial.net/sqlite-insert/)
* 语法
```sql
> INSERT INTO table (column1,column2 ,..)  
VALUES( value1,	value2 ,...);
```

* 案例

```sql
insert into pets values (null, 'cat'); /* 不指定id */
insert into pets values (1, 'cat');  /* 指定id */
/* >>> Error: UNIQUE constraint failed: pets.id */
insert into pets values (null, 'cat'), (null, 'dog');  /* 批量插入数据 */
insert into pets (name) values ('cat'), ('dog');  /* 指定表头顺序 */
```

#### Update
#### Delete
#### Replace

### Section 11. Data definition
* alter
[官网](http://www.sqlitetutorial.net/sqlite-alter-table/)  
sqlite不支持删除字段，只支持rename表和添加column. 所以如果你想删除某个字段，就先rename这个表，然后创建一个新表,然后再把数据复制过来


    ALTER TABLE existing_table ADD COLUMN st_size integer NULL;

* attach
导入其他的数据库
```
attach "filename" as <dbname>;
```
* [ ] autoincrement
* CREATE 创建表


    CREATE TABLE "dbxd" (
    "id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, 
    "time" datetime NOT NULL, 
    "contentid" varchar(32) NOT NULL,
    "charge1" integer NOT NULL, 
    "channel" varchar(32) NOT NULL);  

* [ ] drop
* rename
```
ALTER TABLE <表> RENAME TO <临时表名>
CREATE TABLE <表>
INSERT INTO <表> SELECT * FROM <临时表名>
```
* .schema
查看某个表的格式  

### Section 14. Indexes 索引
#### [基础](https://www.sqlitetutorial.net/sqlite-index/)
#### 基础-创建索引

    # 单列索引
    CREATE INDEX myindexname
    ON <tablename>(<columname>);

    # 多列索引
    CREATE UNIQUEINDEX myindexname
    ON comments(post, sender);


#### [基础-查看索引](https://www.sqlitetutorial.net/sqlite-index/#shcb-language-14)
#### 基础-删除索引

### [Inner Join](https://www.sqlitetutorial.net/sqlite-inner-join/)
* 基础用法


    SELECT a1, a2, b1, b2
    FROM A
    INNER JOIN B on B.f = A.f;

* 找到某个用户的所有专辑下的所有歌曲


    SELECT
        trackid,
        tracks.name AS Track,
        albums.title AS Album,
        artists.name AS Artist
    FROM
        tracks
    INNER JOIN albums ON albums.albumid = tracks.albumid
    INNER JOIN artists ON artists.artistid = albums.artistid
    WHERE
        artists.artistid = 10

### Section 17
#### [引入csv文件](https://www.sqlitetutorial.net/sqlite-import-csv/)

```sql
create table <tablename>(field1, field2)
.mode csv
.import <filepath> <tablename>
```

#### 导出和备份数据
* [dump 备份数据库](http://www.sqlitetutorial.net/sqlite-dump/)
```
.output backup.sql
.dump
.exit
或者
.output test.txt
select * from table;
```

* read 还原数据库  
如果你是从mysqldump出来的数据, 可以用[工具](https://github.com/dumblob/mysql2sqlite)进行转化
```
sqlite3 test.db
.read <filename>
.import 文件名 表名
```
