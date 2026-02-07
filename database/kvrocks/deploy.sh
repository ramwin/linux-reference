#!/bin/bash
# Kvrocks 高可用集群部署脚本
# 支持：启动、停止、重启、状态检查、数据备份、扩容等功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
Kvrocks 高可用集群管理脚本

用法: $0 <命令> [选项]

命令:
    start       启动集群
    stop        停止集群
    restart     重启集群
    status      查看集群状态
    logs        查看日志 (用法: $0 logs [服务名])
    backup      备份所有节点数据
    cleanup     清理所有数据和日志 (⚠️ 危险操作)
    scale-up    扩容集群（添加新节点）
    benchmark   性能测试
    help        显示此帮助信息

示例:
    $0 start                    # 启动集群
    $0 stop                     # 停止集群
    $0 logs kvrocks-master-1    # 查看 master-1 的日志
    $0 backup                   # 备份数据到 backup/ 目录
    $0 status                   # 查看集群健康状态

数据目录: ./data/
备份目录: ./backup/
日志获取: docker logs <容器名>
EOF
}

# 检查 Docker 环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查 Docker 服务是否运行
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker 服务"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
}

# 创建必要目录
init_dirs() {
    mkdir -p data/{master-1,master-2,master-3,replica-1,replica-2,replica-3}
    mkdir -p backup
    mkdir -p logs
    print_success "目录初始化完成"
}

# 启动集群
start_cluster() {
    print_info "正在启动 Kvrocks 集群..."
    
    check_docker
    init_dirs
    
    # 检查 docker-compose 命令
    if docker-compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # 拉取最新镜像
    print_info "拉取 Kvrocks 镜像..."
    $COMPOSE_CMD pull
    
    # 启动服务
    print_info "启动集群服务..."
    $COMPOSE_CMD up -d
    
    # 等待集群初始化
    print_info "等待集群初始化完成..."
    sleep 5
    
    # 检查集群状态
    print_info "检查集群状态..."
    sleep 3
    
    # 显示集群信息
    show_cluster_status
    
    print_success "集群启动完成！"
    echo ""
    echo "连接信息:"
    echo "  - Master-1: localhost:6666"
    echo "  - Master-2: localhost:6667"
    echo "  - Master-3: localhost:6668"
    echo "  - Replica-1: localhost:6669"
    echo "  - Replica-2: localhost:6670"
    echo "  - Replica-3: localhost:6671"
    echo ""
    echo "使用以下命令连接集群:"
    echo "  redis-cli -c -p 6666"
    echo ""
}

# 停止集群
stop_cluster() {
    print_info "正在停止 Kvrocks 集群..."
    
    if docker-compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    $COMPOSE_CMD down
    print_success "集群已停止"
}

# 重启集群
restart_cluster() {
    print_info "正在重启 Kvrocks 集群..."
    stop_cluster
    sleep 2
    start_cluster
}

