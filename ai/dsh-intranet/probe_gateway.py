#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""内网大模型网关探测器, 零依赖纯 Python(标准库)。

回答四个问题:
  1. 网关到底在哪个路径上?          -> 依次试探 {url}/v1 与 {url}, 报出真正 200 的那个
  2. 两种协议哪种能用?              -> OpenAI 兼容 / Claude(Anthropic Messages) 各打一发
  3. OpenAI 兼容的"方言"是哪一种?    -> 逐项试探 max_tokens / store / developer /
                                       strict / reasoning_effort / include_usage,
                                       哪些被 4xx 拒绝就关掉对应的 compat 开关
  4. Claude 对接能不能吞下 DSH 的
     私有顶层字段?                   -> 单独试探 output_config / dsh_session_log,
                                       被拒就说明要关掉 DeepSeek 扩展插件

探测只发极小的请求(max_tokens=8), 不消耗多少额度; 全部结论只是"这个网关接受/
拒绝什么", 不改任何远端状态。

    python3 probe_gateway.py --url http://10.0.0.9:8000 --key sk-xxx
    python3 probe_gateway.py --url https://gw.corp/anthropic --key sk-xxx --insecure
"""

from __future__ import annotations

import argparse
import json
import ssl
import sys
import time
import urllib.error
import urllib.request

TIMEOUT = 30
PROBE_MAX_TOKENS = 8


# --------------------------------------------------------------------- HTTP

def build_opener(insecure: bool, use_proxy: bool):
    handlers = []
    if not use_proxy:  # 内网地址默认绕开 http_proxy/https_proxy
        handlers.append(urllib.request.ProxyHandler({}))
    if insecure:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        handlers.append(urllib.request.HTTPSHandler(context=ctx))
    return urllib.request.build_opener(*handlers)


class Result:
    def __init__(self, name: str, ok: bool, status: int | None, detail: str, ms: int,
                 raw: str = ""):
        self.name = name
        self.ok = ok
        self.status = status
        self.detail = detail
        self.ms = ms
        self.raw = raw

    def __str__(self) -> str:
        mark = "✅" if self.ok else "❌"
        status = self.status if self.status is not None else "---"
        return f"{mark} {self.name:<34} HTTP {status:<5} {self.ms:>5}ms  {self.detail}"


def request(opener, method: str, url: str, headers: dict, body: dict | None) -> tuple[int, str]:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    for key, value in headers.items():
        req.add_header(key, value)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with opener.open(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.read(4000).decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(4000).decode("utf-8", "replace")
    except Exception as exc:  # 连接失败/超时/DNS
        return 0, f"{type(exc).__name__}: {exc}"


def short(text: str, limit: int = 150) -> str:
    text = " ".join(text.split())
    return text if len(text) <= limit else text[:limit] + "…"


def error_message(raw: str) -> str:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return short(raw)
    if isinstance(payload, dict):
        err = payload.get("error")
        if isinstance(err, dict):
            return short(str(err.get("message") or err))
        if isinstance(err, str):
            return short(err)
        if payload.get("message"):
            return short(str(payload["message"]))
    return short(raw)


# ------------------------------------------------------------------ 探测项

class Probe:
    def __init__(self, opts):
        self.o = opts
        self.opener = build_opener(opts.insecure, opts.use_proxy)
        self.results: list[Result] = []

    # ---- 基础工具
    def hit(self, name: str, method: str, url: str, headers: dict,
            body: dict | None, expect: str = "json") -> Result:
        """expect: json(默认) | sse | any —— 决定怎样算"这个探测通过"。"""
        started = time.time()
        status, raw = request(self.opener, method, url, headers, body)
        ms = int((time.time() - started) * 1000)
        ok = 200 <= status < 300
        if ok and expect == "json":
            try:
                json.loads(raw)
            except json.JSONDecodeError:
                ok = False
                raw = "响应不是合法 JSON: " + raw
        elif ok and expect == "sse":
            if "data:" not in raw and "event:" not in raw:
                ok = False
                raw = "不是 SSE 流: " + raw
        detail = "ok" if ok else error_message(raw)
        result = Result(name, ok, status or None, detail, ms, raw)
        self.results.append(result)
        print(result, flush=True)
        return result

    # ---- OpenAI 兼容
    def openai_headers(self) -> dict:
        return {"Authorization": f"Bearer {self.o.key}"}

    def openai_body(self, **overrides) -> dict:
        body = {
            "model": self.o.model,
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": PROBE_MAX_TOKENS,
            "stream": False,
        }
        body.update(overrides)
        return body

    def probe_openai(self, root: str) -> dict:
        """返回 openai 方言的探测结论。"""
        chat = root + "/chat/completions"
        verdict = {"root": root, "usable": False, "compat": {}, "notes": []}
        print(f"\n== OpenAI 兼容接口: {chat}", flush=True)

        base = self.hit("openai: 最小 chat 请求", "POST", chat, self.openai_headers(),
                        self.openai_body())
        if not base.ok:
            verdict["notes"].append(f"最小请求就失败: HTTP {base.status} {base.detail}")
            return verdict
        verdict["usable"] = True

        # 输出上限字段: max_tokens 还是 max_completion_tokens
        body = self.openai_body()
        body.pop("max_tokens")
        body["max_completion_tokens"] = PROBE_MAX_TOKENS
        if self.hit("openai: max_completion_tokens", "POST", chat, self.openai_headers(), body).ok:
            verdict["compat"]["maxTokensField"] = "max_completion_tokens"
        else:
            verdict["compat"]["maxTokensField"] = "max_tokens"
            verdict["notes"].append("网关只认 max_tokens, 已写入 compat.maxTokensField")

        # 逐个试探"多余字段"是否被接受
        extras = {
            "supportsStore": {"store": False},
            "supportsUsageInStreaming": {"stream_options": {"include_usage": True}},
            "supportsReasoningEffort": {"reasoning_effort": "low"},
        }
        for knob, payload in extras.items():
            probe_body = self.openai_body(**payload)
            ok = self.hit(f"openai: {knob} ({', '.join(payload)})", "POST", chat,
                          self.openai_headers(), probe_body).ok
            verdict["compat"][knob] = ok
            if not ok:
                verdict["notes"].append(f"网关拒绝 {', '.join(payload)}, 已关闭 compat.{knob}")

        # developer 角色 (OpenAI 新方言) 是否被接受
        dev_body = self.openai_body(messages=[
            {"role": "developer", "content": "you are a test"},
            {"role": "user", "content": "ping"},
        ])
        ok = self.hit("openai: developer 角色", "POST", chat, self.openai_headers(), dev_body).ok
        verdict["compat"]["supportsDeveloperRole"] = ok
        if not ok:
            verdict["notes"].append("网关拒绝 developer 角色, 已关闭 compat.supportsDeveloperRole")

        # 工具 schema 的 strict 模式
        tools = [{
            "type": "function",
            "function": {
                "name": "ping",
                "description": "probe",
                "strict": True,
                "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
            },
        }]
        ok = self.hit("openai: tools + strict", "POST", chat, self.openai_headers(),
                      self.openai_body(tools=tools)).ok
        verdict["compat"]["supportsStrictMode"] = ok
        if not ok:
            verdict["notes"].append("网关拒绝 strict 工具, 已关闭 compat.supportsStrictMode")

        # 工具调用本身能不能过 (只验 schema 被接受 + 流式)
        ok = self.hit("openai: 流式 + tools", "POST", chat, self.openai_headers(),
                      self.openai_body(stream=True, tools=tools, max_tokens=16),
                      expect="sse").ok
        verdict["streaming"] = ok
        return verdict

    # ---- Anthropic Messages
    def anthropic_headers(self) -> dict:
        return {
            "x-api-key": self.o.key,
            "anthropic-version": "2023-06-01",
        }

    def anthropic_body(self, **overrides) -> dict:
        body = {
            "model": self.o.model,
            "max_tokens": PROBE_MAX_TOKENS,
            "messages": [{"role": "user", "content": "ping"}],
        }
        body.update(overrides)
        return body

    def probe_anthropic(self, root: str) -> dict:
        messages = root + "/v1/messages"
        verdict = {"root": root, "usable": False, "compat": {}, "notes": []}
        print(f"\n== Claude(Anthropic Messages) 对接: {messages}", flush=True)

        base = self.hit("anthropic: 最小 messages 请求", "POST", messages,
                        self.anthropic_headers(), self.anthropic_body())
        if not base.ok:
            verdict["notes"].append(f"最小请求就失败: HTTP {base.status} {base.detail}")
            return verdict
        verdict["usable"] = True

        # DSH 的 DeepSeek 扩展字段: 被拒就必须关掉对应插件
        for knob, payload in (
            ("thinking(disabled)", {"thinking": {"type": "disabled"}}),
            ("thinking(enabled)", {"thinking": {"type": "enabled"}}),
            ("output_config", {"output_config": {"effort": "high"}}),
            ("dsh_session_log", {"dsh_session_log": {"version": 1, "events": []}}),
            ("dsh_plugin_packages", {"dsh_plugin_packages": {"version": 1, "packages": []}}),
        ):
            ok = self.hit(f"anthropic: {knob}", "POST", messages, self.anthropic_headers(),
                          self.anthropic_body(**payload)).ok
            verdict["compat"][knob] = ok

        ok = self.hit("anthropic: 流式", "POST", messages, self.anthropic_headers(),
                      self.anthropic_body(stream=True, max_tokens=16), expect="sse").ok
        verdict["streaming"] = ok

        if not verdict["compat"].get("output_config", True):
            verdict["notes"].append("网关拒绝 output_config -> reasoningEffort 必须设为 off")
        if not verdict["compat"].get("dsh_session_log", True) or \
           not verdict["compat"].get("dsh_plugin_packages", True):
            verdict["notes"].append("网关拒绝 DSH 私有字段 -> 必须 disabled 三个 DeepSeek 扩展插件")
        return verdict

    # ---- 模型列表
    def probe_models(self, roots: list[str]) -> list[str]:
        ids: list[str] = []
        print("\n== 模型列表", flush=True)
        for root in roots:
            for name, headers in (("Bearer", {"Authorization": f"Bearer {self.o.key}"}),
                                  ("x-api-key", self.anthropic_headers())):
                url = root + "/models"
                result = self.hit(f"models: {url} ({name})", "GET", url, headers, None)
                if result.ok:
                    ids = parse_model_ids(result.raw)
                    if ids:
                        print(f"   发现 {len(ids)} 个模型: {', '.join(ids[:12])}"
                              + (" …" if len(ids) > 12 else ""), flush=True)
                        return ids
        if not ids:
            print("   (没有可用的模型列表接口, 后面只能用 --model 指定的 id)", flush=True)
        return ids


def parse_model_ids(raw: str) -> list[str]:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return []
    items = payload.get("data") if isinstance(payload, dict) else payload
    if not isinstance(items, list):
        return []
    ids = []
    for item in items:
        if isinstance(item, dict) and isinstance(item.get("id"), str):
            ids.append(item["id"])
        elif isinstance(item, str):
            ids.append(item)
    return ids


# --------------------------------------------------------------- 配置生成

def normalize_roots(url: str) -> tuple[str, str]:
    """返回 (openai根, anthropic根)。两家的 baseURL 约定不同, 这里都归一化。"""
    url = url.strip().rstrip("/")
    if url.endswith("/v1"):
        return url, url[: -len("/v1")]
    return url + "/v1", url


# 实测(dsh 0.1.7-rc.2): compat 的键是按协议分的, 放错协议会在真正启动时报
# INVALID_CONFIG —— 而 --dump-config 查不出来, 所以生成时必须只挑本协议认的键。
# openai-completions 认这些:
OPENAI_COMPAT_KEYS = {
    "cacheControlFormat", "chatTemplateArgs", "chatTemplateKwargs", "maxTokensField",
    "requiresAssistantAfterToolResult", "requiresReasoningContentOnAssistantMessages",
    "requiresThinkingAsText", "requiresToolResultName", "supportsDeveloperRole",
    "supportsFinishReason", "supportsLongCacheRetention", "supportsReasoningEffort",
    "supportsStore", "supportsStrictMode", "supportsThinkingTokenBudget",
    "supportsUsageInStreaming", "thinkingFormat", "thinkingTokenBudgetField", "vllmPriority",
}
# anthropic-messages 认这些(本方案里 Claude 路由走 llm-deepseek, 没有 compat 面, 仅作参考):
ANTHROPIC_COMPAT_KEYS = {
    "allowEmptySignature", "forceAdaptiveThinking", "supportsCacheControlOnTools",
    "supportsEagerToolInputStreaming", "supportsStrictTools", "supportsTemperature",
    "supportsLongCacheRetention",
}


def openai_patch(model: str, root: str, context: int, max_tokens: int, compat: dict) -> str:
    compat_lines = []
    for key in ("supportsStore", "supportsDeveloperRole", "supportsReasoningEffort",
                "supportsUsageInStreaming", "supportsStrictMode"):
        if compat.get(key) is False and key in OPENAI_COMPAT_KEYS:
            compat_lines.append(f"          {key}: false")
    if compat.get("maxTokensField") == "max_tokens":
        compat_lines.append("          maxTokensField: max_tokens")
    if model.lower().startswith("glm"):
        compat_lines.append("          thinkingFormat: zai   # GLM/Zhipu 的思维链方言")
    compat_block = ""
    if compat_lines:
        compat_block = "        compat:\n" + "\n".join(compat_lines) + "\n"
    return f"""# 由 probe_gateway.py 生成: OpenAI 兼容路由
