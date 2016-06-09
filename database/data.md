# Sqlite
## 插入
    INSERT INTO "TESET" ( "NAME" ) VALUES ( "TEST" ) , ( "TEST2" );

## 查询
#### 简单查询
    SELECT * FROM TABLE;
    SELECT DISTINCT ID FROM TABLE;  # 去重, 这个distinct是用来修饰SELECT的
    select * from order_dayorder, order_country where   # 外键查询 
            order_dayorder.country_id = order_country.id;
    SELECT * FROM <table> where <column> like "%王%" and id < 5 and age > 20;  # 模糊查询

## 删除
    DELETE from <table> where <condition>

## 修改
    UPDATE <table> SET column1=value1, column2=value2 WHERE column3=value3;

## 数据库迁移
    ALTER TABLE "table_city" RENAME TO "table_city__old";
    CREATE TABLE "table_city" ("id" integer NOT NULL PRIMARY KEY AUTOINCREMENT, "code4" varchar(6) NOT NULL, "name" varchar(37) NOT NULL, "province_id" integer NOT NULL REFERENCES "table_province" ("id"));
    INSERT INTO "table_city" ("id", "province_id", "name", "code4") SELECT "id", "province_id", "name", "code" FROM "table_city__old";
    DROP TABLE "table_city__old";
    CREATE INDEX "table_city_4a5754ed" ON "table_city" ("province_id");

# MySQL
## 查询
#### INNER JOIN
    SELECT a.column, b.column FROM table1 a INNER JOIN table2 b ON a.column_id = b.column_id

#### LEFT JOIN
    SELECT a.column, b.column FROM table1 a LEFT JOIN table2 b ON a.column_id = b.column_id;
#### RIGHT JOIN
    SELECT a.column, b.column FROM table1 a RIGHT JOIN table2 b ON a.column_id = b.column_id;
### 制定多个字段排序
    select * from <table> order by date desc, time desc limit 100;
