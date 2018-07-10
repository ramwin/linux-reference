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
* [Redis Strings](https://redis.io/topics/data-types-intro#redis-strings)
    * tutorial
    ```
    > set mykey value nx|xx nx: key must not exist xx: exist
    > get mykey
    > set counter 100
    > incr counter
    > incrby counter 50
    > mset a 10 b 20 c 30
    OK
    > mget a b c
    1) "10"
    2) "20"
    3) "30"
    > exists mykey
    (integer) 1
    > del mykey
    (integer) 1
    > exists mykey
    (integer) 0
    > type mykey
    > set key some-value
    > expire key 5  # redis saves the date at which a key will expire, so even the server stops, the expire time will still run

    > set key 100 ex 10
    > ttl key
    > persist key
    ```
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
* ## [redis sorted sets](https://redis.io/topics/data-types-intro#redis-sorted-sets)
    * tutorial
    ```
    > zadd hackers 1940 "Allan Kay"
    (integer) 1
    > zadd hackers 1957 "Sophie Wilson"
    (integer) 1

    > zrange hackers 0 -1
    > zrevrange hackers 0 -1
    > zrange hackers 0 -1 withscores
    > zrangebyscore hackers -inf 1950
    > zremrangebyscore hackers 1940 1960
    > zrange hackers "Anita Borg"  # return the rank (from 0) or (nil)

    # Lexicographical scores  # It should only be used in sets where all the members have the same score. 只能用于所有元素分数一致的情况，不然过滤会出现意想不到的结果
    > zadd hackers 0 "Alan Kay" 0 "Sophie Wilson" 0 "Richard Stallman" 0
  "Anita Borg" 0 "Yukihiro Matsumoto" 0 "Hedy Lamarr" 0 "Claude Shannon"
  0 "Linus Torvalds" 0 "Alan Turing"
    > zrange hackers 0 -1
    > zrangebylex hackers [B [P
    ```

# [Command 命令](https://redis.io/commands)
## connections
* [ ] auth
* echo argument: return argument
* [ping](https://redis.io/commands/ping)
```
ping [argument]: return "pong" if argument is mepty or <argument>
use this command to test if a connection is still alive
```
* quit: close the connection
* select: select index switch to different database
* swapdb index index: swap two redis databases, the clients connected with database 1 will see the data that was formerly of database 0


## Keys
    * TTL [教程](https://redis.io/commands/ttl)  
        ```
        * 返回一个key的remaining time
        * >=0, 剩余时间
        * -1, 这个key不存在expire time
        * -2, key不存在
        ```
* [ ] Lists
    * `lpop`
        ```
        lpop(key)  如果没有数据了，返回None
        ```

## String
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

## Sorted Sets
* [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
