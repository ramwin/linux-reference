#!/usr/bin/env bash
# 把一篇文档丢给可用的外部模型做校对,结果落到 reviews/YYYY-MM-DD-<slug>.md
# 用法: ./external_review.sh architecture.md "七阶段契约是否过度设计"
set -uo pipefail
cd "$(dirname "$0")"

doc=${1:-}
focus=${2:-"重点看事实断言是否过时、结论的失效条件"}
if [[ -z "$doc" || ! -f "$doc" ]]; then
    echo "用法: ./external_review.sh <文档.md> [焦点]" >&2
    exit 1
fi

# 本机坑:no_proxy 里的 [::1] 会让 httpx 抛 InvalidURL: Invalid port ':1]'
export no_proxy="localhost,127.0.0.1,::1" NO_PROXY="localhost,127.0.0.1,::1"

PROMPT="你是外部评审,不是作者。下面是一篇中文技术文档,主题是多智能体测试平台(验收端)。
请只回答三件事,不要复述原文,不要客套:
1. 你认为可能错误或过时的事实断言(逐条列,给一手依据链接;给不出就写\"无\");
2. 最强反例:在什么前提/规模下,文中的结论会失效;
3. 不超过 3 条可落地的修改建议。
焦点:$focus

=== 文档正文 ===
$(cat "$doc")"

slug=$(basename "$doc" .md)
out="reviews/$(date +%F)-${slug}.md"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

model=""
answer=""

if command -v kimi >/dev/null 2>&1; then
    echo "→ 尝试 Kimi ..." >&2
    if answer=$(cd "$work" && timeout 300 kimi -p "$PROMPT" 2>"$work/err"); then
        if grep -q "Authorization failed\|401" <<<"$answer" || grep -q "Authorization failed" "$work/err"; then
            echo "  Kimi 凭据过期(401),跳过。终端跑 kimi 后输入 /login 重新授权。" >&2
            answer=""
        else
            model="Kimi(kimi-code CLI)"
        fi
    else
        echo "  Kimi 调用失败,跳过:" >&2; tail -3 "$work/err" >&2; answer=""
    fi
fi

if [[ -z "$answer" ]] && command -v claude >/dev/null 2>&1; then
    echo "→ 尝试 Claude ..." >&2
    if answer=$(cd "$work" && timeout 300 claude -p "$PROMPT" 2>"$work/err2"); then
        model="Claude(CLI)"
    else
        echo "  Claude 调用失败,跳过:" >&2; tail -3 "$work/err2" >&2; answer=""
    fi
fi

if [[ -z "$answer" ]]; then
    cat >&2 <<'EOF'
没有可用的外部模型 CLI。两条路:
  1. 终端跑 `kimi`,输入 /login 重新授权(本机 Kimi 凭据已过期);
     或按 ai/agent-testing-platform/external-review.md 装好 Claude CLI;
  2. 把本文档正文 + 该文件里的「提问模板」粘到任意网页版模型,回答贴回 reviews/。
EOF
    exit 2
fi

{
    echo "# 外部校对:${doc}"
    echo
    echo "- 模型:$model"
    echo "- 日期:$(date +%F)"
    echo "- 焦点:$focus"
    echo "- 原文:[${doc}](./../${doc})"
    echo
    echo "> 本文件是外部模型的原始输出,未做裁决。裁决与回写按 reviews/_TEMPLATE.md 走。"
    echo
    echo "---"
    echo
    echo "$answer"
} > "$out"

echo "已写入 $out" >&2
