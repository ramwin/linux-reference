# Git Bundle 增量同步解决方案

## 问题描述
- 分支inner基于master节点A0，开发了A1, A2, A3, A4
- 已经将A1到A3打包成bundle_A123给同事C
- 同事B开发了B1并合并到master
- 将A4 rebase到B1后变成A1', A2', A3', A4'
- 需要将A4'发给同事C，但要避免重新传输A1', A2', A3'

## 解决方案：增量Bundle策略

### 方案1：仅打包A4'（推荐）

```bash
# 1. 在你的机器上，假设当前在inner分支上
# 找到A3'的commit hash
git log --oneline -n 5

# 2. 只打包A4'这一个提交（假设A3'的hash是abc123）
git bundle create bundle_A4_only.bundle abc123..HEAD

# 3. 将bundle_A4_only.bundle发送给同事C
```

### 同事C的操作流程：

```bash
# 1. 首先应用之前的bundle_A123（如果还没有应用）
git fetch bundle_A123.bundle refs/heads/inner:inner_old
git checkout inner_old

# 2. 应用新的增量bundle
git fetch bundle_A4_only.bundle refs/heads/inner:inner_new

# 3. 检查差异并合并
git log inner_old..inner_new --oneline
git checkout inner_new
```

### 方案2：基于已知点的增量bundle

如果同事C已经有了A1, A2, A3的内容，可以：

```bash
# 在你的机器上，创建从A3'到A4'的bundle
# 假设A3的原始hash是def456
git bundle create bundle_A4_incremental.bundle def456..HEAD
```

### 方案3：使用--since参数

```bash
# 基于时间的增量bundle（如果知道A3的提交时间）
git bundle create bundle_recent.bundle --since="2024-01-01" HEAD
```

## 验证Bundle内容

```bash
# 查看bundle包含的内容
git bundle list-heads bundle_A4_only.bundle
git bundle verify bundle_A4_only.bundle

# 查看bundle的大小
ls -lh *.bundle
```

## 最佳实践建议

1. **记录提交点**：每次创建bundle时记录base commit，方便后续增量操作
2. **使用标签**：在关键节点打标签，便于引用
3. **测试验证**：在本地模拟同事C的操作流程进行验证

## 示例脚本

```bash
#!/bin/bash
# create_incremental_bundle.sh

# 参数检查
if [ $# -ne 2 ]; then
    echo "Usage: $0 <base_commit> <target_branch>"
    echo "Example: $0 abc123 inner"
    exit 1
fi

BASE_COMMIT=$1
TARGET_BRANCH=$2
BUNDLE_NAME="bundle_incremental_$(date +%Y%m%d_%H%M%S).bundle"

# 创建增量bundle
git bundle create "$BUNDLE_NAME" "$BASE_COMMIT..$TARGET_BRANCH"

# 验证bundle
if git bundle verify "$BUNDLE_NAME"; then
    echo "✅ Bundle created successfully: $BUNDLE_NAME"
    echo "📦 Bundle size: $(ls -lh "$BUNDLE_NAME" | awk '{print $5}')"
    echo "📋 Bundle contents:"
    git bundle list-heads "$BUNDLE_NAME"
else
    echo "❌ Bundle verification failed"
    exit 1
fi
```

## 注意事项

1. 确保base_commit在同事C那边已经存在
2. 如果A1', A2', A3'与原来的A1, A2, A3内容完全不同，增量bundle可能仍然很大
3. 考虑使用Git的`--thin`选项来进一步减小bundle大小
4. 建议在传输前压缩bundle文件