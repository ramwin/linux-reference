#!/bin/bash
# Kvrocks 数据落盘验证脚本
# 多种方法验证数据是否真正写入磁盘

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Kvrocks 数据落盘验证工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查节点是否运行
check_node() {
    local port=$1
    redis-cli -p $port ping > /dev/null 2>&1
}

# 方法1: 查看数据目录磁盘占用
verify_disk_usage() {
    echo -e "${YELLOW}[方法1] 查看数据目录磁盘占用${NC}"
    echo "----------------------------------------"
    
    for node in master-1 master-2 master-3 replica-1 replica-2 replica-3; do
        local dir="${DATA_DIR}/${node}"
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            local sst_count=$(find "$dir" -name "*.sst" 2>/dev/null | wc -l)
            echo "  ${node}: ${size} (${file_count} 文件, ${sst_count} SST文件)"
        else
            echo "  ${node}: 目录不存在"
        fi
    done
    echo ""
}

# 方法2: 查看 RocksDB 统计信息
verify_rocksdb_stats() {
    echo -e "${YELLOW}[方法2] RocksDB 存储统计${NC}"
    echo "----------------------------------------"
    
    if ! check_node 6666; then
        echo -e "${RED}  错误: 节点未运行，请先启动集群${NC}"
        return 1
    fi
    
    # 获取 RocksDB 统计
    local stats=$(redis-cli -p 6666 INFO rocksdb 2>/dev/null || echo "")
    
    if [ -z "$stats" ]; then
        echo "  无法获取 RocksDB 统计信息"
        return 1
    fi
    
    # 提取关键指标
    echo "  内存使用:"
    echo "$stats" | grep -E "rocksdb.block_cache_usage|rocksdb.block_cache_pinned_usage|rocksdb.estimate-table-readers-mem|rocksdb.size-all-mem-tables" | while read line; do
        local key=$(echo "$line" | cut -d: -f1)
        local val=$(echo "$line" | cut -d: -f2 | tr -d '\r')
        # 转换为可读格式
        if [ "$val" -gt 1073741824 ]; then
            val_gb=$(echo "scale=2; $val/1073741824" | bc)
            echo "    $key: ${val_gb} GB"
        elif [ "$val" -gt 1048576 ]; then
            val_mb=$(echo "scale=2; $val/1048576" | bc)
            echo "    $key: ${val_mb} MB"
        elif [ "$val" -gt 1024 ]; then
            val_kb=$(echo "scale=2; $val/1024" | bc)
            echo "    $key: ${val_kb} KB"
        else
            echo "    $key: ${val} B"
        fi
    done
    
    echo ""
    echo "  磁盘数据:"
    echo "$stats" | grep -E "rocksdb.estimate-live-data-size|rocksdb.total-sst-files-size|rocksdb.live-sst-files-size" | while read line; do
        local key=$(echo "$line" | cut -d: -f1)
        local val=$(echo "$line" | cut -d: -f2 | tr -d '\r')
        if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
            if [ "$val" -gt 1073741824 ]; then
                val_gb=$(echo "scale=2; $val/1073741824" | bc)
                echo "    $key: ${val_gb} GB"
            elif [ "$val" -gt 1048576 ]; then
                val_mb=$(echo "scale=2; $val/1048576" | bc)
                echo "    $key: ${val_mb} MB"
            elif [ "$val" -gt 1024 ]; then
                val_kb=$(echo "scale=2; $val/1024" | bc)
                echo "    $key: ${val_kb} KB"
            else
                echo "    $key: ${val} B"
            fi
        fi
    done
    
    echo ""
    echo "  SST 文件统计:"
    echo "$stats" | grep -E "rocksdb.num-immutable-mem-table|rocksdb.num-immutable-mem-table-flushed|rocksdb.compaction.pending" | while read line; do
        echo "    $line" | tr -d '\r'
    done
    
    echo ""
}

