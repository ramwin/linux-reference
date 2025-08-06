#!/bin/bash

# Git Bundle 增量应用脚本
# 用于应用增量bundle到本地仓库

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
    echo "Git Bundle 增量应用脚本"
    echo ""
    echo "用法:"
    echo "  $0 [选项] BUNDLE_FILE"
    echo ""
    echo "选项:"
    echo "  -b, --branch BRANCH   目标分支名 (默认: 从bundle中推断)"
    echo "  -n, --new-branch      创建新分支而不是更新现有分支"
    echo "  -p, --preview         预览模式，只显示将要应用的提交"
    echo "  -h, --help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 bundle_inner_20241201_143022.bundle"
    echo "  $0 -b inner -n bundle_A4_only.bundle"
    echo "  $0 --preview bundle_incremental.bundle"
    echo ""
    echo "注意:"
    echo "  在应用bundle之前，请确保你已经应用了之前的bundle_A123"
}

# 默认值
BUNDLE_FILE=""
TARGET_BRANCH=""
CREATE_NEW_BRANCH=false
PREVIEW_MODE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        -n|--new-branch)
            CREATE_NEW_BRANCH=true
            shift
            ;;
        -p|--preview)
            PREVIEW_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "未知参数: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$BUNDLE_FILE" ]]; then
                BUNDLE_FILE="$1"
            else
                print_error "只能指定一个bundle文件"
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查必需参数
if [[ -z "$BUNDLE_FILE" ]]; then
    print_error "必须指定bundle文件"
    show_help
    exit 1
fi

# 检查bundle文件是否存在
if [[ ! -f "$BUNDLE_FILE" ]]; then
    print_error "Bundle文件不存在: $BUNDLE_FILE"
    exit 1
fi

# 解压bundle文件（如果是压缩的）
ORIGINAL_BUNDLE="$BUNDLE_FILE"
if [[ "$BUNDLE_FILE" == *.gz ]]; then
    print_info "检测到压缩的bundle文件，正在解压..."
    UNCOMPRESSED_FILE="${BUNDLE_FILE%.gz}"
    if [[ ! -f "$UNCOMPRESSED_FILE" ]]; then
        gunzip -k "$BUNDLE_FILE"
    fi
    BUNDLE_FILE="$UNCOMPRESSED_FILE"
    print_success "解压完成: $BUNDLE_FILE"
fi

print_info "开始处理bundle: $BUNDLE_FILE"

# 验证bundle
print_info "正在验证bundle..."
if ! git bundle verify "$BUNDLE_FILE"; then
    print_error "Bundle验证失败"
    exit 1
fi
print_success "Bundle验证通过"

# 获取bundle中的分支信息
print_info "Bundle中包含的分支:"
BUNDLE_HEADS=$(git bundle list-heads "$BUNDLE_FILE")
echo "$BUNDLE_HEADS"

# 如果没有指定目标分支，尝试从bundle中推断
if [[ -z "$TARGET_BRANCH" ]]; then
    # 提取第一个分支名
    TARGET_BRANCH=$(echo "$BUNDLE_HEADS" | head -n1 | awk '{print $2}' | sed 's|refs/heads/||')
    if [[ -z "$TARGET_BRANCH" ]]; then
        print_error "无法从bundle中推断分支名，请使用 -b/--branch 指定"
        exit 1
    fi
    print_info "推断的目标分支: $TARGET_BRANCH"
fi

# 预览模式
if [[ "$PREVIEW_MODE" == true ]]; then
    print_info "预览模式 - 显示bundle中的提交:"
    
    # 创建临时分支来查看提交
    TEMP_BRANCH="temp_preview_$(date +%s)"
    git fetch "$BUNDLE_FILE" "refs/heads/$TARGET_BRANCH:$TEMP_BRANCH"
    
    echo
    print_info "Bundle中的新提交:"
    if git show-branch --current "$TEMP_BRANCH" 2>/dev/null | grep -q "\[$TEMP_BRANCH\]"; then
        git log --oneline --graph "$TEMP_BRANCH" ^HEAD 2>/dev/null || git log --oneline "$TEMP_BRANCH" -10
    else
        git log --oneline "$TEMP_BRANCH" -10
    fi
    
    # 清理临时分支
    git branch -D "$TEMP_BRANCH"
    
    echo
    print_info "预览完成。要应用bundle，请重新运行脚本而不使用 --preview 选项"
    exit 0
fi

# 检查当前状态
if [[ -n "$(git status --porcelain)" ]]; then
    print_warning "工作目录不干净，建议先提交或暂存更改"
    echo "未提交的更改:"
    git status --short
    echo
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi
fi

# 应用bundle
if [[ "$CREATE_NEW_BRANCH" == true ]]; then
    # 创建新分支
    NEW_BRANCH_NAME="${TARGET_BRANCH}_$(date +%Y%m%d_%H%M%S)"
    print_info "创建新分支: $NEW_BRANCH_NAME"
    
    git fetch "$BUNDLE_FILE" "refs/heads/$TARGET_BRANCH:$NEW_BRANCH_NAME"
    git checkout "$NEW_BRANCH_NAME"
    
    print_success "成功创建并切换到新分支: $NEW_BRANCH_NAME"
else
    # 更新现有分支或创建分支
    print_info "应用bundle到分支: $TARGET_BRANCH"
    
    # 检查分支是否存在
    if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
        # 分支存在，更新它
        CURRENT_BRANCH=$(git branch --show-current)
        
        if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
            # 当前就在目标分支上
            git fetch "$BUNDLE_FILE" "refs/heads/$TARGET_BRANCH"
            git merge FETCH_HEAD
        else
            # 在其他分支上，先切换
            git fetch "$BUNDLE_FILE" "refs/heads/$TARGET_BRANCH:$TARGET_BRANCH"
            git checkout "$TARGET_BRANCH"
        fi
    else
        # 分支不存在，创建它
        git fetch "$BUNDLE_FILE" "refs/heads/$TARGET_BRANCH:$TARGET_BRANCH"
        git checkout "$TARGET_BRANCH"
    fi
    
    print_success "成功应用bundle到分支: $TARGET_BRANCH"
fi

# 显示应用后的状态
echo
print_info "应用后的分支状态:"
git log --oneline --graph -5

echo
print_success "Bundle应用完成！"

# 清理解压的文件（如果原文件是压缩的）
if [[ "$ORIGINAL_BUNDLE" != "$BUNDLE_FILE" && "$ORIGINAL_BUNDLE" == *.gz ]]; then
    read -p "是否删除解压后的bundle文件 $BUNDLE_FILE? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$BUNDLE_FILE"
        print_info "已删除解压后的文件: $BUNDLE_FILE"
    fi
fi