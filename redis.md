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

# Progamming with Redis
## [Redis as an LRU cache](https://redis.io/topics/lru-cache)
* maxmemory 最大允许使用的内存 如果是用10M代表了10000000字节，如果是10MB代表了 10MiB
* maxmemory-policy 占用内存过多时的操作
* maxmemory-samples 5 控制的精准度 (从几个sample里面找到不需要的key去删除)

## Redis as an LFU mode
Starting with Redis 4.0, a new Least Frequently Used eviction mode is available.
* lfu-decay-time 1: 每过多少时间，key的counter会减少
* lfu-log-factor 10: 需要次命中后，counter达到最大。我们系统里匹配一个人大概匹配几千次。所以匹配1000次后认为最大，暂时不删除, factor设置成0, decay-time要坚持数据保存一天，255次需要6分钟才允许删除一次。一共需要减少16次，所以设置成10吧

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

## [Geo](https://redis.io/commands#geo)
* GEOADD `GEOADD key longitude latitude member [longitude latitude member ... ]`
* GEODIST `GEODIST key member1 member2 unit`
* GEORADIUS `GEORADIUS key 15 37 100 km`
* GEOHASH `GEOHASH key member [member1 [member2]]`
    1. They can be shortened removing characters from the right. It will lose precision but will still point to the same area.
    2. Strings with a similar prefix are nearby, but the contrary is not true, it is possible that strings with different prefixes are nearby too.
* GEOPOS `GEOPOS key member [member1]`
return longitude latitude
* GEODIS `GEODIS key member1 member2 [unit|m|km|mi|ft]`
return the distance of two position
* GEORADIUS
```
GEORADIUS key longitude latitude radius m|km|ft|mi [WITHCOORD] [WITHDIST] [WITHHASH] [COUNT count] [ASC|DESC] [STORE key] [STOREDIST key]
```
Query very large areas with a very small COUNT option may be slow.
* GEORADIUSBYMEMBER
THis command is exactly like GEORADIUS except you should use a member to replace the longitude and latitude

## Keys
* DEL
```
DEL key1 [key2 [key3]]
(integer) 2  # return how many keys has really been deleted
```
* DUMP
> Return a serialized version of the value stored at the specified key, it does not contain expire information

* EXISTS `EXISTS KEY1 [KEY2] KEY[3]`
> Return the number of keys that exists

* EXPIRE `EXPIRE key seconds`  
    1. DEL, SET, GETSET will clear the timeout  
    2. `RENAME Key_B Key_A`: the new timeout will inherit all the characteristics of `Key_B`  
    3. Call `EXPIRE/PEXPIRE` with a non-positive timeout or `EXPIREAT/PEXPIREAT` with a time in the past will delete the key rather than expired  
    4. return 1 if the key exists and 0 if the key does not exist  
    5. The expire accuracy error is from 0 to 1 milliseconds since 2.6
    6. The expire information is stored as absolute Unix timestamps, so even the Redis instance is not active, the time still flows.
    7. delete the key in passive way and active way.

* EXPIREAT `EXPIREAT key timestamp`

* KEYS
> don't use in in production environment, consider using scan or sets

* migrate
> transfer a key from a Redis instance to another one.

