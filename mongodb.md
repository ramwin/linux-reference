# 启动与退出
    docker pull mongo
    docker run --name some-mogo -d -p 27017:27017 -p 28017:28017 mongo:tag 

# python相关
[pymongo](https://docs.mongodb.org/getting-started/python/client/)
```python
    pip install pymongo
    from pymongo import MongoClient
    client = MongoClient()
    db = client.test
    db.restaurants.insert_on({<data>})
```

# 基础
    mongo --host localhost --port 27017
    help    # 显示帮助文档
    use test   # 使用数据库

# 插入数据
    # 如果没有_id,就会自己生成_id, _id必须保证唯一性
    db.user.insert(
        "name": "ramwin",
        "身高": 170,
        "家庭": [
            "父亲": {},
            "母亲": {},
        ]
    )
# 数据查询
    db.user.find({"name": "ramwin"})
    db.info.find({}, {realname:1, by: 1})  # by=1: include模式 by=0: exclude模式

# 删除数据库
    db.user.drop()

# 备份与还原
```
    mongodump -h localhost -d matchup -o `date +%Y年%m月%d日mongo数据库备份`
    mongorestore -h <hostname><:port> -d dbname <path>
```
