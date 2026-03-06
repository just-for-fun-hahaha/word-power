#!/usr/bin/env python3
"""下载 YouTube 字幕到本地 SRT 文件。

默认行为：
  - 默认尝试从 Safari 读取 cookies，降低直接下载被限制的概率
  - 默认自动探测可用 JS runtime，降低 YouTube challenge 失败概率
  - 优先下载人工字幕；传 --allow-generated 时允许回退到自动字幕
  - 优先输出 SRT；若源字幕不是 SRT，则尝试转换为 SRT

使用方式（建议在已有 venv 中执行）：
  1) 安装依赖：
     pip install -r requirements.txt
  2) 下载字幕：
     python3 scripts/download_youtube_subtitles.py "https://www.youtube.com/watch?v=xxxxx"
  3) 常用参数：
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --lang en-GB
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --allow-generated
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --list-subs
     python3 scripts/download_youtube_subtitles.py "https://youtu.be/xxxxx" --output downloads/demo.srt
"""

from __future__ import annotations

import argparse
import re
import shutil
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlparse


YOUTUBE_VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")
DEFAULT_COOKIES_BROWSER = "safari"
DEFAULT_REMOTE_COMPONENTS = ("ejs:github",)
JS_RUNTIME_BINARIES = (
    ("deno", "deno"),
    ("node", "node"),
    ("bun", "bun"),
    ("quickjs", "qjs"),
)


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


def detect_js_runtimes() -> dict[str, dict]:
    runtimes: dict[str, dict] = {}
    for runtime_name, binary_name in JS_RUNTIME_BINARIES:
        if shutil.which(binary_name):
            runtimes[runtime_name] = {}
    return runtimes


def normalize_browser_name(value: str) -> str:
    normalized = (value or "").strip().lower()
    if normalized in {"", "none", "off", "disable", "disabled"}:
        return ""
    return normalized


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
        help="输出文件路径，默认 downloads/<video_id>.<actual_lang>.srt",
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
        "--js-runtime",
        default="auto",
        help="JS runtime，默认 auto（自动探测 deno/node/bun/quickjs）",
    )
    parser.add_argument(
        "--list-subs",
        action="store_true",
        help="只列出可用字幕，不实际下载",
    )
    return parser.parse_args()


