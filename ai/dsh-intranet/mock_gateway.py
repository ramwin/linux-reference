#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""内网大模型网关的最小模拟器, 零依赖纯 Python(标准库)。

回答三个问题:
  1. DSH 打到网关上的请求到底长什么样?      -> 每个请求体原样落盘 requests.jsonl
  2. 配置里的 baseURL 该怎么写才不会 404?    -> 这里只暴露 /v1/messages 与
                                                /v1/chat/completions, 路径对不上一眼可见
  3. 不碰内网真网关, 配置对不对?             -> 用它顶替网关跑 dsh headless 冒烟

同时提供两种协议(故意和中转网关一样):
  * Anthropic Messages    POST /v1/messages          (Claude 对接)
  * OpenAI Chat Completions POST /v1/chat/completions (OpenAI 兼容)
  * 模型列表              GET  /v1/models            (两种协议共用)

用法:
    python3 mock_gateway.py --port 18080 --model glm-5.3
    # 另一个终端:
    #   ANTHROPIC_BASE_URL=http://127.0.0.1:18080 ./configure-dsh.sh ...
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def _force_utf8_stdio() -> None:
    """把 stdout/stderr 掰成 UTF-8。

    内网机器常见 LANG=zh_CN.GBK: 那时 Python 会按 GBK 编码输出, 而 ✅/❌/→ 这些
    字符不在 GBK 里, 打印第一行结果就 UnicodeEncodeError 崩掉。这里统一成 UTF-8
    并把无法编码的字符替换掉, 保证脚本永远不会因为终端编码而死。
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


REQUESTS_LOCK = threading.Lock()
ARGS = None


def log_request_record(record: dict) -> None:
    """把请求体落盘, 供人工比对 DSH 真正发出的协议字段。"""
    with REQUESTS_LOCK:
        with open(ARGS.log, "a", encoding="utf-8") as fp:
            fp.write(json.dumps(record, ensure_ascii=False) + "\n")


# --strict 用: 严格的 Claude 兼容网关只认这些顶层字段, 其余一律 400
ANTHROPIC_ALLOWED = {
    "model", "messages", "max_tokens", "stream", "system", "tools", "tool_choice",
    "temperature", "top_p", "top_k", "stop_sequences", "metadata", "thinking",
}

# --strict 用: 很多中转/自建网关不认这些 OpenAI 方言
OPENAI_REJECTED_FIELDS = {
    "max_completion_tokens": "unsupported parameter: max_completion_tokens (use max_tokens)",
    "store": "unsupported parameter: store",
    "stream_options": "unsupported parameter: stream_options",
    "reasoning_effort": "unsupported parameter: reasoning_effort",
}


def strict_problem(path: str, body: dict) -> str | None:
    """严格模式下返回拒绝原因, 通过则返回 None。"""
    if path == "/v1/messages":
        unknown = sorted(set(body) - ANTHROPIC_ALLOWED)
        if unknown:
            return f"unknown top-level field(s): {', '.join(unknown)}"
        return None
    for field, message in OPENAI_REJECTED_FIELDS.items():
        if field in body:
            return message
    if any(m.get("role") == "developer" for m in body.get("messages") or []
           if isinstance(m, dict)):
        return "unsupported role: developer (use system)"
    for tool in body.get("tools") or []:
        fn = tool.get("function") if isinstance(tool, dict) else None
        if isinstance(fn, dict) and "strict" in fn:
            return "unsupported parameter: tools[].function.strict"
    return None


def extract_prompt(body: dict) -> str:
    """从两种协议的请求体里取出最后一条用户文本, 用来回显。"""
    messages = body.get("messages") or []
    for message in reversed(messages):
        content = message.get("content")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            for block in reversed(content):
                if isinstance(block, dict) and block.get("type") == "text":
                    return block.get("text", "")
    return ""


def reply_text(body: dict) -> str:
    prompt = extract_prompt(body).strip().replace("\n", " ")
    if len(prompt) > 60:
        prompt = prompt[:60] + "…"
    return f"[mock-gateway:{ARGS.model}] 收到: {prompt}"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "mock-intranet-gateway/1.0"

    # ------------------------------------------------------------ 基础设施
    def log_message(self, fmt: str, *args) -> None:  # 关掉默认 access log 噪音
        sys.stderr.write("[mock] %s\n" % (fmt % args))

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            return json.loads(raw or b"{}")
        except json.JSONDecodeError:
            return {"_raw": raw.decode("utf-8", "replace")}

    def _send_json(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_sse(self, events: list[tuple[str, dict]]) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        for name, payload in events:
            chunk = f"event: {name}\ndata: {json.dumps(payload, ensure_ascii=False)}\n\n"
            self.wfile.write(chunk.encode("utf-8"))
            self.wfile.flush()

    def _record(self, path: str, body: dict) -> None:
        log_request_record(
            {
                "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "path": path,
                "headers": {
                    k.lower(): v
                    for k, v in self.headers.items()
                    if k.lower() in ("authorization", "x-api-key", "anthropic-version",
                                     "content-type", "user-agent", "anthropic-beta")
                },
                "body": body,
            }
        )

    # ----------------------------------------------------------------路由
    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path in ("/v1/models", "/models"):
            self._record(path, {})
            now = int(time.time())
            self._send_json(
                {
                    "object": "list",
                    "data": [
                        {
                            "id": ARGS.model,
                            "object": "model",
                            "created": now,
                            "owned_by": "intranet",
                            "max_input_tokens": ARGS.context_window,
                            "max_tokens": 8192,
                        },
                        {
                            "id": ARGS.model + "-air",
                            "object": "model",
                            "created": now,
                            "owned_by": "intranet",
                        },
                    ],
                }
            )
            return
        self._send_json({"error": {"message": f"no such route: {path}"}}, status=404)

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0].rstrip("/") or "/"
        if path == "/v1/messages" and ARGS.only == "openai":
            self._send_json({"type": "error", "error": {
                "type": "not_found_error",
                "message": "this gateway does not serve the Messages API"}}, status=404)
            return
        if path == "/v1/chat/completions" and ARGS.only == "anthropic":
            self._send_json({"error": {
                "message": "this gateway does not serve the Chat Completions API",
                "type": "not_found_error"}}, status=404)
            return
        body = self._read_body()
        self._record(path, body)
        if ARGS.strict:
            problem = strict_problem(path, body)
            if problem is not None:
                if path == "/v1/messages":
                    self._send_json(
                        {"type": "error", "error": {"type": "invalid_request_error",
                                                    "message": problem}},
                        status=400,
                    )
                else:
                    self._send_json(
                        {"error": {"message": problem, "type": "invalid_request_error"}},
                        status=400,
                    )
                return
        if path == "/v1/messages":
            self._anthropic_messages(body)
            return
        if path == "/v1/chat/completions":
            self._openai_chat(body)
            return
        self._send_json({"error": {"message": f"no such route: {path}"}}, status=404)

    # ------------------------------------------------------ Anthropic 协议
    def _anthropic_messages(self, body: dict) -> None:
        if not (self.headers.get("x-api-key") or self.headers.get("authorization")):
            self._send_json(
                {"type": "error", "error": {"type": "authentication_error",
                                            "message": "missing x-api-key"}},
                status=401,
            )
            return
        text = reply_text(body)
        if not body.get("stream"):
            self._send_json(
                {
                    "id": "msg_mock_1",
                    "type": "message",
                    "role": "assistant",
                    "model": body.get("model", ARGS.model),
                    "content": [{"type": "text", "text": text}],
                    "stop_reason": "end_turn",
                    "stop_sequence": None,
                    "usage": {"input_tokens": 12, "output_tokens": 8},
                }
            )
            return
        model = body.get("model", ARGS.model)
        base = {"type": "message_start",
                "message": {"id": "msg_mock_1", "type": "message", "role": "assistant",
                            "model": model, "content": [],
                            "stop_reason": None, "stop_sequence": None,
                            "usage": {"input_tokens": 12, "output_tokens": 1}}}
        events = [
            ("message_start", base),
            ("content_block_start", {"type": "content_block_start", "index": 0,
                                     "content_block": {"type": "text", "text": ""}}),
        ]
        for piece in [text[i:i + 8] for i in range(0, len(text), 8)]:
            events.append(("content_block_delta",
                           {"type": "content_block_delta", "index": 0,
                            "delta": {"type": "text_delta", "text": piece}}))
        events += [
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {"type": "message_delta",
                               "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                               "usage": {"output_tokens": 8}}),
            ("message_stop", {"type": "message_stop"}),
        ]
        self._send_sse(events)

    # -------------------------------------------------------- OpenAI 协议
    def _openai_chat(self, body: dict) -> None:
        if not self.headers.get("authorization"):
            self._send_json(
                {"error": {"message": "missing Authorization header", "type": "invalid_request_error"}},
                status=401,
            )
            return
        text = reply_text(body)
        created = int(time.time())
        if not body.get("stream"):
            self._send_json(
                {
                    "id": "chatcmpl-mock-1",
                    "object": "chat.completion",
                    "created": created,
                    "model": body.get("model", ARGS.model),
                    "choices": [{"index": 0, "finish_reason": "stop",
                                 "message": {"role": "assistant", "content": text}}],
                    "usage": {"prompt_tokens": 12, "completion_tokens": 8, "total_tokens": 20},
                }
            )
            return
        envelope = {"id": "chatcmpl-mock-1", "object": "chat.completion.chunk",
                    "created": created, "model": body.get("model", ARGS.model)}

        def chunk(delta: dict, finish=None) -> str:
            payload = dict(envelope)
            payload["choices"] = [{"index": 0, "delta": delta, "finish_reason": finish}]
            return "data: " + json.dumps(payload, ensure_ascii=False) + "\n\n"

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(chunk({"role": "assistant", "content": ""}).encode())
        for piece in [text[i:i + 8] for i in range(0, len(text), 8)]:
            self.wfile.write(chunk({"content": piece}).encode())
            self.wfile.flush()
        self.wfile.write(chunk({}, finish="stop").encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()


def main() -> int:
    _force_utf8_stdio()
    global ARGS
    parser = argparse.ArgumentParser(description="内网大模型网关模拟器")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18080)
    parser.add_argument("--model", default="glm-5.3", help="对外公布的模型 id")
    parser.add_argument("--context-window", type=int, default=204800)
    parser.add_argument("--log", default="/tmp/mock-gateway-requests.jsonl")
    parser.add_argument("--only", choices=("both", "openai", "anthropic"), default="both",
                        help="只开一种协议, 用来模拟内网只给了一个口子的网关")
    parser.add_argument("--strict", action="store_true",
                        help="扮演严格的网关: 拒掉 DeepSeek 私有字段与 OpenAI 方言, 用来验证降级配置")
    ARGS = parser.parse_args()
    server = ThreadingHTTPServer((ARGS.host, ARGS.port), Handler)
    print(f"[mock] 监听 http://{ARGS.host}:{ARGS.port}", flush=True)
    extra = ""
    if ARGS.only != "both":
        extra += f"; 只开 {ARGS.only} 口子"
    if ARGS.strict:
        extra += "; 严格模式(拒私有字段/方言)"
    print(f"[mock] 模型 {ARGS.model}; 请求记录 {ARGS.log}{extra}", flush=True)
    print("[mock] Anthropic: POST /v1/messages   OpenAI: POST /v1/chat/completions", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("[mock] 退出", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
