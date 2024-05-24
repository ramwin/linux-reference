#!/bin/bash
# Xiang Wang(ramwin@qq.com)

rm -r _build

sphinx-autobuild \
    -j auto \
    --port 18002 \
    . _build/html/ \
    --re-ignore "\.mypy_cache" \
    --re-ignore "\.git"    \
    --re-ignore "\.*\.swp"
