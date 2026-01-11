#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess
import os
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Tuple, Union


class PostgreSQLBatchExporter:
    """PostgreSQL 分批导出工具类（支持任意主键类型 & 稀疏表）"""

    def __init__(
        self,
        host: str,
        dbname: str,
        user: str,
        password: Optional[str] = None,
        port: int = 5432,
    ) -> None:
        self.host = host
        self.dbname = dbname
        self.user = user
        self.password = password
        self.port = port
        self.output_dir: Path = Path.cwd()

    # -------------------- 对外唯一入口 --------------------
    def export_table(
        self,
        table_name: str,
        batch_size: int = 10_000,
        primary_key: Optional[str] = None,
        output_dir: Optional[str] = None,
    ) -> Path:
        if output_dir is None:
            self.output_dir = Path(f"backup_{datetime.now():%Y%m%d_%H%M%S}")
        else:
            self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        print(f"📦 开始导出表 `{table_name}` 到 {self.output_dir}")

        # 1. 结构
        self._export_schema(table_name)

        # 2. 数据
        batch_files = self._export_data_batches(table_name, batch_size, primary_key)

        # 3. 导入脚本
        self._generate_import_script(table_name, batch_files)

        print(f"✅ 导出完成！共 {len(batch_files)} 个数据文件\n")
        return self.output_dir

    # -------------------- 内部实现 --------------------
    def _export_schema(self, table_name: str) -> None:
        schema_file = self.output_dir / f"00_{table_name}_schema.sql"
        cmd = self._build_pg_dump_cmd(
            table_name, extra_args=["--schema-only", "-f", str(schema_file)]
        )
        self._run_command(cmd, f"  ✓ 表结构: {schema_file.name}")

    def _export_data_batches(
        self,
        table_name: str,
        batch_size: int,
        primary_key: Optional[str],
    ) -> List[str]:
        pk = primary_key or self._detect_primary_key(table_name)
        if pk is None:
            raise RuntimeError(f"表 {table_name} 无主键，也无法自动检测，请手动指定 primary_key 参数")

        total_rows = self._get_total_rows(table_name)
        if total_rows == 0:
            print("  ⚠️  表中没有数据\n")
            return []

        print(f"  📊 总行数: {total_rows:,}, 每批约 {batch_size:,} 条")

        batch_files: List[str] = []
        offset = 0
        batch_num = 1

        while offset < total_rows:
            # 取当前批次「边界主键」
            lower_key, upper_key = self._get_key_boundary(
                table_name, pk, offset, batch_size
            )
            if lower_key is None:  # 最后一批可能不足 batch_size
                break

            file_name = f"{batch_num:03d}_{table_name}_data.sql"
            batch_file = self.output_dir / file_name

            where = f'"{pk}" >= {self._quote_if_str(lower_key)} AND "{pk}" < {self._quote_if_str(upper_key)}'
            cmd = self._build_pg_dump_cmd(
                table_name,
                extra_args=["--data-only", "--where", where, "-f", str(batch_file)],
            )
            self._run_command(
                cmd,
                f"    第{batch_num:3d}批: {lower_key} ≤ {pk} < {upper_key}",
            )
            batch_files.append(file_name)

            offset += batch_size
            batch_num += 1

        return batch_files

    # ---------- 工具 ----------
    def _quote_if_str(self, v: Union[str, int]) -> str:
        return f"'{v}'" if isinstance(v, str) else str(v)

    def _detect_primary_key(self, table: str) -> Optional[str]:
        sql = f"""
        SELECT a.attname::text
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = '{table}'::regclass
          AND i.indisprimary
        LIMIT 1;
        """
        row = self._execute_sql_one_row_optional(sql)
        return row[0] if row else None

    def _get_total_rows(self, table: str) -> int:
        sql = f"SELECT COUNT(*) FROM {table}"
        (cnt,) = self._execute_sql_one_row(sql)
        return cnt

    def _get_key_boundary(
        self, table: str, pk: str, offset: int, limit: int
    ) -> Tuple[Optional[Union[str, int]], Optional[Union[str, int]]]:
        """
        返回 (offset 处主键值, offset+limit 处主键值)
        用于构造 ≥ lower 且 < upper 的区间
        """
        # 下限
        sql_lo = f"""
        SELECT "{pk}" FROM {table}
        ORDER BY "{pk}" ASC
        LIMIT 1 OFFSET {offset};
        """
        lo = self._execute_sql_one_row_optional(sql_lo)
        if lo is None:  # 已经到表尾
            return (None, None)

        # 上限
        sql_hi = f"""
        SELECT "{pk}" FROM {table}
        ORDER BY "{pk}" ASC
        LIMIT 1 OFFSET {offset + limit};
        """
        hi = self._execute_sql_one_row_optional(sql_hi)
        # 如果已到末尾，用「无穷大」符号：NULL 可理解为 > 任意值
        upper = hi[0] if hi else "NULL"
        return (lo[0], upper)

    # ---------- SQL 执行 ----------
    def _execute_sql_one_row(self, sql: str) -> Tuple[Union[str, int], ...]:
        env = os.environ.copy()
        if self.password:
            env["PGPASSWORD"] = self.password
        cmd = [
            "psql",
            "-h",
            self.host,
            "-p",
            str(self.port),
            "-U",
            self.user,
            "-d",
            self.dbname,
            "-t",
            "-A",
            "-c",
            sql,
        ]
        result = subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
        return tuple(result.stdout.strip().split("|"))

    def _execute_sql_one_row_optional(
        self, sql: str
    ) -> Optional[Tuple[Union[str, int], ...]]:
        env = os.environ.copy()
        if self.password:
            env["PGPASSWORD"] = self.password
        cmd = [
            "psql",
            "-h",
            self.host,
            "-p",
            str(self.port),
            "-U",
            self.user,
            "-d",
            self.dbname,
            "-t",
            "-A",
            "-c",
            sql,
        ]
        result = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if result.returncode != 0 or result.stdout.strip() == "":
            return None
        return tuple(result.stdout.strip().split("|"))

    # ---------- pg_dump 命令 ----------
    def _build_pg_dump_cmd(self, table: str, extra_args: List[str]) -> List[str]:
        base = [
            "pg_dump",
            "--host",
            self.host,
            "--port",
            str(self.port),
            "--username",
            self.user,
            "--dbname",
            self.dbname,
            "--table",
            table,
            "--no-owner",
            "--no-acl",
            "--rows-per-insert",
            "1000",
        ]
        base.extend(extra_args)
        return base

    def _run_command(self, cmd: List[str], success_msg: str) -> None:
        env = os.environ.copy()
        if self.password:
            env["PGPASSWORD"] = self.password
        try:
            subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
            print(success_msg)
        except subprocess.CalledProcessError as e:
            print(f"\n❌ 命令执行失败:\n   命令: {' '.join(cmd)}\n   错误: {e.stderr}\n")
            raise

    # ---------- 导入脚本 ----------
    def _generate_import_script(self, table_name: str, batch_files: List[str]) -> None:
        script = self.output_dir / "import.sh"
        lines = [
            "#!/bin/bash",
            f"# PostgreSQL 导入脚本 - 表: {table_name}",
            f"# 数据文件数: {len(batch_files)}",
            "set -e",
            f'DB_NAME="{self.dbname}"',
            f'HOST="{self.host}"',
            f'USER="{self.user}"',
            'echo "📥 开始导入..."',
            'echo "📦 导入表结构..."',
            f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -f 00_{table_name}_schema.sql',
            'echo "📊 导入数据..."',
        ]
        for f in batch_files:
            lines.extend([f'echo "  📄 {f}"', f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -f {f}'])
        lines.extend(
            [
                'echo "✅ 导入完成!"',
                f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM {table_name};"',
            ]
        )
        script.write_text("\n".join(lines))
        script.chmod(0o755)
        print(f"  ✓ 导入脚本: {script.name}\n")


# ----------------------------------------------------------------------
#  命令行演示
# ----------------------------------------------------------------------
if __name__ == "__main__":
    exporter = PostgreSQLBatchExporter(
        host="localhost",
        dbname="schoolproject",
        user="postgres",
        password=None,  # 使用 ~/.pgpass
        port=5432,
    )
    try:
        out = exporter.export_table("school_student", batch_size=5_000)
        print(f"🎯 输出目录: {out}")
        print("📜 导入命令: cd", out, "&& bash import.sh")
    except Exception as e:
        print(f"❌ 导出失败: {e}")
