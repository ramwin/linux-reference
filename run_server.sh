#!/bin/bash
# Xiang Wang(ramwin@qq.com)

if [ -d _build ]
then
    rm -r _build
fi

sphinx-autobuild \
    -v \
    --host 0.0.0.0 \
    --port 18002 \
    . _build/html/ \
    --re-ignore "\.mypy_cache" \
    --re-ignore "_build" \
    --re-ignore "\.git"    \
    --re-ignore "_static"    \
    --re-ignore "\.*\.swp" \
    --re-ignore "terminal_link.json" \
    --re-ignore "terminal配置.json" \
    --re-ignore "software\/terminal\/.*" \
    --ignore "terminal_link.json" \
    --ignore "terminal配置.json" \
    --ignore "software/terminal/terminal_link.json" \
    --ignore "software/terminal/terminal配置.json" \
    --ignore "software/terminal/windows_5800.json" \
    --ignore "software/terminal/windows_5800_link.json" \
    --re-ignore "\.*\.log" \

    # -j auto \
