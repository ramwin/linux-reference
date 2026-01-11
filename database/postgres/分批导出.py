#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess
import os
import time  # 新增：用于批次间休眠
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Tuple, Union


class PostgreSQLBatchExporter:
    """PostgreSQL 分批导出工具类（无 OFFSET 累积，任意主键，带压缩，批次间休眠）"""

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
        compress: bool = True,
    ) -> Path:
        if output_dir is None:
            self.output_dir = Path(f"backup_{datetime.now():%Y%m%d_%H%M%S}")
        else:
            self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        print(f"📦 开始导出表 `{table_name}` 到 {self.output_dir}")

        # 1. 结构（支持压缩）
        self._export_schema(table_name, compress)

        # 2. 数据（支持压缩 + 批次休眠）
        batch_files = self._export_data_batches_copy(table_name, batch_size, primary_key, compress)

        # 3. 导入脚本（自动识别压缩格式）
        self._generate_import_script(table_name, batch_files, compress)

        print(f"✅ 导出完成！共 {len(batch_files)} 个数据文件\n")
        return self.output_dir

    # -------------------- 内部实现 --------------------
    def _export_schema(self, table_name: str, compress: bool) -> None:
        schema_file = self.output_dir / f"00_{table_name}_schema.sql"
        cmd = [
            "pg_dump",
            "--host", self.host,
            "--port", str(self.port),
            "--username", self.user,
            "--dbname", self.dbname,
            "--table", table_name,
            "--schema-only",
            "--no-owner",
            "--no-acl",
            "-f", str(schema_file),
        ]
        self._run_command(cmd, f"  ✓ 表结构: {schema_file.name}")

        if compress:
            self._gzip_file(schema_file)

    def _export_data_batches_copy(
        self,
        table_name: str,
        batch_size: int,
        primary_key: Optional[str],
        compress: bool,
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
        batch_num = 1
        lower_key = self._get_min_key(table_name, pk)

        while lower_key is not None:
            upper_key = self._get_nth_key(table_name, pk, lower_key, batch_size)
            where = f'"{pk}" >= {self._quote_if_str(lower_key)}'
            if upper_key is not None:
                where += f' AND "{pk}" < {self._quote_if_str(upper_key)}'

            file_name = f"{batch_num:03d}_{table_name}_data.sql"
            batch_file = self.output_dir / file_name

            # 使用 COPY 导出 + 可选压缩
            self._copy_to_file(table_name, where, batch_file, compress)
            final_name = f"{file_name}.gz" if compress else file_name
            batch_files.append(final_name)

            # 每批导出后休眠 0.2 秒，减轻数据库压力
            time.sleep(0.2)

            if upper_key is None:
                break
            lower_key = upper_key
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

    def _get_total_rows(self, table_name: str) -> int:
        sql = f"SELECT COUNT(*) FROM {table_name}"
        (cnt,) = self._execute_sql_one_row(sql)
        return int(cnt)  # 必须转 int，否则 f-string 格式化报错

    def _get_min_key(self, table: str, pk: str) -> Optional[Union[str, int]]:
        sql = f'SELECT "{pk}" FROM {table} ORDER BY "{pk}" ASC LIMIT 1'
        row = self._execute_sql_one_row_optional(sql)
        return row[0] if row else None

    def _get_nth_key(
        self, table: str, pk: str, start_key: Union[str, int], n: int
    ) -> Optional[Union[str, int]]:
        sql = f"""
        SELECT "{pk}"
        FROM {table}
        WHERE "{pk}" >= {self._quote_if_str(start_key)}
        ORDER BY "{pk}" ASC
        LIMIT 1 OFFSET {n};
        """
        row = self._execute_sql_one_row_optional(sql)
        return row[0] if row else None

    # ---------- SQL 执行 ----------
    def _execute_sql_one_row(self, sql: str) -> Tuple[Union[str, int], ...]:
        env = os.environ.copy()
        if self.password:
            env["PGPASSWORD"] = self.password
        cmd = [
            "psql",
            "-h", self.host,
            "-p", str(self.port),
            "-U", self.user,
            "-d", self.dbname,
            "-t", "-A", "-c", sql,
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
            "-h", self.host,
            "-p", str(self.port),
            "-U", self.user,
            "-d", self.dbname,
            "-t", "-A", "-c", sql,
        ]
        result = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if result.returncode != 0 or result.stdout.strip() == "":
            return None
        return tuple(result.stdout.strip().split("|"))

    # ---------- COPY 导出 + 压缩 ----------
    def _copy_to_file(self, table_name: str, where: str, file: Path, compress: bool) -> None:
        """COPY 数据到文件，可选 gzip 压缩"""
        copy_sql = f"COPY (SELECT * FROM {table_name} WHERE {where}) TO STDOUT WITH (FORMAT text, HEADER false)"
        
        env = os.environ.copy()
        if self.password:
            env["PGPASSWORD"] = self.password

        if compress:
            # psql | gzip 管道压缩
            psql_cmd = [
                "psql",
                "-h", self.host,
                "-p", str(self.port),
                "-U", self.user,
                "-d", self.dbname,
                "-c", copy_sql,
            ]
            gzip_cmd = ["gzip", "-c"]
            gz_file = file.with_suffix(".sql.gz")
            
            with open(gz_file, "wb") as f:
                psql_proc = subprocess.Popen(psql_cmd, env=env, stdout=subprocess.PIPE)
                gzip_proc = subprocess.Popen(gzip_cmd, stdin=psql_proc.stdout, stdout=f)
                psql_proc.stdout.close()  # 让 psql 知道 stdout 已被接管
                gzip_proc.communicate()
                psql_proc.wait()
                if psql_proc.returncode != 0:
                    raise subprocess.CalledProcessError(psql_proc.returncode, psql_cmd)
            print(f"    导出数据(已压缩): {gz_file.name}")
        else:
            # 不压缩，直接 psql -o 输出
            cmd = [
                "psql",
                "-h", self.host,
                "-p", str(self.port),
                "-U", self.user,
                "-d", self.dbname,
                "-c", copy_sql,
                "-o", str(file),
            ]
            try:
                subprocess.run(cmd, env=env, check=True, capture_output=True, text=True)
                print(f"    导出数据: {file.name}")
            except subprocess.CalledProcessError as e:
                print(f"\n❌ 命令执行失败:\n   命令: {' '.join(cmd)}\n   错误: {e.stderr}\n")
                raise

    # ---------- 文件压缩 ----------
    def _gzip_file(self, file: Path) -> None:
        """gzip 压缩文件"""
        cmd = ["gzip", "-f", str(file)]
        subprocess.run(cmd, check=True)
        print(f"    已压缩: {file.name}.gz")

    # ---------- 通用命令 ----------
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
    def _generate_import_script(self, table_name: str, batch_files: List[str], compress: bool) -> None:
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
        ]
        
        if compress:
            lines.extend([
                'echo "📦 导入表结构..."',
                f'gunzip -c 00_{table_name}_schema.sql.gz | psql -h "$HOST" -U "$USER" -d "$DB_NAME"',
                'echo "📊 导入数据..."',
            ])
            for f in batch_files:
                lines.extend([
                    f'echo "  📄 {f}"',
                    f'gunzip -c {f} | psql -h "$HOST" -U "$USER" -d "$DB_NAME" -c "\\\\copy {table_name} FROM STDIN"'
                ])
        else:
            lines.extend([
                'echo "📦 导入表结构..."',
                f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -f 00_{table_name}_schema.sql',
                'echo "📊 导入数据..."',
            ])
            for f in batch_files:
                lines.extend([
                    f'echo "  📄 {f}"',
                    f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -c "\\\\copy {table_name} FROM ''{f}''"'
                ])
        
        lines.extend([
            'echo "✅ 导入完成!"',
            f'psql -h "$HOST" -U "$USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM {table_name};"'
        ])
        
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
        # 默认启用压缩 + 休眠
        out = exporter.export_table("school_student", batch_size=5_000, compress=True)
        print(f"🎯 输出目录: {out}")
        print("📜 导入命令: cd", out, "&& bash import.sh")
    except Exception as e:
        print(f"❌ 导出失败: {e}")
