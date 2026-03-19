#!/usr/bin/env python3
import redis
import time
import threading
import sys

def continuous_write_test():
    """持续写入测试：故障期间允许卡顿，禁止报错"""
    client = redis.cluster.RedisCluster(
        startup_nodes=[{"host": "127.0.0.1", "port": 6666}],
        decode_responses=True,
        socket_connect_timeout=6,
        retry_on_timeout=True,
        retry=redis.retry.Retry(
            redis.backoff.ExponentialBackoff(cap=1, base=0.1),
            retries=20
        )
    )
    
    success_count = 0
    fail_count = 0
    max_stall = 0
    
    for i in range(100):
        start = time.time()
        try:
            client.set(f"key_{i}", f"value_{i}")
            elapsed = time.time() - start
            success_count += 1
            if elapsed > max_stall:
                max_stall = elapsed
            print(f"[{i}] OK ({elapsed:.2f}s)")
        except Exception as e:
            fail_count += 1
            print(f"[{i}] FAIL: {e}")
        
        # 在第 20 次写入时，手动触发故障转移（在另一个终端执行 docker stop kvrocks1）
        if i == 20:
            print("\n*** 请立即执行: docker stop kvrocks1 ***")
            print("*** 预期行为：接下来几次写入卡顿 3-5 秒，但不报错 ***\n")
            time.sleep(2)
    
    print(f"\n结果: 成功 {success_count}, 失败 {fail_count}, 最大卡顿 {max_stall:.2f}s")

if __name__ == "__main__":
    continuous_write_test()
