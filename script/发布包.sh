#!/bin/bash
# Xiang Wang(ramwin@qq.com)

rm -rf dist/*
# hatch build
# hatch publish
#
python3 -m build
twine upload dist/*

# python3 setup.py sdist bdist_wheel
# twine upload -r dist/*
