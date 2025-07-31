"""
D:/tmp/open_excel.py
日志：D:/tmp/open_excel.log（只追加，不删除）
"""

import sys, os, subprocess, traceback, re, urllib.parse as up
from datetime import datetime

LOG_FILE = r'D:/tmp/open_excel.log'

def log(msg):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + '\n')

try:
    log('===== 新调用开始 =====')
    log(f'sys.argv: {sys.argv}')

    raw = sys.argv[1]
    log(f'原始 URL: {raw}')

    # 1. 统一去掉协议前缀（excel:// 或 excel:）
    path = re.sub(r'^excel:?/*', '', raw, flags=re.IGNORECASE)
    log(f'去掉协议后: {path}')

    # 2. URL 解码（%20、%5C 等）
    path = up.unquote(path)
    log(f'URL 解码后: {path}')

    # 3. 把 %5C → \ 并去掉开头多余的 \
    path = path.replace('\\', '/')          # 先统一为正斜杠，避免双反斜杠
    path = path.lstrip('/')                 # 去掉开头的 / 或 \
    path = path.replace('/', '\\')          # 再换回 Windows 反斜杠
    log(f'整理后路径: {path}')

    # 4. 拼成真正绝对路径
    path = os.path.abspath(path)
    log(f'绝对路径: {path}')

    if not os.path.isfile(path):
        log(f'❌ 文件不存在: {path}')
        raise FileNotFoundError(path)

    excel = r"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
    log(f'Excel 路径: {excel}')
    subprocess.Popen([excel, path])
    log('✅ Excel 已调起')

except Exception:
    log('=== 异常堆栈 ===')
    log(traceback.format_exc())