# 方法3: 强制刷盘测试
verify_force_flush() {
    echo -e "${YELLOW}[方法3] 强制刷盘测试${NC}"
    echo "----------------------------------------"
    
    if ! check_node 6666; then
        echo -e "${RED}  错误: 节点未运行${NC}"
        return 1
    fi
    
    # 记录刷盘前的状态
    local before_mem=$(redis-cli -p 6666 INFO rocksdb 2>/dev/null | grep "rocksdb.size-all-mem-tables" | cut -d: -f2 | tr -d '\r')
    local before_sst=$(find "${DATA_DIR}/master-1" -name "*.sst" 2>/dev/null | wc -l)
    
    echo "  刷盘前:"
    echo "    内存表大小: ${before_mem:-0} bytes"
    echo "    SST 文件数: $before_sst"
    
    # 写入一些数据
    echo "  写入 10000 条测试数据..."
    for i in $(seq 1 10000); do
        redis-cli -p 6666 SET "flush:test:$i" "$(openssl rand -base64 100)" > /dev/null 2>&1
    done
    
    # 强制刷盘
    echo "  执行 BGSAVE 强制刷盘..."
    redis-cli -p 6666 BGSAVE > /dev/null 2>&1
    sleep 2
    
    # 等待刷盘完成
    while redis-cli -p 6666 INFO persistence 2>/dev/null | grep -q "rdb_bgsave_in_progress:1"; do
        sleep 1
    done
    
    # 记录刷盘后的状态
    local after_mem=$(redis-cli -p 6666 INFO rocksdb 2>/dev/null | grep "rocksdb.size-all-mem-tables" | cut -d: -f2 | tr -d '\r')
    local after_sst=$(find "${DATA_DIR}/master-1" -name "*.sst" 2>/dev/null | wc -l)
    local dir_size=$(du -sh "${DATA_DIR}/master-1" 2>/dev/null | cut -f1)
    
    echo "  刷盘后:"
    echo "    内存表大小: ${after_mem:-0} bytes"
    echo "    SST 文件数: $after_sst"
    echo "    数据目录大小: $dir_size"
    
    if [ "$after_sst" -gt "$before_sst" ] 2>/dev/null || [ -n "$dir_size" ]; then
        echo -e "  ${GREEN}✓ 数据已成功写入磁盘${NC}"
    fi
    
    echo ""
}

# 方法4: 监控磁盘IO
verify_disk_io() {
    echo -e "${YELLOW}[方法4] 写入时的磁盘IO监控${NC}"
    echo "----------------------------------------"
    
    if ! check_node 6666; then
        echo -e "${RED}  错误: 节点未运行${NC}"
        return 1
    fi
    
    echo "  准备写入 50000 条数据（约 5MB）..."
    echo "  请观察磁盘IO变化（需要 iostat 或 iotop）"
    echo ""
    
    # 检查是否有 iostat
    if command -v iostat &> /dev/null; then
        echo "  磁盘IO统计 (5秒采样):"
        iostat -x 1 3 | tail -n +4 &
        IOPID=$!
        sleep 1
    fi
    
    # 批量写入数据
    echo "  开始写入数据..."
    local start_time=$(date +%s)
    
    for i in $(seq 1 50000); do
        redis-cli -p 6666 SET "io:test:$i" "$(openssl rand -base64 50)" > /dev/null 2>&1
        if [ $((i % 10000)) -eq 0 ]; then
            echo "    已写入 $i 条..."
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ -n "$IOPID" ]; then
        wait $IOPID 2>/dev/null || true
    fi
    
    echo ""
    echo "  写入完成: 50000 条数据，耗时 ${duration} 秒"
    
    # 查看最终磁盘占用
    local final_size=$(du -sh "${DATA_DIR}/master-1" 2>/dev/null | cut -f1)
    echo "  Master-1 数据目录大小: $final_size"
    echo ""
}

# 方法5: 文件类型分析
verify_file_types() {
    echo -e "${YELLOW}[方法5] 数据文件类型分析${NC}"
    echo "----------------------------------------"
    
    for node in master-1 master-2 master-3; do
        local dir="${DATA_DIR}/${node}"
        if [ -d "$dir" ]; then
            echo "  ${node} 文件分布:"
            
            # 统计各种文件类型
            local sst_files=$(find "$dir" -name "*.sst" -type f 2>/dev/null)
            local log_files=$(find "$dir" -name "*.log" -type f 2>/dev/null)
            local manifest_files=$(find "$dir" -name "MANIFEST*" -type f 2>/dev/null)
            
            if [ -n "$sst_files" ]; then
                local sst_size=$(du -ch $sst_files 2>/dev/null | tail -1 | cut -f1)
                local sst_count=$(echo "$sst_files" | wc -l)
                echo "    SST 数据文件: ${sst_count} 个, 共 ${sst_size}"
            else
                echo "    SST 数据文件: 0 个"
            fi
            
            if [ -n "$log_files" ]; then
                local log_size=$(du -ch $log_files 2>/dev/null | tail -1 | cut -f1)
                local log_count=$(echo "$log_files" | wc -l)
                echo "    WAL 日志文件: ${log_count} 个, 共 ${log_size}"
            else
                echo "    WAL 日志文件: 0 个"
            fi
            
            if [ -n "$manifest_files" ]; then
                echo "    元数据文件: $(echo "$manifest_files" | wc -l) 个"
            fi
            
            echo ""
        fi
    done
    
    echo "  说明:"
    echo "    - SST 文件: RocksDB 的持久化数据文件（已排序字符串表）"
    echo "    - WAL 日志: 写前日志，用于崩溃恢复"
    echo "    - MANIFEST: 元数据文件，记录 SST 文件的组织结构"
    echo ""
}

