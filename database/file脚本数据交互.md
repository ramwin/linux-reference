# sqlite
## 执行脚本
    sqlite3 test.db
    .read <filename>
## 数据导出
    .output test.txt
    select * from table;
## 数据导入
    .import 文件名 表名

# mysql
## 执行sql脚本
    mysql -h localhost -u root -p < ./test.sql

## 数据导出
    # 在mysql内部导出
    SELECT a,b,a+b INTO OUTFILE '/tmp/result.text'
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    FROM test_table;
    # 使用mysqldump导出
    mysqldump -uroot -p [database namne] > [dump file]
## 数据导入
    mysql> LOAD DATA LOCAL INFILE 'dump.txt' INTO TABLE mytbl
      -> FIELDS TERMINATED BY ':'
      -> LINES TERMINATED BY '\r\n';