- id: llm-pi-ai
  config:
    providers:
      intranet-gw:
        displayName: 内网网关
        api: openai-completions
        baseURL: {root}
        apiKeyEnv: INTRANET_LLM_API_KEY
{compat_block}        defaultContextWindow: {context}
        defaultMaxTokens: {max_tokens}
        models:
          - id: {model}
            name: {model}
            contextWindow: {context}
            maxTokens: {max_tokens}
- id: agent-default-model
  config:
    provider: intranet-gw
    model: {model}
"""


def anthropic_patch(model: str, root: str, context: int, max_tokens: int,
                    effort: str, disable_extensions: bool) -> str:
    block = ""
    if disable_extensions:
        block = """# 网关不认识 DSH 的私有顶层字段, 先关掉 DeepSeek 专属扩展
- id: deepseek-llm-api-extensions
  disabled: true
- id: session-log-deepseek
  disabled: true
- id: plugin-package-inventory-deepseek
  disabled: true
"""
    return f"""# 由 probe_gateway.py 生成: Claude(Anthropic Messages) 路由
{block}- id: llm-deepseek
  name: '@deepseek-ai/dsh-llm-deepseek-api-key'
  config:
    apiKeyEnv: INTRANET_LLM_API_KEY
    baseURL: {root}
    maxTokens: {max_tokens}
    reasoningEffort: {effort}
    models:
      - id: {model}
        name: {model}
        contextWindow: {context}
