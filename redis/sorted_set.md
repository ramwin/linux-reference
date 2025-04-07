# Sorted Sets
## 常用示例
* 获取任务
```
# 死循环快速处理任务
while True:
    info = redis.bzpopmin('key', timeout=30)
    if info is None:
        continue
    _, taskid, score = info
```

[官网][sorted set]

sorted sets 保存的是字符串: float

## zpopmin,zpopmax
返回score最大的若干个elements, 如果超过了，不会报错
```
> ZPOPMAX key [count]
[('three', 3.0), ('b', 2.0)]
[('c', 2.0)]
```

## BZPOPMIN(str|List[str], timeout)
如果timeout了，返回None, 否则返回(rediskey: str, value_key, score: float)

## Lexicographical scores
It should only be used in sets where all the members have the same score. 只能用于所有元素分数一致的情况，不然过滤会出现意想不到的结果
> zadd hackers 0 "Alan Kay" 0 "Sophie Wilson" 0 "Richard Stallman" 0
    "Anita Borg" 0 "Yukihiro Matsumoto" 0 "Hedy Lamarr" 0 "Claude Shannon"
    0 "Linus Torvalds" 0 "Alan Turing"
> zrange hackers 0 -1
> zrangebylex hackers [B [P

## ZADD
[官网](https://redis.io/commands/zadd)
```
ZADD key <score> member  # shell
redis.zadd(key, mapping)  # python
```

## [ZCARD](https://redis.io/commands/zcard)
返回一个sorted sets的长度, 如果key不存在，就返回0
* ZCOUNT
返回scrore在min和max之间的元素的数量
默认是闭区间，如果想要得到开区间，就在对应的数字上加`(`
```
ZCOUNT myset -inf +inf
ZCOUNT myset 1 3
```
## ZINCRBY key increment member
如果key不存在，就创建这个key, 如果member不存在，就加入member
increment可以是小数，整数，负数, 返回当前的value

## ZSCORE: `ZSCORE key member`
返回一个key里面member的score, 如果key不存在会返回nill(None)

## [ZRANGE](https://redis.io/commands/zrange)
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
zrange('mykey', -1, -1, withscores=True)  # 找到最大的
[('foo', 23.0)]
zrange('mykey', -1, -1)  # 找到最大的
['foo']
```

> 从0开始, -1是最后一个， -2是倒数第二个  
> 前后都是闭区间  
> 不会报错，如果start大于stop，或者start大于长度，返回 []  

## [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
## [ ] ZRANK
## [ZREM](https://redis.io/commands/zrem): 删除一个元素  
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
* ZREMRANGEBYRANK
删除数据。注意是闭区间
```
redis.zremrangebyrank(key, 0, delete_cnt - 1)  # 删除delete_cnt
redis.zremrangebyrank(key, -10086, -101)  # 只保留最大的前100个数据
```
* ZREMRANGEBYSCORE
根据分数来删除
* [ZREVRANGE](https://redis.io/commands/zrevrange): 类似ZRANGE但是是逆序的

