**Xiang Wang @ 2018-06-29 11:48:44**


# Install
* docker
```
    docker run --restart=always --name redis -d -p 6379:6379 redis
    docker exec -it redis-server redis-cli
```
* [compile install](https://redis.io/download)
```
    wget http://download.redis.io/releases/redis-3.2.8.tar.gz
    tar xzf redis-3.2.8.tar.gz
    cd redis-3.2.8
    make
    src/redis-server
```

# [Data Types 数据类型](https://redis.io/topics/data-types-intro)
* [ ] redis hashes
* ## [Redis Sets](https://redis.io/topics/data-types-intro#redis-sets)
    * tutorial
    ```
    > sadd myset 1 2 3
    (integer) 3
    > smembers myset
    1) "1"
    2) "2"
    3) "3"
    > sismember myset 3
    (integer) 1
    > sismember myset 30
    (integer) 0
    > sinter tag:1:news tag:2:news tag:10:news tag:27:news  # find the same member in all keys 找到几个sets共有的元素
    ... results here ...
    > sunionstore game:1:deck deck [otherdeck...]  # copy all the members in deck to game:1:deck 复制所有的元素到目标game:1:deck
    > spop game:1:deck [count] # pop a member from sets
    "C6"
    > scard game:1:deck  # count the amounts of remaining members
    (integer) 47
    ```
* [ ] redis sorted sets

# [Command 命令](./redis/commands.md)

# [database 数据库]
    * change database 切换数据: `select 1`
