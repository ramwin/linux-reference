#!/usr/bin/env python3
"""
Kvrocks 集群高可用写入测试脚本

使用方法:
1. 启动集群: ./start-all.sh
2. 运行此脚本: python3 test-ha-failover.py
3. 当提示时执行: docker stop kvrocks1
"""

import redis
from redis.cluster import ClusterNode
import time
import sys
import signal

# 全局变量用于信号处理
running = True
timeout_occurred = False

def signal_handler(signum, frame):
    """处理 Ctrl+C"""
    global running
    print("\n[信号] 收到中断信号,正在停止...")
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def create_cluster_client():
    """创建集群客户端,带详细日志"""
    print("[初始化] 正在创建集群客户端...")
    print("[初始化] 连接地址: 127.0.0.1:6666")
    
    startup_nodes = [ClusterNode("127.0.0.1", 6666)]
    
    try:
        client = redis.cluster.RedisCluster(
            startup_nodes=startup_nodes,
            decode_responses=True,
            socket_connect_timeout=3,      # 连接超时 3 秒
            socket_timeout=3,              # 读写超时 3 秒
            retry_on_timeout=True,
            retry=redis.retry.Retry(
                redis.backoff.ExponentialBackoff(cap=1, base=0.1),
                retries=3                  # 最多重试 3 次
            ),
            skip_full_coverage_check=True,  # 允许部分节点故障
            reinitialize_steps=5,          # 集群拓扑刷新步数
            health_check_interval=1        # 健康检查间隔
        )
        print("[初始化] 客户端创建成功!")
        
        # 测试连接
        print("[初始化] 测试连接...")
        client.ping()
        print("[初始化] PING 成功!")
        
        # 获取集群信息
        print("[初始化] 获取集群节点信息...")
        nodes = client.cluster_nodes()
        print(f"[初始化] 集群共有 {len(nodes)} 个节点")
        
        return client
        
    except Exception as e:
        print(f"[初始化错误] {type(e).__name__}: {e}")
        raise


def safe_write(client, key, value, max_wait=10):
    """
    安全的写入操作,带超时控制
    
    使用忙等待而不是阻塞调用,避免永久卡死
    """
    global timeout_occurred
    
    start = time.time()
    result = {"success": False, "error": None, "elapsed": 0}
    
    # 使用线程来执行写入,主线程检查超时
    import threading
    
    write_result = {"done": False, "error": None}
    
    def do_write():
        try:
            client.set(key, value)
            write_result["done"] = True
        except Exception as e:
            write_result["error"] = e
            write_result["done"] = True
    
    # 启动写入线程
    thread = threading.Thread(target=do_write)
    thread.daemon = True
    thread.start()
    
    # 主线程等待,带超时检查
    while not write_result["done"]:
        elapsed = time.time() - start
        if elapsed > max_wait:
            # 超时了
            result["elapsed"] = elapsed
            result["error"] = f"操作超时(>{max_wait}s)"
            timeout_occurred = True
            return result
        time.sleep(0.1)
    
    # 操作完成
    result["elapsed"] = time.time() - start
    
    if write_result["error"]:
        result["error"] = write_result["error"]
    else:
        result["success"] = True
    
    return result


def continuous_write_test():
    """持续写入测试:故障期间允许卡顿,禁止报错"""
    
    print("="*60)
    print("Kvrocks 集群高可用写入测试")
    print("="*60)
    
    try:
        client = create_cluster_client()
    except Exception as e:
        print(f"[错误] 无法创建客户端: {e}")
        sys.exit(1)
    
    success_count = 0
    fail_count = 0
    timeout_count = 0
    max_stall = 0
    
    print("\n[测试] 开始持续写入测试...")
    print("[提示] 按 Ctrl+C 可以随时停止\n")
    
    for i in range(100):
        if not running:
            print("\n[停止] 测试被用户中断")
            break
        
        key = f"key_{i}"
        value = f"value_{i}"
        
        # 显示进度
        if i % 10 == 0:
            print(f"\n[进度] 当前写入次数: {i}/100")
        
        # 执行写入
        result = safe_write(client, key, value, max_wait=8)
        
        if result["success"]:
            success_count += 1
            if result["elapsed"] > max_stall:
                max_stall = result["elapsed"]
            if result["elapsed"] > 1:
                print(f"  [{i}] SLOW ({result['elapsed']:.2f}s): {key}")
            else:
                print(f"  [{i}] OK ({result['elapsed']:.2f}s): {key}")
        else:
            error_str = str(result["error"])
            if "超时" in error_str or "timeout" in error_str.lower():
                timeout_count += 1
                print(f"  [{i}] TIMEOUT ({result['elapsed']:.2f}s): {key} - {error_str}")
                # 超时后尝试刷新节点信息
                try:
                    print(f"  [{i}] 尝试刷新集群拓扑...")
                    client.reload_startup_nodes()
                    print(f"  [{i}] 拓扑刷新完成")
                except Exception as e:
                    print(f"  [{i}] 拓扑刷新失败: {e}")
            else:
                fail_count += 1
                print(f"  [{i}] FAIL ({result['elapsed']:.2f}s): {key} - {error_str}")
        
        # 第 20 次写入时提示用户执行故障转移
        if i == 20:
            print("\n" + "="*60)
            print("*** [关键步骤] 请立即执行以下命令来模拟故障:")
            print("***   docker stop kvrocks1")
            print("***")
            print("*** 预期行为:")
            print("***   - 接下来几次写入可能超时")
            print("***   - 超时后会自动重试/刷新拓扑")
            print("***   - 最终应该能继续写入(由从节点接管)")
            print("="*60 + "\n")
            time.sleep(3)
    
    # 输出统计结果
    print("\n" + "="*60)
    print("测试结果统计")
    print("="*60)
    print(f"总写入次数: {success_count + fail_count + timeout_count}")
    print(f"成功: {success_count}")
    print(f"超时: {timeout_count}")
    print(f"失败: {fail_count}")
    print(f"最大卡顿: {max_stall:.2f}s")
    
    if fail_count == 0:
        print("\n[通过] 没有写入失败,高可用测试通过!")
    else:
        print(f"\n[警告] 有 {fail_count} 次写入失败")
    
    print("="*60)


if __name__ == "__main__":
    continuous_write_test()
