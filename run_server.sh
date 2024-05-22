#!/bin/bash
# Xiang Wang(ramwin@qq.com)

rm -r _build

# wsl下
# 这样都会忽略
# sphinx-autobuild -j auto --port 18002 . _build/html/ --re-ignore _build --re-ignore .git
# 这样git status也会刷新
sphinx-autobuild -j auto --port 18002 . _build/html/ --re-ignore _build