# 显示集群状态
show_cluster_status() {
    echo ""
    echo "========================================"
    echo "         Kvrocks 集群状态"
    echo "========================================"
    echo ""
    
    # 检查容器状态
    echo "【容器状态】"
    docker ps --filter "name=kvrocks" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  无运行中的容器"
    echo ""
    
    # 检查节点健康
    echo "【节点健康检查】"
    for port in 6666 6667 6668 6669 6670 6671; do
        if redis-cli -p $port ping 2>/dev/null | grep -q "PONG"; then
            role=$(redis-cli -p $port info replication 2>/dev/null | grep "role:" | cut -d: -f2 | tr -d '\r')
            echo "  ✓ Port $port: $role - 正常"
        else
            echo "  ✗ Port $port: 无法连接"
        fi
    done
    echo ""
    
    # 集群信息
    echo "【集群状态】"
    cluster_info=$(redis-cli -p 6666 cluster info 2>/dev/null || echo "")
    if echo "$cluster_info" | grep -q "cluster_state:ok"; then
        echo "  ✓ 集群状态: 正常"
        echo "  - 节点数: $(echo "$cluster_info" | grep "cluster_known_nodes:" | cut -d: -f2 | tr -d '\r')"
        echo "  - 分片数: $(echo "$cluster_info" | grep "cluster_size:" | cut -d: -f2 | tr -d '\r')"
    else
        echo "  ! 集群未初始化或异常"
    fi
    echo ""
    
    # 集群节点列表
    echo "【节点列表】"
    redis-cli -p 6666 cluster nodes 2>/dev/null | while read line; do
        node_id=$(echo $line | awk '{print $1}')
        addr=$(echo $line | awk '{print $2}')
        flags=$(echo $line | awk '{print $3}')
        master_id=$(echo $line | awk '{print $4}')
        ping_sent=$(echo $line | awk '{print $5}')
        pong_recv=$(echo $line | awk '{print $6}')
        epoch=$(echo $line | awk '{print $7}')
        state=$(echo $line | awk '{print $8}')
        slots=$(echo $line | awk '{print $9}')
        
        if echo "$flags" | grep -q "master"; then
            echo "  [主] $addr - $state - Slots: $slots"
        elif echo "$flags" | grep -q "slave"; then
            echo "  [从] $addr - $state - 主节点: ${master_id:0:8}..."
        fi
    done
    echo ""
    echo "========================================"
}

# 查看日志
show_logs() {
    service_name=$1
    if [ -z "$service_name" ]; then
        print_info "显示所有服务日志..."
        if docker-compose version &> /dev/null; then
            docker-compose logs -f --tail=100
        else
            docker compose logs -f --tail=100
        fi
    else
        print_info "显示 $service_name 日志..."
        docker logs -f --tail=100 "$service_name" 2>/dev/null || print_error "服务 $service_name 不存在或未运行"
    fi
}

# 备份数据
backup_data() {
    print_info "开始备份 Kvrocks 数据..."
    
    backup_dir="backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    for node in master-1 master-2 master-3 replica-1 replica-2 replica-3; do
        print_info "备份 $node ..."
        if [ -d "data/$node" ]; then
            tar czf "$backup_dir/${node}.tar.gz" -C data "$node"
            print_success "$node 备份完成"
        else
            print_warning "$node 数据目录不存在，跳过"
        fi
    done
    
    # 备份配置
    cp -r config "$backup_dir/"
    
    print_success "所有数据已备份到: $backup_dir"
    echo "备份内容:"
    ls -lh "$backup_dir"
}

# 清理数据
cleanup_data() {
    echo ""
    print_warning "⚠️  警告: 此操作将删除所有数据和日志，且无法恢复！"
    echo ""
    read -p "确定要继续吗？输入 'yes' 确认: " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        return
    fi
    
    print_info "停止集群..."
    if docker-compose version &> /dev/null; then
        docker-compose down -v
    else
        docker compose down -v
    fi
    
    print_info "清理数据目录..."
    rm -rf data/*
    
    print_success "清理完成"
}

# 性能测试
run_benchmark() {
    print_info "运行 Kvrocks 性能测试..."
    
    if ! command -v redis-benchmark &> /dev/null; then
        print_error "redis-benchmark 未安装，请先安装 Redis 工具"
        exit 1
    fi
    
    echo ""
    echo "测试配置:"
    echo "  - 连接端口: 6666 (集群模式)"
    echo "  - 并发客户端: 50"
    echo "  - 每客户端请求: 100000"
    echo "  - 数据大小: 128 bytes"
    echo ""
    
    redis-benchmark -p 6666 -c 50 -n 100000 -d 128 --cluster
}

# 主函数
main() {
    case "${1:-help}" in
        start)
            start_cluster
            ;;
        stop)
            stop_cluster
            ;;
        restart)
            restart_cluster
            ;;
        status)
            show_cluster_status
            ;;
        logs)
            show_logs "$2"
            ;;
        backup)
            backup_data
            ;;
        cleanup)
            cleanup_data
            ;;
        benchmark)
            run_benchmark
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
