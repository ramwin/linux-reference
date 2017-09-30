#### Xiang Wang @ 2017-05-12 13:59:21

# 基础
* [官方教程](https://redis.io/commands#)
* string
    * `SET key value [EX seconds] [PX milliseconds] [NX|XX]` [参考](https://redis.io/commands/set)
        ```
        # SET key value [EX seconds] [PX milliseconds] [NX|XX]
        # NX only set the key if it does not already exist
        # XX only set the key if it already exist
        SET foo bar
        # 利用这个 NX 可以做成一个资源锁。当client申请资源的时候, set key value ex 3600 NX, 如果返回ok就操作，否则就申请失败
        ```
    * GET
        ```
        GET foo
        ```
* list
    * `lpop`
        ```
        lpop(key)  如果没有数据了，返回None
        ```
* keys
    * TTL [教程](https://redis.io/commands/ttl)  
        ```
        * 返回一个key的remaining time
        * >=0, 剩余时间
        * -1, 这个key不存在expire time
        * -2, key不存在
        ```
