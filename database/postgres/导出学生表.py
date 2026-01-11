#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang <ramwin@qq.com>

from 分批导出 import PostgreSQLBatchExporter

if __name__ == "__main__":
    PostgreSQLBatchExporter(
        host="",
        dbname="schoolproject",
        user="",
        password=None,  # 使用 ~/.pgpass
        port=5432,
    ).export_table("school_student", batch_size=500)
