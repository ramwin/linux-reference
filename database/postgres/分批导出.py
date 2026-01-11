#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang <ramwin@qq.com>


import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import Optional, List


class PostgreSQLBatchExporter:
    """PostgreSQL 分批导出工具类"""

    def __init__(self, host: str, dbname: str, user: str, password: Optional[str] = None, port: int = 5432):
        """
        初始化导出器

        Args:
            host: 数据库主机
            dbname: 数据库名
            user: 用户名
            password: 密码（可选，推荐用 .pgpass 文件）
            port: 端口，默认 5432
        """
        self.host = host
        self.dbname = dbname
        self.user = user
        self.password = password
        self.port = port
        self.output_dir = None

    def export_table(self, table_name: str, batch_size: int = 10000,
                     primary_key: Optional[str] = None, output_dir: Optional[str] = None) -> Path:
        """
        导出表结构和分批数据

        Args:
            table_name: 要导出的表名
            batch_size: 每批导出的行数
            primary_key: 主键字段名，不指定则自动检测
            output_dir: 输出目录，默认创建带时间戳的目录

        Returns:
            输出目录的 Path 对象
        """
        # 创建输出目录
        if output_dir is None:
            output_dir = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        print(f"📦 开始导出表 `{table_name}` 到 {self.output_dir}")

        # 导出表结构
        self._export_schema(table_name)

        # 分批导出数据
        batch_files = self._export_data_batches(table_name, batch_size, primary_key)

        # 生成导入脚本
        self._generate_import_script(table_name, batch_files)

        print(f"✅ 导出完成！共 {len(batch_files)} 个数据文件\n")
        return self.output_dir

    def _export_schema(self, table_name: str):
        """导出表结构（带 IF NOT EXISTS）"""
        schema_file = self.output_dir / f"00_{table_name}_schema.sql"

        cmd = self._build_pg_dump_cmd(
            table_name,
            extra_args=["--schema-only", "-f", str(schema_file)]
        )

        self._run_command(cmd, f"  ✓ 表结构: {schema_file.name}")

    def _export_data_batches(self, table_name: str, batch_size: int,
                            primary_key: Optional[str]) -> List[str]:
        """分批导出数据"""
        # 获取总行数和主键范围
        total_rows, min_id, max_id = self._get_table_stats(table_name, primary_key)

        if total_rows == 0:
            print("  ⚠️  表中没有数据\n")
            return []

        print(f"  📊 总行数: {total_rows:,}, ID范围: {min_id} - {max_id}")

        batch_files = []
        current_id = min_id
        batch_num = 1

        # 按主键范围分批
        while current_id <= max_id:
            file_name = f"{batch_num:03d}_{table_name}_data.sql"
            batch_file = self.output_dir / file_name

            where_clause = f"\"{primary_key}\" >= {current_id} AND \"{primary_key}\" < {current_id + batch_size}"

            cmd = self._build_pg_dump_cmd(
                table_name,
                extra_args=[
                    "--data-only",
                    "--where", where_clause,
                    "-f", str(batch_file)
                ]
            )

            # 只导出非空批次
            batch_rows = self._get_batch_count(table_name, primary_key, current_id, current_id + batch_size)
            if batch_rows > 0:
                self._run_command(cmd, f"    第{batch_num:3d}批: {current_id:8d} - {current_id + batch_size:8d} ({batch_rows:6,}行)")
                batch_files.append(file_name)

            current_id += batch_size
            batch_num += 1

        return batch_files

    def _build_pg_dump_cmd(self, table_name: str, extra_args: List[str]) -> List[str]:
        """构建 pg_dump 命令"""
        cmd = [
            "pg_dump",
            "--host", self.host,
            "--dbname", self.dbname,
            "--username", self.user,
            "--port", str(self.port),
            "--table", table_name,
            "--no-owner",
            "--no-acl",
            "--rows-per-insert", "1000",
        ]
        cmd.extend(extra_args)
        return cmd

    def _run_command(self, cmd: List[str], success_msg: str):
        """执行命令并处理错误"""
        env = os.environ.copy()
        if self.password:
            env['PGPASSWORD'] = self.password

        try:
            subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
            print(success_msg)
        except subprocess.CalledProcessError as e:
            print(f"\n❌ 命令执行失败:")
            print(f"   命令: {' '.join(cmd)}")
            print(f"   错误: {e.stderr}\n")
            raise

    def _get_table_stats(self, table_name: str, primary_key: Optional[str]) -> tuple:
        """获取表统计信息"""
        sql = f"""
            SELECT
                COUNT(*),
                COALESCE(MIN("{primary_key}"), 0),
                COALESCE(MAX("{primary_key}"), 0)
            FROM {table_name}
        """
        return self._execute_sql_one_row(sql)

    def _get_batch_count(self, table_name: str, primary_key: str, start_id: int, end_id: int) -> int:
        """获取批次行数"""
        sql = f"""
            SELECT COUNT(*)
            FROM {table_name}
            WHERE "{primary_key}" >= {start_id} AND "{primary_key}" < {end_id}
        """
        return self._execute_sql_one_row(sql)[0]

    def _execute_sql_one_row(self, sql: str) -> tuple:
        """执行SQL并返回单行结果"""
        env = os.environ.copy()
        if self.password:
            env['PGPASSWORD'] = self.password

        cmd = [
            "psql",
            "-h", self.host,
            "-p", str(self.port),
            "-U", self.user,
            "-d", self.dbname,
            "-t", "-A", "-c", sql
        ]

        result = subprocess.run(cmd, env=env, capture_output=True, text=True, check=True)
        return tuple(map(int, result.stdout.strip().split('|')))

    def _generate_import_script(self, table_name: str, batch_files: List[str]):
        """生成导入脚本"""
        script_file = self.output_dir / "import.sh"

        script_lines = [
            "#!/bin/bash",
            f"# PostgreSQL 导入脚本 - 表: {table_name}",
            f"# 数据文件数: {len(batch_files)}",
            "set -e",
            "",
            f'DB_NAME="{self.dbname}"',
            f'HOST="{self.host}"',
            f'USER="{self.user}"',
            "echo \"📥 开始导入...\"",
            "",
            "# 1. 导入表结构（自动跳过已存在）",
            "echo \"📦 导入表结构...\"",
            f"psql -h \"$HOST\" -U \"$USER\" -d \"$DB_NAME\" -f 00_{table_name}_schema.sql",
            "",
            "# 2. 导入数据",
            "echo \"📊 导入数据...\"",
        ]

        # 为每个文件生成导入命令
        for file_name in batch_files:
            script_lines.extend([
                f"echo \"  📄 {file_name}\"",
                f"psql -h \"$HOST\" -U \"$USER\" -d \"$DB_NAME\" -f {file_name}"
            ])

        script_lines.extend([
            "",
            "echo \"✅ 导入完成！\"",
            f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM {table_name};"'
        ])

        script_content = "\n".join(script_lines)
        script_file.write_text(script_content)
        script_file.chmod(0o755)

        print(f"  ✓ 导入脚本: {script_file.name}\n")


# ============== 使用示例 ==============
if __name__ == "__main__":
    # 配置数据库连接
    exporter = PostgreSQLBatchExporter(
        host="localhost",
        dbname="schoolproject",
        user="postgres",
        password="your_password",  # 留空则使用 ~/.pgpass
        port=5432
    )

    # 导出表（自动检测主键）
    try:
        output_dir = exporter.export_table(
            table_name="school_student",
            batch_size=5000  # 每批5000条
        )
        print(f"🎯 输出目录: {output_dir}")
        print("📜 导入命令: cd", output_dir, "&& bash import.sh")
    except Exception as e:
        print(f"❌ 导出失败: {e}")