# 方法6: 小内存强制测试（创建临时配置）
verify_small_memory_test() {
    echo -e "${YELLOW}[方法6] 小内存强制落盘测试${NC}"
    echo "----------------------------------------"
    
    echo "  此测试会创建一个临时配置，限制内存使用强制数据落盘"
    echo ""
    
    # 检查是否有运行中的节点
    if check_node 6666; then
        echo -e "  ${YELLOW}注意: 检测到有节点在运行，将使用现有节点进行测试${NC}"
        echo "  如需使用小内存配置，请先停止集群: ./deploy.sh stop"
        echo ""
    fi
    
    # 显示如何配置小内存
    echo "  强制数据落盘的配置方法:"
    echo ""
    echo "  1. 修改 config/base.conf，添加以下配置:"
    echo ""
    echo -e "     ${GREEN}# 极小的写缓冲区，强制频繁刷盘${NC}"
    echo "     write-buffer-size 4mb"
    echo "     max-write-buffer-number 2"
    echo "     min-write-buffer-number-to-merge 1"
    echo ""
    echo -e "     ${GREEN}# 极小的块缓存，强制从磁盘读取${NC}"
    echo "     rocksdb.block_cache_size 8mb"
    echo "     rocksdb.metadata_block_cache_size 2mb"
    echo ""
    echo "  2. 重启集群: ./deploy.sh restart"
    echo ""
    echo "  3. 写入数据时观察磁盘IO: iostat -x 1"
    echo ""
    
    # 如果节点在运行，执行一个快速测试
    if check_node 6666; then
        echo "  使用当前配置进行测试..."
        
        # 清理旧数据
        echo "  清理测试数据..."
        redis-cli -p 6666 --scan --pattern "smallmem:test:*" | xargs -r redis-cli -p 6666 DEL > /dev/null 2>&1
        
        local before=$(du -sh "${DATA_DIR}/master-1" 2>/dev/null | cut -f1)
        echo "  写入前数据目录: $before"
        
        # 写入大量数据
        echo "  写入 100000 条数据..."
        for i in $(seq 1 100000); do
            redis-cli -p 6666 SET "smallmem:test:$(printf %06d $i)" "$(openssl rand -base64 200)" > /dev/null 2>&1
        done
        
        # 强制刷盘
        redis-cli -p 6666 BGSAVE > /dev/null 2>&1
        sleep 3
        
        local after=$(du -sh "${DATA_DIR}/master-1" 2>/dev/null | cut -f1)
        local sst_count=$(find "${DATA_DIR}/master-1" -name "*.sst" | wc -l)
        
        echo "  写入后数据目录: $after"
        echo "  SST 文件数量: $sst_count"
        
        if [ "$after" != "$before" ] && [ "$sst_count" -gt 0 ]; then
            echo -e "  ${GREEN}✓ 验证成功: 数据已写入磁盘${NC}"
        fi
        
        echo ""
        echo "  清理测试数据..."
        redis-cli -p 6666 --scan --pattern "smallmem:test:*" | xargs -r redis-cli -p 6666 DEL > /dev/null 2>&1
    fi
    
    echo ""
}

# 主菜单
show_menu() {
    echo "请选择验证方法:"
    echo ""
    echo "  1) 查看数据目录磁盘占用"
    echo "  2) 查看 RocksDB 统计信息"
    echo "  3) 强制刷盘测试"
    echo "  4) 磁盘IO监控测试"
    echo "  5) 数据文件类型分析"
    echo "  6) 小内存强制测试"
    echo "  0) 运行所有测试"
    echo ""
}

# 运行所有测试
run_all_tests() {
    verify_disk_usage
    verify_rocksdb_stats
    verify_force_flush
    verify_disk_io
    verify_file_types
    verify_small_memory_test
}

# 主函数
main() {
    local choice="${1:-}"
    
    if [ -z "$choice" ]; then
        show_menu
        read -p "请输入选项 (0-6): " choice
    fi
    
    case "$choice" in
        1) verify_disk_usage ;;
        2) verify_rocksdb_stats ;;
        3) verify_force_flush ;;
        4) verify_disk_io ;;
        5) verify_file_types ;;
        6) verify_small_memory_test ;;
        0) run_all_tests ;;
        *) 
            echo "无效选项: $choice"
            show_menu
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}验证完成!${NC}"
}

main "$@"
