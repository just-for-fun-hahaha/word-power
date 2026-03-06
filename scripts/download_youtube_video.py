#!/usr/bin/env python3
"""下载 YouTube 视频到本地文件。

默认行为：
  - 优先下载不高于 720p 的 H.264/AAC mp4 视频
  - 默认尝试从 Safari 读取 cookies，降低直接下载被限制的概率
  - 要求系统提供 ffmpeg 和 ffprobe，确保输出是真正可校验的 mp4
  - 若最终结果不是 QuickTime 友好的 H.264/AAC MP4，会直接报错并删除输出文件

使用方式（建议在已有 venv 中执行）：
  1) 安装依赖：
     pip install -r requirements.txt
  2) 下载视频：
     python3 scripts/download_youtube_video.py "https://www.youtube.com/watch?v=xxxxx"
  3) 常用参数：
     python3 scripts/download_youtube_video.py "https://youtu.be/xxxxx" --output-dir downloads/videos
     python3 scripts/download_youtube_video.py "https://youtu.be/xxxxx" --cookies-from-browser chrome
     python3 scripts/download_youtube_video.py "https://youtu.be/xxxxx" --cookies-from-browser none
     python3 scripts/download_youtube_video.py "https://youtu.be/xxxxx" --list-formats
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path
from urllib.parse import parse_qs, urlparse


YOUTUBE_VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")
DEFAULT_OUTPUT_TEMPLATE = "%(title).200B [%(id)s].%(ext)s"
DEFAULT_COOKIES_BROWSER = "safari"
DEFAULT_REMOTE_COMPONENTS = ("ejs:github",)
JS_RUNTIME_BINARIES = (
    ("deno", "deno"),
    ("node", "node"),
    ("bun", "bun"),
    ("quickjs", "qjs"),
)
ALLOWED_VIDEO_CODECS = {"h264"}
ALLOWED_AUDIO_CODECS = {"aac"}


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


def normalize_youtube_input(youtube_url: str) -> str:
    value = (youtube_url or "").strip()
    if YOUTUBE_VIDEO_ID_PATTERN.fullmatch(value):
        return f"https://www.youtube.com/watch?v={value}"

    extract_youtube_video_id(value)
    return value


def _load_yt_dlp():
    try:
        from yt_dlp import YoutubeDL
    except ImportError as exc:
        raise RuntimeError(
            "缺少 yt-dlp 依赖，请先执行: pip install -r requirements.txt"
        ) from exc

    return YoutubeDL


def has_ffmpeg() -> bool:
    return bool(shutil.which("ffmpeg"))


def has_ffprobe() -> bool:
    return bool(shutil.which("ffprobe"))


def detect_js_runtimes() -> dict[str, dict]:
    runtimes: dict[str, dict] = {}
    for runtime_name, binary_name in JS_RUNTIME_BINARIES:
        if shutil.which(binary_name):
            runtimes[runtime_name] = {}
    return runtimes


def build_format_selector(max_height: int) -> str:
    if not has_ffmpeg() or not has_ffprobe():
        raise RuntimeError(
            "缺少 ffmpeg 或 ffprobe。为保证输出是真正可播放且可校验的 mp4，"
            "当前脚本要求两者都可用后才允许下载。"
        )

    return (
        f"bv*[height<={max_height}][ext=mp4][vcodec~='^(avc1|h264)']+"
        f"ba[ext=m4a][acodec~='^(mp4a|aac)']/"
        f"b[height<={max_height}][ext=mp4][vcodec~='^(avc1|h264)'][acodec~='^(mp4a|aac)']/"
        f"bv*[height<={max_height}][vcodec~='^(avc1|h264)']+"
        f"ba[acodec~='^(mp4a|aac)']"
    )


def find_downloaded_file(info: dict, output_dir: Path) -> Path | None:
    requested = info.get("requested_downloads") or []
    for item in requested:
        filepath = item.get("filepath")
        if filepath:
            path = Path(filepath)
            if path.exists():
                return path

    possible_path = info.get("filepath")
    if possible_path:
        path = Path(possible_path)
        if path.exists():
            return path

    video_id = info.get("id", "")
    candidates = sorted(
        (
            path
            for path in output_dir.iterdir()
            if path.is_file() and f"[{video_id}]" in path.name
        ),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return candidates[0] if candidates else None


def validate_mp4_output(file_path: Path) -> None:
    if not file_path.exists():
        raise RuntimeError("下载完成后未找到输出文件。")

    if file_path.suffix.lower() != ".mp4":
        raise RuntimeError(f"下载结果不是 .mp4 文件：{file_path.name}")

    result = shutil.which("ffprobe")
    if not result:
        raise RuntimeError("缺少 ffprobe，无法校验输出是否为真实 mp4。")

    import subprocess

    probe = subprocess.run(
        [
            result,
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_streams",
            "-show_format",
            str(file_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if probe.returncode != 0:
        raise RuntimeError(f"ffprobe 无法读取输出文件：{file_path.name}")

    try:
        payload = json.loads(probe.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"无法解析 ffprobe 输出：{file_path.name}") from exc

    format_name = str(payload.get("format", {}).get("format_name", "") or "").lower()
    format_names = {item.strip() for item in format_name.split(",") if item.strip()}
    if "mov,mp4,m4a,3gp,3g2,mj2" in format_names:
        pass
    elif "mp4" in format_names:
        pass
    elif "mov" in format_names:
        pass
    else:
        raise RuntimeError(
            f"输出文件不是 MP4/MOV 容器，而是: {format_name or 'unknown'}"
        )

    streams = payload.get("streams") or []
    video_streams = [stream for stream in streams if stream.get("codec_type") == "video"]
    audio_streams = [stream for stream in streams if stream.get("codec_type") == "audio"]

    if not video_streams:
        raise RuntimeError("输出文件不包含视频轨。")
    if not audio_streams:
        raise RuntimeError("输出文件不包含音频轨。")

    video_codec = str(video_streams[0].get("codec_name", "") or "").lower()
    audio_codec = str(audio_streams[0].get("codec_name", "") or "").lower()

    if video_codec not in ALLOWED_VIDEO_CODECS:
        raise RuntimeError(
            "输出文件的视频编码不兼容 QuickTime："
            f"{video_codec or 'unknown'}。当前脚本只接受 H.264。"
        )
    if audio_codec not in ALLOWED_AUDIO_CODECS:
        raise RuntimeError(
            "输出文件的音频编码不兼容 QuickTime："
            f"{audio_codec or 'unknown'}。当前脚本只接受 AAC。"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="下载 YouTube 视频到本地文件")
    parser.add_argument("youtube_url", help="YouTube 视频链接或视频 ID")
    parser.add_argument(
        "--height",
        type=int,
        default=720,
        help="最大清晰度上限，默认 720",
    )
    parser.add_argument(
        "--output-dir",
        default="downloads/videos",
        help="输出目录，默认 downloads/videos",
    )
    parser.add_argument(
        "--output-template",
        default=DEFAULT_OUTPUT_TEMPLATE,
        help=f"输出文件名模板，默认 {DEFAULT_OUTPUT_TEMPLATE.replace('%', '%%')}",
    )
    parser.add_argument(
        "--cookies-from-browser",
        default=DEFAULT_COOKIES_BROWSER,
        help=f"从浏览器读取 cookies，默认 {DEFAULT_COOKIES_BROWSER}",
    )
    parser.add_argument(
        "--cookies",
        default="",
        help="cookies.txt 文件路径",
    )
    parser.add_argument(
        "--user-agent",
        default="",
        help="可选，自定义 User-Agent",
    )
    parser.add_argument(
        "--list-formats",
        action="store_true",
        help="只列出可用格式，不实际下载",
    )
    parser.add_argument(
        "--js-runtime",
        default="auto",
        help="JS runtime，默认 auto（自动探测 deno/node/bun/quickjs）",
    )
    return parser.parse_args()


def normalize_browser_name(value: str) -> str:
    normalized = (value or "").strip().lower()
    if normalized in {"", "none", "off", "disable", "disabled"}:
        return ""
    return normalized


def build_ydl_options(args: argparse.Namespace) -> tuple[dict, str]:
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    format_selector = build_format_selector(args.height)

    options = {
        "format": format_selector,
        "paths": {"home": str(output_dir)},
        "outtmpl": {"default": args.output_template},
        "noplaylist": True,
        "merge_output_format": "mp4",
        "restrictfilenames": False,
    }

    js_runtime = (args.js_runtime or "").strip().lower()
    if js_runtime in {"", "auto"}:
        detected_runtimes = detect_js_runtimes()
    elif js_runtime in {"none", "off", "disable", "disabled"}:
        detected_runtimes = {}
    else:
        detected_runtimes = {js_runtime: {}}

    if detected_runtimes:
        options["js_runtimes"] = detected_runtimes
        options["remote_components"] = list(DEFAULT_REMOTE_COMPONENTS)

    browser_name = normalize_browser_name(args.cookies_from_browser)
    if browser_name and not args.cookies:
        options["cookiesfrombrowser"] = (browser_name,)
    if args.cookies:
        options["cookiefile"] = args.cookies
    if args.user_agent:
        options["user_agent"] = args.user_agent
    if args.list_formats:
        options["listformats"] = True
        options["skip_download"] = True

    return options, format_selector


def main() -> int:
    args = parse_args()
    url = normalize_youtube_input(args.youtube_url)
    YoutubeDL = _load_yt_dlp()
    ydl_opts, format_selector = build_ydl_options(args)
    configured_runtimes = list((ydl_opts.get("js_runtimes") or {}).keys())

    if configured_runtimes:
        print(f"已启用 JS runtime: {', '.join(configured_runtimes)}")
        print(f"已启用远程组件: {', '.join(ydl_opts.get('remote_components', []))}")
    else:
        print(
            "警告: 未检测到可用的 JS runtime。若遇到 YouTube challenge 错误，"
            "请安装 deno 或 node，或显式传 --js-runtime node。"
        )

    browser_name = normalize_browser_name(args.cookies_from_browser)

    if browser_name and args.cookies:
        print("提示: 已同时传入 --cookies-from-browser 和 --cookies，yt-dlp 会优先使用显式 cookies 文件。")

    try:
        with YoutubeDL(ydl_opts) as ydl:
            if args.list_formats:
                print(f"格式选择器: {format_selector}")
                ydl.download([url])
                return 0

            info = ydl.extract_info(url, download=True)
            downloaded_file = find_downloaded_file(info, Path(args.output_dir))
            if downloaded_file is None:
                raise RuntimeError("下载完成后未定位到输出文件。")

            try:
                validate_mp4_output(downloaded_file)
            except Exception:
                downloaded_file.unlink(missing_ok=True)
                raise

            title = info.get("title") or extract_youtube_video_id(url)
            print(f"已下载视频: {title}")
            print(f"输出文件: {downloaded_file.resolve()}")
            print(f"格式策略: {format_selector}")
    except Exception as exc:
        message = str(exc)
        if "Cookies.binarycookies" in message and "Operation not permitted" in message:
            raise RuntimeError(
                "无法读取 Safari cookies。macOS 拒绝了 Cookies.binarycookies 的访问权限。\n"
                "可选解决方案：\n"
                "1) 给你当前使用的终端/IDE 授予 Full Disk Access；\n"
                "2) 改用 --cookies-from-browser chrome；\n"
                "3) 先导出 cookies.txt，再用 --cookies /path/to/cookies.txt；\n"
                "4) 若要禁用浏览器 cookies，传 --cookies-from-browser none。"
            ) from exc
        if "n challenge solving failed" in message:
            raise RuntimeError(
                "YouTube challenge 解算失败，导致可下载格式没有正确拿到。\n"
                "已在脚本里启用 JS runtime 自动探测；若仍失败，请优先确认：\n"
                "1) 机器上已安装 node 或 deno；\n"
                "2) 继续尝试显式传 --js-runtime node；\n"
                "3) 先执行 --list-formats 看是否仍只剩图片格式；\n"
                "4) 如仍失败，再尝试改用 --cookies-from-browser chrome。"
            ) from exc
        if "Requested format is not available" in message:
            raise RuntimeError(
                "当前视频没有找到符合条件的下载格式。\n"
                "当前脚本只接受不高于目标清晰度、且对 QuickTime 友好的 H.264/AAC 格式。\n"
                "可先执行 --list-formats 确认可用源；若确实没有匹配格式，可以改低 --height，"
                "或接受脚本继续保持失败而不产出不兼容文件。"
            ) from exc
        raise

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