* move key db
> move a key to another database (the key must don't exist in the other database); return 1 if key was moved 0 if it was not moved.

* OBJECT
    * REFCOUNT: for debugging
    * ENCODING: show "embstr" or "int"
    * IDLETIME: seconds since the object stored at the specified key is idle.

* PERSIST
> Remopve the existing timeout on key.

* PEXPIRE
> Like EXPIRE but the time to live of the key is in milliseconds.

* PEXPIREAT
> Like EXPIREAT but the Unix time is specified in milliseconds

* PTTL
> Returns the remaining time of live of a key. -2 if the key does not exist and -1 if the key exists but has no associated expire.

* RANDOMKEY
> Return a random key from currently selected database.

* RENAME
> Renames key to new key. It returns an error when key does not exist, overwrite the key if exists (using DEL operation).

* RENAMEX
> Renames key to newkey if newkey does not yet exist.

* restore
`RESTORE key expire(milliseconds) dumpdata`
if expire is 0, the key is created without any expire

* SORT
> return the elements contained in the list
1. SORT mylist
2. SORT mylist DESC
3. SORT mylist ALPHA 0 2  # limit the amount
4. `SORT mylist By weight_*`  # this will get the key and get the value of `weight_<key>`, and then order by the value
5. `SORT mylist By weight_* get object_*`  # after sort, it will return the value of `object_<key>`
6. `SORT mylist By weight_* STORE resultkey`  # after sorting, store it in `<resultkey>`

* [ ] touch

* TTL [教程](https://redis.io/commands/ttl)  
    ```
    * 返回一个key的remaining time
    * >=0, 剩余时间
    * -1, 这个key不存在expire time
    * -2, key不存在
    ```


## Lists
    * blpop
    * brpop
    * brpoplpush: 和rpoplpush类似，但是会block
    * lindex: 返回一个元素在List的位置
    * `linsert key BEFORE|AFTER value1 new_value`: 插入新的数据
    * llen: 长度
    * `lpop`: `lpop(key)  如果没有数据了，返回None`
    * lpush
    * lpushx: only insert if the key exists
    * rpoplpush
    * lrange
    * `lrem key count value`: 删除list里面的元素,count代表几次。0代表所有，count>0从head往tail删，count<0从tail往head删除
    * lset key index value: 修改元素index的值
    * ltrim key start stop: 只保留list中部分的数值
    * rpop
    * rpoplpush
    * rpush
    * rpushx: 必须有这个key，这个key是list才会push

## [Pub/Sub 订阅消息](https://redis.io/commands#pubsub)
* SUBSCRIBE: `SUBSCRIBE channel [channel]`
* PUBLISH: `PUBLISH channel message` return the number of clients that received the message

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

## [Sorted Sets](https://redis.io/commands#sorted_set)
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
* [ZADD](https://redis.io/commands/zadd)
    * `ZADD key <score> member`
    * python: `redis.zadd(key, mapping)`
    * `redis.zadd('my-key', 1.1, 'name1', 2.2, 'name2', name3=3.3, name4=4.4)`
* [ZCARD](https://redis.io/commands/zcard)
返回一个sorted sets的长度, 如果key不存在，就返回0
* ZCOUNT
返回scrore在min和max之间的元素的数量
默认是闭区间，如果想要得到开区间，就在对应的数字上加`(`
```
ZCOUNT myset -inf +inf
ZCOUNT myset 1 3
```
* ZPOPMAX  
返回score最大的若干个elements, 如果超过了，不会报错
```
> ZPOPMAX key [count]
[('three', 3.0), ('b', 2.0)]
[('c', 2.0)]
```
* ZSCORE: `ZSCORE key member`
返回一个key里面member的score, 如果key不存在会返回nill(None)

* [ZRANGE](https://redis.io/commands/zrange)
```
zrange('mykey', 0, -1)
```
    1. > 从0开始, -1是最后一个， -2是倒数第二个
    2. > 前后都是闭区间
    3. > 不会报错，如果start大于stop，或者start大于长度，返回 []
* [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
* [ ] ZRANK
* [ZREM](https://redis.io/commands/zrem): 删除一个元素  
基础代码
```
ZREM key member [member ...]
> 0  # 只要有一个member存在，就会返回1, 否则返回0
```
python用法
```
client.zrem(key, 'member', 'member2')
> 0 或者 1 # 只要一个member存在就返回1
```

* [ ] ZREMRANGEBYLEX
* [ZREVRANGE](https://redis.io/commands/zrevrange): 类似ZRANGE但是是逆序的

# Administration
## Config 配置
* maxmemory 100mb
    * string 72b 
    * list 168b
    * set 72b
* bind 允许通过哪个IP访问，一般设置成127.0.0.1(本机访问)或者自己的IP(都能访问), useless，不是防火墙的只允许哪些地址访问的意思
    * bind 127.0.0.1  只监听本机  
    * bind 192.168.1.111  这个ip必须是本机的ip, 其他机子 redis-cli -h 192.168.1.111 就能访问  
    * 192.168.1.111 127.0.0.1  这样就能直接 localhost访问或者其他机器 -h 192.168.1.111 访问了。
* requirepass `<longpassword>`: password，longer than 32
* daemonize no: if it is yes, redis will create `/var/run/redis.pid`

## Persistence
redis有2种保存方式
* RDB保存直接保存当前的快照
* AOF保存所有的操作

### RDB的优势
* 仅仅生成一个文件，方便备份
* 方便恢复
* 性能高，会生成一个子进程来备份
* 恢复时启动块

### RDB缺点
* 不是及时的，2次备份间隔期间的数据会因为下次备份没生成而丢失
* 数据很大，cpu不高会卡顿

## To be continued
* [ ] Replication
* [ ] Redis Administration
