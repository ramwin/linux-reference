#!/bin/bash

# Git Bundle 增量同步脚本
# 用于解决rebase后的增量同步问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 显示帮助信息
show_help() {
    echo "Git Bundle 增量同步脚本"
    echo ""
    echo "用法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -b, --base COMMIT     基础提交点 (必需)"
    echo "  -t, --target BRANCH   目标分支 (默认: 当前分支)"
    echo "  -o, --output FILE     输出文件名 (默认: 自动生成)"
    echo "  -c, --compress        压缩bundle文件"
    echo "  -h, --help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -b abc123 -t inner"
    echo "  $0 --base HEAD~1 --output my_bundle.bundle --compress"
    echo ""
    echo "场景说明:"
    echo "  当你rebase了分支后，想要只发送新的提交给同事，"
    echo "  而不是重新发送整个分支的内容。"
}

# 默认值
BASE_COMMIT=""
TARGET_BRANCH=""
OUTPUT_FILE=""
COMPRESS=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--base)
            BASE_COMMIT="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必需参数
if [[ -z "$BASE_COMMIT" ]]; then
    print_error "必须指定基础提交点 (-b/--base)"
    show_help
    exit 1
fi

# 获取当前分支作为默认目标分支
if [[ -z "$TARGET_BRANCH" ]]; then
    TARGET_BRANCH=$(git branch --show-current)
    if [[ -z "$TARGET_BRANCH" ]]; then
        print_error "无法确定当前分支，请使用 -t/--target 指定目标分支"
        exit 1
    fi
fi

# 生成默认输出文件名
if [[ -z "$OUTPUT_FILE" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT_FILE="bundle_${TARGET_BRANCH}_${TIMESTAMP}.bundle"
fi

print_info "开始创建增量bundle..."
print_info "基础提交: $BASE_COMMIT"
print_info "目标分支: $TARGET_BRANCH"
print_info "输出文件: $OUTPUT_FILE"

# 验证基础提交是否存在
if ! git rev-parse --verify "$BASE_COMMIT" >/dev/null 2>&1; then
    print_error "基础提交 '$BASE_COMMIT' 不存在"
    exit 1
fi

# 验证目标分支是否存在
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    print_error "目标分支 '$TARGET_BRANCH' 不存在"
    exit 1
fi

# 检查是否有新的提交
COMMIT_COUNT=$(git rev-list --count "$BASE_COMMIT..$TARGET_BRANCH")
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
    print_warning "从 '$BASE_COMMIT' 到 '$TARGET_BRANCH' 没有新的提交"
    exit 0
fi

print_info "发现 $COMMIT_COUNT 个新提交:"
git log --oneline "$BASE_COMMIT..$TARGET_BRANCH"
echo

# 创建bundle
print_info "正在创建bundle..."
if git bundle create "$OUTPUT_FILE" "$BASE_COMMIT..$TARGET_BRANCH"; then
    print_success "Bundle创建成功: $OUTPUT_FILE"
else
    print_error "Bundle创建失败"
    exit 1
fi

# 验证bundle
print_info "正在验证bundle..."
if git bundle verify "$OUTPUT_FILE"; then
    print_success "Bundle验证通过"
else
    print_error "Bundle验证失败"
    exit 1
fi

# 显示bundle信息
BUNDLE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
print_info "Bundle大小: $BUNDLE_SIZE"

print_info "Bundle包含的分支:"
git bundle list-heads "$OUTPUT_FILE"

# 压缩bundle (如果需要)
if [[ "$COMPRESS" == true ]]; then
    print_info "正在压缩bundle..."
    if command -v gzip >/dev/null 2>&1; then
        gzip -k "$OUTPUT_FILE"
        COMPRESSED_FILE="${OUTPUT_FILE}.gz"
        COMPRESSED_SIZE=$(ls -lh "$COMPRESSED_FILE" | awk '{print $5}')
        print_success "压缩完成: $COMPRESSED_FILE (大小: $COMPRESSED_SIZE)"
    else
        print_warning "gzip命令不可用，跳过压缩"
    fi
fi

echo
print_success "增量bundle创建完成！"
echo
print_info "接下来的步骤:"
echo "1. 将 $OUTPUT_FILE 发送给同事C"
echo "2. 同事C执行以下命令应用bundle:"
echo "   git fetch $OUTPUT_FILE refs/heads/$TARGET_BRANCH:${TARGET_BRANCH}_new"
echo "   git checkout ${TARGET_BRANCH}_new"
echo
print_info "或者同事C可以使用以下命令直接更新现有分支:"
echo "   git fetch $OUTPUT_FILE refs/heads/$TARGET_BRANCH:$TARGET_BRANCH"