- id: agent-default-model
  config:
    provider: deepseek-official
    model: {model}
"""


# -------------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(description="内网大模型网关探测器")
    parser.add_argument("--url", required=True, help="网关地址, 带不带 /v1 都行")
    parser.add_argument("--key", required=True, help="API Key")
    parser.add_argument("--model", default="", help="模型 id; 省略则从 /models 里挑")
    parser.add_argument("--context-window", type=int, default=204800)
    parser.add_argument("--max-tokens", type=int, default=32768,
                        help="DSH 请求的输出上限, 要小于网关允许值")
    parser.add_argument("--insecure", action="store_true", help="忽略自签证书校验")
    parser.add_argument("--use-proxy", action="store_true",
                        help="走 http_proxy/https_proxy(默认绕过, 内网直连)")
    parser.add_argument("--emit", metavar="DIR", help="把推荐配置写到该目录")
    opts = parser.parse_args()

    openai_root, anthropic_root = normalize_roots(opts.url)
    probe = Probe(opts)

    available = probe.probe_models([openai_root, anthropic_root])
    if not opts.model:
        if not available:
            print("\n❌ 没有 --model, 网关也不提供模型列表, 无法继续", file=sys.stderr)
            return 2
        glm = [m for m in available if "glm" in m.lower()]
        opts.model = (glm or available)[0]
        print(f"\n自动选择模型: {opts.model}", flush=True)

    openai_verdict = probe.probe_openai(openai_root)
    anthropic_verdict = probe.probe_anthropic(anthropic_root)

    # ---- 结论
    print("\n" + "=" * 72)
    print("结论")
    print("=" * 72)
    usable = []
    if openai_verdict["usable"]:
        usable.append("openai-completions")
    if anthropic_verdict["usable"]:
        usable.append("anthropic-messages")
    print(f"模型 id        : {opts.model}")
    print(f"可用协议       : {', '.join(usable) if usable else '都没有打通 ❌'}")
    for note in openai_verdict["notes"] + anthropic_verdict["notes"]:
        print(f"注意           : {note}")

    if not usable:
        print("\n两种协议都没打通。先确认: 地址/端口、key、以及内网有没有 http_proxy 干扰。",
              file=sys.stderr)
        return 1

    disable_extensions = not (anthropic_verdict["compat"].get("dsh_session_log", True)
                              and anthropic_verdict["compat"].get("dsh_plugin_packages", True))
    effort = "high" if anthropic_verdict["compat"].get("output_config", False) else "off"
    if anthropic_verdict["usable"] and effort == "off":
        print("注意           : Claude 路由的 reasoningEffort 用 off(网关不认识 output_config)")

    openai_text = openai_patch(opts.model, openai_root, opts.context_window,
                               opts.max_tokens, openai_verdict["compat"])
    anthropic_text = anthropic_patch(opts.model, anthropic_root, opts.context_window,
                                     opts.max_tokens, effort, disable_extensions)

    if opts.emit:
        import os  # noqa: PLC0415  只在这里用到
        os.makedirs(opts.emit, exist_ok=True)
        files = {}
        if openai_verdict["usable"]:
            files["cordis.patch.openai.yml"] = openai_text
        if anthropic_verdict["usable"]:
            files["cordis.patch.anthropic.yml"] = anthropic_text
        for name, text in files.items():
            path = os.path.join(opts.emit, name)
            with open(path, "w", encoding="utf-8") as fp:
                fp.write(text)
            print(f"已写出配置     : {path}")
    else:
        print("\n" + "-" * 72)
        if openai_verdict["usable"]:
            print("推荐 OpenAI 兼容路由(cordis.patch.openai.yml):\n")
            print(openai_text)
        if anthropic_verdict["usable"]:
            print("备选 Claude 路由(cordis.patch.anthropic.yml):\n")
            print(anthropic_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
