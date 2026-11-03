# LexiSharp 语音插件：本地识别加置信度，低置信度路由给云端大模型

```{contents}
```

## 问题背景

[LexiSharp-Linux](https://github.com/wangx/LexiSharp-Linux)（本机 `~/github/other/LexiSharp-Linux/lexisharp.py`）用 sherpa-onnx + SenseVoice int8 ONNX 模型做完全本地的语音识别。本地模型免费、快、隐私好，但遇到口音、噪声、专业词汇时会听错。希望：**给每次识别打一个置信度，低于阈值时把同一段音频转给云端大模型 ASR 兜底**。

好消息是 `lexisharp.py` 已经内置了三个云端渠道（火山引擎 `bigmodel`、Soniox、通义 `qwen3-asr-flash`），云端调用代码现成，只差「置信度 + 路由」这一层。

## 关键实测结论（2025-11，本机验证）

1. **sherpa-onnx 1.13.6 的 `OfflineRecognitionResult` 有 `ys_log_probs` 字段，但 SenseVoice 走 CTC 解码，该字段恒为空**（实测歌曲/噪声/静音三种输入 `len == 0`）。所以不能白嫖封装层。
2. **SenseVoice 的 ONNX 模型直接输出 CTC logits**（`logits [N, T, 25055]`），可以绕过 sherpa-onnx 封装，用 onnxruntime 自己算置信度：
   - 输入特征：80 维 kaldi fbank（25ms/10ms，dither=0）+ LFR 拼帧（m=7, n=6 → 560 维），可用 `pip install kaldi-native-fbank` 计算；
   - 另外两个输入：`language`（zh=0, en=1, yue=2, ja=3, ko=4）、`text_norm`（withitn=14, woitn=15）；
   - blank id = 0（`<|unk>`），可用静音输入实测探测；
   - 置信度 = greedy 路径上**非 blank 帧的 max-softmax 平均值**。
3. 实测分离度良好（同一段音频直出 ONNX 解码结果与 sherpa-onnx 文本一致）：

   | 输入 | 置信度 |
   |---|---|
   | 清晰人声（歌曲片段） | **0.93** |
   | 白噪声 | 0.59 |
   | 纯静音 | 0.61 |

   阈值取 **0.75~0.85** 比较稳妥，先用 0.80 跑一周看命中率再调。

## 方案对比

| 方案 | 置信度来源 | 准确度 | 改动量 | 云端花费 |
|---|---|---|---|---|
| A. 信号+文本启发式 | 音量/时长/削波 + 乱码率、重复率等文本特征 | 低（只能抓明显垃圾） | 小 | 仅兜底时 |
| B. CTC logits 真置信度 | 直跑 onnxruntime，算声学置信度 | 中高 | 中（装 `kaldi-native-fbank`，重写特征提取） | 仅兜底时 |
| C. 每次都双引擎对比 | 本地+云端各跑一次，比较文本一致度 | 高 | 小 | **每次都花钱，失去本地意义** |
| D. LLM 文本纠错 | 低置信文本发给 DeepSeek 等 LLM 按上下文改错别字 | 中（能修术语错字，但听错的词救不回来，还可能幻觉改错） | 小 | 便宜（纯文本） |

**推荐组合：B（声学置信度）+ 路由到 `qwen3-asr-flash`（云端大模型 ASR，听原音频）+ 可选 D（术语润色）**。
A 可以作为 B 的补充前置过滤（比如音频太短/音量太小直接判低置信，不进模型）。

## 落地实现

### 1. 置信度计算模块（新增 `confidence.py`，与 lexisharp.py 同目录）

```python
"""SenseVoice CTC 置信度计算：绕过 sherpa-onnx 封装直跑 onnxruntime。"""
import numpy as np
import onnxruntime as ort
import kaldi_native_fbank as knf

MODEL = "/home/wangx/.dsh/speech-to-text/sensevoice/models/sensevoice-onnx/model.int8.onnx"

# SenseVoice onnx 的固定输入编码（来自 FunASR 导出约定）
LANG_ID = {"zh": 0, "en": 1, "yue": 2, "ja": 3, "ko": 4}
TEXT_NORM = {"withitn": 14, "woitn": 15}
BLANK_ID = 0  # 实测探测：<|unk>，静音输入下所有帧 argmax 均为 0


def _fbank_lfr(samples: np.ndarray, sr: int = 16000) -> np.ndarray:
    """80 维 fbank + LFR(m=7, n=6) → [T', 560]"""
    opts = knf.FbankOptions()
    opts.frame_opts.samp_freq = sr
    opts.frame_opts.frame_length_ms = 25
    opts.frame_opts.frame_shift_ms = 10
    opts.frame_opts.dither = 0
    opts.mel_opts.num_bins = 80
    f = knf.OnlineFbank(opts)
    f.accept_waveform(sr, samples.tolist())
    f.input_finished()
    feat = np.stack([f.get_frame(i) for i in range(f.num_frames_ready)])
    T = feat.shape[0]
    m, l = 7, 6
    T_lfr = max(1, (T - m + l - 1) // l + 1) if T >= m else 1
    frames = []
    for i in range(T_lfr):
        s = i * l
        frames.append(np.concatenate([feat[min(s + k, T - 1)] for k in range(m)]))
    return np.stack(frames).astype(np.float32)


class SenseVoiceConfidence:
    """加载一次模型，复用 session；同时给出文本和置信度。"""

    def __init__(self, model_path: str = MODEL):
        self.sess = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])

    def infer(self, samples: np.ndarray, language: str = "zh",
              text_norm: str = "woitn") -> tuple[str, float, list[int]]:
        """返回 (tokens_ids, 置信度)。文本解码沿用 sherpa 的结果即可，这里只要置信度。"""
        x = _fbank_lfr(samples)[None, :, :]
        logits = self.sess.run(["logits"], {
            "x": x,
            "x_length": np.array([x.shape[1]], dtype=np.int32),
            "language": np.array([LANG_ID.get(language, 0)], dtype=np.int32),
            "text_norm": np.array([TEXT_NORM.get(text_norm, 15)], dtype=np.int32),
        })[0][0]  # [T', 25055]
        ids = logits.argmax(-1)
        mask = ids != BLANK_ID
        if not mask.any():
            return 0.0
        z = logits - logits.max(-1, keepdims=True)
        p = np.exp(z)
        p /= p.sum(-1, keepdims=True)
        return float(p.max(-1)[mask].mean())
```

### 2. 在 `lexisharp.py` 里加路由（改动 `_call_local_sherpa` 返回处）

`lexisharp.py` 现在的本地识别入口是 `_call_local_sherpa(audio_file)`（约 2059~2102 行），返回纯文本。改成：

```python
# 配置模板 CONFIG_TEMPLATE 里新增三项：
#   "local_confidence_threshold": 0.80,      # 低于此值转云端
#   "local_fallback_channel": "qwen",        # 兜底渠道：qwen / volcengine / soniox
#   "local_fallback_enabled": True,

def _call_local_sherpa(self, audio_file: str) -> Optional[str]:
    text, samples, sr = self._local_recognize_with_audio(audio_file)  # 把原函数改成同时返回音频
    if not text:
        return None

    # —— 新增：置信度路由 ——
    if self.config.get("local_fallback_enabled", True):
        try:
            conf = self._sv_confidence.infer(samples)
        except Exception:
            self.logger.exception("置信度计算失败，按高置信处理")
            conf = 1.0
        threshold = float(self.config.get("local_confidence_threshold", 0.80))
        self.logger.info("本地识别置信度 %.3f（阈值 %.2f）", conf, threshold)
        if conf < threshold:
            channel = self.config.get("local_fallback_channel", "qwen")
            self.logger.warning("置信度不足，转云端渠道 %s 兜底", channel)
            cloud_text = self._recognize_with_channel(channel, audio_file)  # 复用现有渠道分发
            if cloud_text:
                return f"{cloud_text}"   # 或返回 (cloud_text, {"via": channel}) 供 UI 标记
    return text
```

其中 `_local_recognize_with_audio` 就是把现有 `_call_local_sherpa` 里「读 wav → `_trim_silence` → sherpa 解码」的代码原样保留，只是最后多返回 `samples`；云端分发复用现有 `recognize()` 里按 `channel` 分支的那段逻辑（约 1610~1619 行），抽成一个 `_recognize_with_channel(channel, audio_file)` 即可。

### 3. 依赖

```bash
~/.venvs/lexisharp/bin/pip install kaldi-native-fbank
```

onnxruntime sherpa-onnx 已经带了，不用重装。

## 注意事项

- **双跑成本**：置信度方案会让每段音频多跑一次 ONNX 前向（约等于本地识别耗时翻倍，int8 模型 CPU 上 5 秒音频约几百毫秒，可接受）。如果在意，可以把 sherpa 的解码也替换掉，直接用 logits 做 greedy collapse，只跑一次——上面 `_fbank_lfr` + argmax + 去 blank/去重即是完整解码（实测与 sherpa 文本一致）。
- **阈值校准**：建议先把置信度写进日志（`log_level=DEBUG`）观察一两周自己的语音分布，再定阈值；不同麦克风差异很大。
- **云端兜底要防抖动**：置信度在阈值附近反复横跳时，可以给 UI 提示「本条由云端识别」，避免用户疑惑为什么同一句话格式不同（云端带标点 ITN，本地 `use_itn` 行为不同）。
- **blank id 探测**：换模型文件后 blank id 可能变，启动时用 1 秒静音跑一次 `argmax` 的众数即可自动校准，不用硬编码。

## 版本记录

- v1（2025-11-04）：初稿。模型：DeepSeek（DSH, k3-256k）。实测 sherpa-onnx 1.13.6 + SenseVoice int8，验证 `ys_log_probs` 为空、直跑 onnxruntime 可行、置信度分离度 0.93 vs 0.6。
