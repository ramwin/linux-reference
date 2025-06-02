#!/bin/bash
# Xiang Wang(ramwin@qq.com)

if [ -d _build ]
then
    rm -r _build
fi

sphinx-autobuild \
    --host 0.0.0.0 \
    -j auto \
    --port 18002 \
    . _build/html/ \
    --re-ignore "\.mypy_cache" \
    --re-ignore "\.git"    \
    --re-ignore "\.*\.swp" \
    --re-ignore "\.*\.log" \
