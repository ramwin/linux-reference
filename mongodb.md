## 启动与退出
    docker run -d -p 27017:27017 -p 28017:28017 --name mongodb -e AUTH=no tutum/mongodb

## python相关
[pymongo](https://docs.mongodb.org/getting-started/python/client/)
    pip install pymongo
    from pymongo import MongoClient
    client = MongoClient()
    db = client.test
    db.restaurants.insert_on({<data>})

## 基础
    mongo --host localhost --port 27017
    help    # 显示帮助文档
    use test   # 使用数据库

## 数据查询
    db.user.find()

## 删除数据库
    db.user.drop()
