#!/usr/bin/env python3
"""下载 YouTube 字幕到本地 SRT 文件。

使用方式（建议在已有 venv 中执行）：
  1) 安装依赖：
     pip install -r requirements.txt
  2) 下载字幕：
     python3 scripts/download_youtube_subtitles.py "https://www.youtube.com/watch?v=xxxxx"
  3) 常用参数：
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --lang en-GB
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --allow-generated
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --output downloads/demo.srt
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from urllib.parse import parse_qs, urlparse


YOUTUBE_VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")


def extract_youtube_video_id(youtube_url: str) -> str:
    value = (youtube_url or "").strip()
    if not value:
        raise ValueError("缺少 YouTube 链接")

    if YOUTUBE_VIDEO_ID_PATTERN.fullmatch(value):
        return value

    parsed = urlparse(value)
    if not parsed.netloc and parsed.path:
        normalized = parsed.path.strip()
        if normalized.startswith(("youtube.com/", "www.youtube.com/", "m.youtube.com/", "youtu.be/")):
            parsed = urlparse(f"https://{normalized}")

    host = parsed.netloc.lower()
    path = parsed.path.strip("/")
    video_id = ""

    if host in {"youtu.be", "www.youtu.be"}:
        video_id = path.split("/")[0] if path else ""
    elif "youtube.com" in host or "youtube-nocookie.com" in host:
        if path == "watch":
            video_id = parse_qs(parsed.query).get("v", [""])[0]
        elif path.startswith("embed/"):
            parts = path.split("/")
            video_id = parts[1] if len(parts) > 1 else ""
        elif path.startswith("shorts/") or path.startswith("live/"):
            parts = path.split("/")
            video_id = parts[1] if len(parts) > 1 else ""

    if not YOUTUBE_VIDEO_ID_PATTERN.fullmatch(video_id):
        raise ValueError("无效的 YouTube 视频链接")

    return video_id


def _load_api_class():
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError as exc:
        raise RuntimeError(
            "缺少 youtube-transcript-api 依赖，请先执行: pip install -r requirements.txt"
        ) from exc

    return YouTubeTranscriptApi


def list_transcripts(video_id: str):
    YouTubeTranscriptApi = _load_api_class()

    try:
        api = YouTubeTranscriptApi()
        if hasattr(api, "list"):
            return list(api.list(video_id))
    except TypeError:
        pass

    if hasattr(YouTubeTranscriptApi, "list_transcripts"):
        return list(YouTubeTranscriptApi.list_transcripts(video_id))

    raise RuntimeError("当前 youtube-transcript-api 版本不支持列出字幕")


def select_transcript(video_id: str, language_code: str, allow_generated: bool = False):
    transcripts = list_transcripts(video_id)
    target = (language_code or "").strip().lower()

    def available(transcript) -> bool:
        if allow_generated:
            return True
        return not bool(getattr(transcript, "is_generated", False))

    # 1) 精确匹配 language_code
    for transcript in transcripts:
        code = (getattr(transcript, "language_code", "") or "").strip().lower()
        if code == target and available(transcript):
            return transcript

    # 2) en* 兜底（优先人工）
    if target.startswith("en"):
        for transcript in transcripts:
            code = (getattr(transcript, "language_code", "") or "").strip().lower()
            if code.startswith("en") and available(transcript):
                return transcript

    # 3) 允许生成字幕时再兜底
    if allow_generated:
        for transcript in transcripts:
            code = (getattr(transcript, "language_code", "") or "").strip().lower()
            if code == target or (target.startswith("en") and code.startswith("en")):
                return transcript

    raise FileNotFoundError(
        f"未找到 language_code={language_code} 的可用字幕（allow_generated={allow_generated}）"
    )


def format_srt_timestamp(seconds: float) -> str:
    total_ms = max(0, int(round(seconds * 1000)))
    hours = total_ms // 3_600_000
    minutes = (total_ms % 3_600_000) // 60_000
    secs = (total_ms % 60_000) // 1000
    millis = total_ms % 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def transcript_to_srt(transcript_items) -> str:
    lines = []

    for idx, item in enumerate(transcript_items, start=1):
        if isinstance(item, dict):
            text = str(item.get("text", "")).strip()
            start = float(item.get("start", 0) or 0)
            duration = float(item.get("duration", 0) or 0)
        else:
            text = str(getattr(item, "text", "")).strip()
            start = float(getattr(item, "start", 0) or 0)
            duration = float(getattr(item, "duration", 0) or 0)

        if not text:
            continue

        end = start + (duration if duration > 0 else 2.0)
        clean_text = " ".join(text.replace("\n", " ").split())

        lines.append(str(idx))
        lines.append(f"{format_srt_timestamp(start)} --> {format_srt_timestamp(end)}")
        lines.append(clean_text)
        lines.append("")

    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="下载 YouTube 字幕到本地 SRT")
    parser.add_argument("youtube_url", help="YouTube 视频链接或视频 ID")
    parser.add_argument("--lang", default="en", help="语言代码，默认 en")
    parser.add_argument(
        "--allow-generated",
        action="store_true",
        help="允许下载自动生成字幕（默认只下载人工字幕）",
    )
    parser.add_argument(
        "--output",
        default="",
        help="输出文件路径，默认 downloads/<video_id>.<lang>.srt",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    video_id = extract_youtube_video_id(args.youtube_url)
    transcript = select_transcript(video_id, args.lang, args.allow_generated)
    transcript_items = transcript.fetch()

    srt_content = transcript_to_srt(transcript_items)
    if not srt_content.strip():
        raise RuntimeError("字幕内容为空")

    output_path = Path(args.output) if args.output else Path("downloads") / f"{video_id}.{args.lang}.srt"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(srt_content, encoding="utf-8")

    print(f"已保存字幕: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