def build_common_ydl_options(args: argparse.Namespace) -> dict:
    options = {
        "noplaylist": True,
        "skip_download": True,
        "quiet": False,
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

    return options


def extract_subtitle_catalog(url: str, args: argparse.Namespace) -> dict:
    YoutubeDL = _load_yt_dlp()
    ydl_opts = build_common_ydl_options(args)

    with YoutubeDL(ydl_opts) as ydl:
        return ydl.extract_info(url, download=False)


def choose_language_key(catalog: dict, requested: str) -> str | None:
    target = (requested or "").strip().lower()
    lowered = {str(key).lower(): str(key) for key in (catalog or {}).keys()}

    if target in lowered:
        return lowered[target]

    if target.startswith("en"):
        for code_lower, code_original in lowered.items():
            if code_lower.startswith("en"):
                return code_original

    return None


def select_subtitle_source(info: dict, language_code: str, allow_generated: bool) -> tuple[str, str]:
    subtitles = info.get("subtitles") or {}
    auto_subtitles = info.get("automatic_captions") or {}

    manual_lang = choose_language_key(subtitles, language_code)
    if manual_lang:
        return "manual", manual_lang

    if allow_generated:
        auto_lang = choose_language_key(auto_subtitles, language_code)
        if auto_lang:
            return "generated", auto_lang

    if allow_generated:
        raise FileNotFoundError(
            f"未找到 language_code={language_code} 的可用字幕（人工字幕和自动字幕都没有）"
        )

    raise FileNotFoundError(
        f"未找到 language_code={language_code} 的人工字幕；如接受自动字幕，可追加 --allow-generated"
    )


def print_subtitle_catalog(info: dict) -> None:
    subtitles = info.get("subtitles") or {}
    auto_subtitles = info.get("automatic_captions") or {}

    print("可用字幕：")
    if not subtitles and not auto_subtitles:
        print("  无")
        return

    for language_code in sorted(subtitles):
        formats = subtitles.get(language_code) or []
        exts = sorted({str(item.get("ext", "") or "") for item in formats if item.get("ext")})
        suffix = f" [{', '.join(exts)}]" if exts else ""
        print(f"  - {language_code}: 人工字幕{suffix}")

    for language_code in sorted(auto_subtitles):
        if language_code in subtitles:
            continue
        formats = auto_subtitles.get(language_code) or []
        exts = sorted({str(item.get('ext', '') or '') for item in formats if item.get("ext")})
        suffix = f" [{', '.join(exts)}]" if exts else ""
        print(f"  - {language_code}: 自动字幕{suffix}")


def build_download_ydl_options(
    args: argparse.Namespace,
    temp_dir: Path,
    source_kind: str,
    selected_lang: str,
) -> dict:
    options = build_common_ydl_options(args)
    options.update(
        {
            "paths": {"home": str(temp_dir)},
            "outtmpl": {"default": "%(id)s.%(ext)s"},
            "skip_download": True,
            "writesubtitles": source_kind == "manual",
            "writeautomaticsub": source_kind == "generated",
            "subtitleslangs": [selected_lang],
            "subtitlesformat": "srt/best",
            "convertsubtitles": "srt",
            "restrictfilenames": False,
        }
    )
    return options


def find_downloaded_subtitle(temp_dir: Path, selected_lang: str) -> Path | None:
    preferred = sorted(
        temp_dir.glob(f"*.{selected_lang}.srt"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if preferred:
        return preferred[0]

    fallback = sorted(
        temp_dir.glob("*.srt"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return fallback[0] if fallback else None


def validate_subtitle_output(file_path: Path) -> None:
    if not file_path.exists():
        raise RuntimeError("下载完成后未找到字幕文件。")
    if file_path.suffix.lower() != ".srt":
        raise RuntimeError(f"字幕下载结果不是 .srt 文件：{file_path.name}")
    if not file_path.read_text(encoding="utf-8").strip():
        raise RuntimeError("字幕内容为空")


def build_output_path(video_id: str, selected_lang: str, explicit_output: str) -> Path:
    if explicit_output:
        return Path(explicit_output)
    return Path("downloads") / f"{video_id}.{selected_lang}.srt"


def main() -> int:
    args = parse_args()
    url = normalize_youtube_input(args.youtube_url)
    video_id = extract_youtube_video_id(args.youtube_url)

    common_ydl_opts = build_common_ydl_options(args)
    configured_runtimes = list((common_ydl_opts.get("js_runtimes") or {}).keys())
    if configured_runtimes:
        print(f"已启用 JS runtime: {', '.join(configured_runtimes)}")
        print(f"已启用远程组件: {', '.join(common_ydl_opts.get('remote_components', []))}")
    else:
        print(
            "警告: 未检测到可用的 JS runtime。若遇到 YouTube challenge 错误，"
            "请安装 deno 或 node，或显式传 --js-runtime node。"
        )

    browser_name = normalize_browser_name(args.cookies_from_browser)
    if browser_name and args.cookies:
        print("提示: 已同时传入 --cookies-from-browser 和 --cookies，yt-dlp 会优先使用显式 cookies 文件。")

    try:
        info = extract_subtitle_catalog(url, args)
        if args.list_subs:
            print_subtitle_catalog(info)
            return 0

        source_kind, selected_lang = select_subtitle_source(info, args.lang, args.allow_generated)
        output_path = build_output_path(video_id, selected_lang, args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        YoutubeDL = _load_yt_dlp()
        with tempfile.TemporaryDirectory(prefix="yt_subs_") as temp_dir_name:
            temp_dir = Path(temp_dir_name)
            ydl_opts = build_download_ydl_options(args, temp_dir, source_kind, selected_lang)
            with YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])

            subtitle_file = find_downloaded_subtitle(temp_dir, selected_lang)
            if subtitle_file is None:
                raise RuntimeError("字幕下载完成后未定位到输出文件。")

            validate_subtitle_output(subtitle_file)
            if output_path.exists():
                output_path.unlink()
            subtitle_file.replace(output_path)

        kind_label = "人工字幕" if source_kind == "manual" else "自动字幕"
        print(f"已保存字幕: {output_path}")
        print(f"字幕类型: {kind_label}")
        print(f"语言代码: {selected_lang}")
        return 0
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
                "YouTube challenge 解算失败，导致字幕信息没有正确拿到。\n"
                "已在脚本里启用 JS runtime 自动探测；若仍失败，请优先确认：\n"
                "1) 机器上已安装 node 或 deno；\n"
                "2) 继续尝试显式传 --js-runtime node；\n"
                "3) 先执行 --list-subs 看是否能列出字幕；\n"
                "4) 如仍失败，再尝试改用 --cookies-from-browser chrome。"
            ) from exc
        if "blocked by YouTube" in message or "requests from your IP" in message:
            raise RuntimeError(
                "YouTube 当前仍在拦截这条字幕请求。\n"
                "字幕脚本已切到 yt-dlp 路径；如果仍出现该报错，优先尝试：\n"
                "1) 显式传 --cookies-from-browser safari 或 chrome；\n"
                "2) 先执行 --list-subs 确认当前账号是否能看到字幕；\n"
                "3) 如浏览器能正常看到字幕，但脚本仍失败，再导出 cookies.txt 后用 --cookies。"
            ) from exc
        raise


if __name__ == "__main__":
    raise SystemExit(main())
