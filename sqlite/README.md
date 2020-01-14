**Xiang Wang @ 2019-12-31 10:18:41**

### 基础
[官网](http://www.sqlitetutorial.net/)
* alter
[官网](http://www.sqlitetutorial.net/sqlite-alter-table/)  
sqlite不支持删除字段，只支持rename表和添加column. 所以如果你想删除某个字段，就先rename这个表，然后创建一个新表,然后再把数据复制过来
* attach
导入其他的数据库
```
attach "filename" as <dbname>;
```
* [ ] autoincrement
* CREATE 创建表
```
CREATE TABLE "dbxd" (
"id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, 
"time" datetime NOT NULL, 
"contentid" varchar(32) NOT NULL,
"charge1" integer NOT NULL, 
"channel" varchar(32) NOT NULL);  
```
* [ ] drop
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
```
sqlite3 test.db
.read <filename>
.import 文件名 表名
```
* rename
```
ALTER TABLE <表> RENAME TO <临时表名>
CREATE TABLE <表>
INSERT INTO <表> SELECT * FROM <临时表名>
```
* .schema
查看某个表的格式  

### [Inner Join](https://www.sqlitetutorial.net/sqlite-inner-join/)
* 基础用法
```
SELECT a1, a2, b1, b2
FROM A
INNER JOIN B on B.f = A.f;
```
* 找到某个用户的所有专辑下的所有歌曲
```
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
```
