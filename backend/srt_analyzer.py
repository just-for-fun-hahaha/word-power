#!/usr/bin/env python3
"""
SRT文件分析模块
"""
import csv
import html
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse
from urllib.request import urlopen

try:
    from nltk.corpus import wordnet
    from nltk.stem import WordNetLemmatizer
    from nltk.tag import pos_tag
except ImportError:
    print("错误: 请先安装 nltk")
    raise

# 获取项目根目录
PROJECT_ROOT = Path(__file__).parent.parent

# 初始化词形还原器
lemmatizer = WordNetLemmatizer()
YOUTUBE_VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")


def get_wordnet_pos(word, pos_tag):
    """将NLTK的POS标签转换为WordNet的POS标签"""
    tag = pos_tag[0].upper()
    tag_dict = {
        "J": wordnet.ADJ,
        "N": wordnet.NOUN,
        "V": wordnet.VERB,
        "R": wordnet.ADV,
    }
    return tag_dict.get(tag, wordnet.NOUN)


def clean_srt_content(content):
    """清洗SRT字幕内容"""
    lines = content.split("\n")
    cleaned_lines = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.isdigit():
            continue
        if re.match(
            r"\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}", line
        ):
            continue
        line = re.sub(r"<[^>]+>", "", line)
        cleaned_lines.append(line)

    return "\n".join(cleaned_lines)


def extract_words_from_text(text):
    """从文本中提取英文单词"""
    word_pattern = r"\b[a-zA-Z]+(?:-[a-zA-Z]+)*\b"
    words = re.findall(word_pattern, text)
    words = [
        w.lower() for w in words if len(w) >= 2 or w.lower() in ["a", "i"]
    ]
    return words


def lemmatize_words(words):
    """将单词转换为原型"""
    if not words:
        return []

    tagged_words = pos_tag(words)
    lemmatized_words = []
    for word, pos in tagged_words:
        wordnet_pos = get_wordnet_pos(word, pos)
        lemma = lemmatizer.lemmatize(word, pos=wordnet_pos)
        lemmatized_words.append(lemma)

    return lemmatized_words


def load_word_freq():
    """加载words_freq.csv词频数据"""
    freq_file = PROJECT_ROOT / "words_freq.csv"
    word_freq = {}

    if freq_file.exists():
        try:
            with open(freq_file, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if not row or "word" not in row:
                        continue
                    try:
                        word = row["word"].lower()
                        freq = int(row.get("frequency", 0))
                        word_freq[word] = freq
                    except (ValueError, KeyError):
                        # 跳过格式错误的行
                        continue
        except Exception as e:
            print(f"警告: 读取 words_freq.csv 时出错: {e}")

    return word_freq


def load_word_tags():
    """从word_labels.csv加载单词标签"""
    labels_file = PROJECT_ROOT / "word_labels.csv"
    word_tags = {}

    if labels_file.exists():
        try:
            with open(labels_file, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if not row or "word" not in row:
                        continue
                    word = row["word"].strip().lower()
                    label = row.get("label", "").strip()
                    if word and label:
                        word_tags[word] = label
        except Exception as e:
            print(f"警告: 读取 word_labels.csv 时出错: {e}")
    else:
        print(
            "警告: word_labels.csv 不存在，"
            "请先运行 scripts/generate_word_labels.py 生成标签文件"
        )

    return word_tags


def load_mastered_words():
    """加载已标记为"烂熟于心"的单词列表"""
    mastered_file = PROJECT_ROOT / "mastered_words.csv"
    mastered_words = {}

    if mastered_file.exists():
        try:
            with open(mastered_file, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if not row or "word" not in row:
                        continue
                    word = row["word"].strip().lower()
                    if word:
                        date = row.get("date", "").strip()
                        mastered_words[word] = date
        except Exception as e:
            # 如果CSV格式有问题，返回空字典
            print(f"警告: 读取 mastered_words.csv 时出错: {e}")
            pass

    return mastered_words


def mark_word_mastered(word, date=None):
    """将单词标记为"烂熟于心"，保存到mastered_words.csv"""
    if date is None:
        date = datetime.now().strftime("%Y-%m-%d")

    mastered_file = PROJECT_ROOT / "mastered_words.csv"
    word_lower = word.lower()

    # 读取现有数据
    mastered_words = load_mastered_words()

    # 添加或更新单词
    mastered_words[word_lower] = date

    # 写入CSV文件
    try:
        with open(mastered_file, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["word", "date"])
            for w, d in sorted(mastered_words.items()):
                writer.writerow([w, d])
        return True
    except Exception as e:
        print(f"保存已标记单词时出错: {e}")
        return False


def unmark_word_mastered(word):
    """取消单词的"烂熟于心"标记"""
    mastered_file = PROJECT_ROOT / "mastered_words.csv"
    word_lower = word.lower()

    # 读取现有数据
    mastered_words = load_mastered_words()

    # 删除单词
    if word_lower in mastered_words:
        del mastered_words[word_lower]

    # 写入CSV文件
    try:
        with open(mastered_file, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["word", "date"])
            for w, d in sorted(mastered_words.items()):
                writer.writerow([w, d])
        return True
    except Exception as e:
        print(f"保存已标记单词时出错: {e}")
        return False


def analyze_srt_file(file_path):
    """分析单个SRT文件，返回高频词"""
    srt_path = PROJECT_ROOT / file_path.lstrip("/")

    if not srt_path.exists():
        raise FileNotFoundError(f"文件不存在: {file_path}")

    # 读取文件
    with open(srt_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # 处理内容
    cleaned_content = clean_srt_content(content)
    words = extract_words_from_text(cleaned_content)
    lemmatized_words = lemmatize_words(words)

    # 统计词频
    word_count = Counter(lemmatized_words)

    # 加载全局词频和标签
    global_freq = load_word_freq()
    word_tags = load_word_tags()

    # 加载已标记为"烂熟于心"的单词
    mastered_words = load_mastered_words()

    # 构建结果（按全局词频排序）
    results = []
    for word, count in word_count.items():
        global_frequency = global_freq.get(word, 0)

        # 从词表文件获取标签
        label = word_tags.get(word, "")
        tags = []
        if label == "3000":
            tags.append("常用3000")
        elif label == "5000":
            tags.append("常用5000")
        elif label == "10000":
            tags.append("常用10000")

        # 检查是否已标记为"烂熟于心"
        is_mastered = word in mastered_words

        results.append(
            {
                "word": word,
                "count": count,  # 在当前文件中出现的次数
                "frequency": global_frequency,  # 全局词频
                "tags": tags,
                "mastered": is_mastered,  # 是否已标记为"烂熟于心"
                "mastered_date": mastered_words.get(word, ""),  # 标记日期
            }
        )

    # 排序：未标记的按词频降序，已标记的排最后
    results.sort(key=lambda x: (x["mastered"], -x["frequency"], x["word"]))

    return results


def get_learning_progress():
    """获取3000/5000/10000词的学习进度"""
    # 加载已掌握的单词
    mastered_words = load_mastered_words()
    mastered_set = set(mastered_words.keys())

    progress = {}

    # 读取各个词表文件
    word_files = {
        "3000": PROJECT_ROOT / "words_3000.txt",
        "5000": PROJECT_ROOT / "words_5000.txt",
        "10000": PROJECT_ROOT / "words_10000.txt",
    }

    for label, file_path in word_files.items():
        total = 0
        mastered = 0

        if file_path.exists():
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    for line in f:
                        word = line.strip().lower()
                        if word:
                            total += 1
                            if word in mastered_set:
                                mastered += 1
            except Exception as e:
                print(f"警告: 读取 {file_path} 时出错: {e}")
                continue

        percentage = (mastered / total * 100) if total > 0 else 0

        progress[label] = {
            "total": total,
            "mastered": mastered,
            "percentage": round(percentage, 1),
        }

    return progress


def get_unmastered_words(label):
    """获取指定词表中未掌握的单词列表"""
    # 加载已掌握的单词
    mastered_words = load_mastered_words()
    mastered_set = set(mastered_words.keys())

    # 根据label确定文件路径
    word_files = {
        "3000": PROJECT_ROOT / "words_3000.txt",
        "5000": PROJECT_ROOT / "words_5000.txt",
        "10000": PROJECT_ROOT / "words_10000.txt",
    }

    file_path = word_files.get(label)
    if not file_path or not file_path.exists():
        return []

    unmastered_words = []
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                word = line.strip().lower()
                if word and word not in mastered_set:
                    unmastered_words.append(word)
    except Exception as e:
        print(f"警告: 读取 {file_path} 时出错: {e}")
        return []

    return sorted(unmastered_words)


def analyze_txt_file(file_path):
    """分析指定TXT文件，按顺序列出所有不重复的单词"""
    txt_path = PROJECT_ROOT / file_path.lstrip("/")

    if not txt_path.exists():
        raise FileNotFoundError(f"文件不存在: {file_path}")

    with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    return analyze_txt_content(content)


def analyze_txt_content(content):
    """分析TXT文本内容，按顺序列出所有不重复的单词（含标签和mastered状态）"""
    # 提取单词
    words = extract_words_from_text(content)

    # 词形还原
    lemmatized_words = lemmatize_words(words)

    # 去重但保持顺序
    seen = set()
    unique_words = []
    for word in lemmatized_words:
        if word not in seen:
            seen.add(word)
            unique_words.append(word)

    # 加载标签和mastered数据
    word_tags = load_word_tags()
    mastered_words = load_mastered_words()

    # 构建结果
    results = []
    for word in unique_words:
        label = word_tags.get(word, "")
        tags = []
        if label == "3000":
            tags.append("常用3000")
        elif label == "5000":
            tags.append("常用5000")
        elif label == "10000":
            tags.append("常用10000")

        is_mastered = word in mastered_words

        results.append(
            {
                "word": word,
                "tags": tags,
                "mastered": is_mastered,
                "mastered_date": mastered_words.get(word, ""),
            }
        )

    # 排序：未标记的保持原始顺序，已标记的排最后
    unmastered = [r for r in results if not r["mastered"]]
    mastered = [r for r in results if r["mastered"]]
    results = unmastered + mastered

    return results


def _load_youtube_transcript_api():
    """按需加载youtube-transcript-api依赖"""
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError as e:
        raise RuntimeError(
            "缺少 youtube-transcript-api 依赖，"
            "请先在 backend/requirements.txt 安装后重试"
        ) from e

    return YouTubeTranscriptApi


def extract_youtube_video_id(youtube_url):
    """从YouTube链接中提取视频ID"""
    if not youtube_url or not youtube_url.strip():
        raise ValueError("缺少YouTube链接")

    value = youtube_url.strip()

    # 允许直接输入视频ID
    if YOUTUBE_VIDEO_ID_PATTERN.fullmatch(value):
        return value

    parsed = urlparse(value)
    if not parsed.netloc and parsed.path:
        normalized = parsed.path.strip()
        if normalized.startswith(
            ("youtube.com/", "www.youtube.com/", "m.youtube.com/", "youtu.be/")
        ):
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
        raise ValueError("无效的YouTube视频链接")

    return video_id


def _list_youtube_transcripts(video_id):
    """兼容不同youtube-transcript-api版本，返回字幕对象列表"""
    YouTubeTranscriptApi = _load_youtube_transcript_api()

    # 新版本：实例方法 list(video_id)
    try:
        api = YouTubeTranscriptApi()
        if hasattr(api, "list"):
            return list(api.list(video_id))
    except TypeError:
        # 旧版本可能不支持实例化
        pass

    # 旧版本：类方法 list_transcripts(video_id)
    if hasattr(YouTubeTranscriptApi, "list_transcripts"):
        return list(YouTubeTranscriptApi.list_transcripts(video_id))

    raise RuntimeError(
        "当前 youtube-transcript-api 版本不支持列出字幕，"
        "请升级依赖后重试"
    )


def _is_english_subtitle(language_code):
    code = (language_code or "").strip().lower()
    return code == "en" or code.startswith("en-")


def _get_youtube_video_title(video_id):
    """通过YouTube oEmbed接口获取视频标题（失败时返回空字符串）"""
    try:
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        oembed_url = (
            "https://www.youtube.com/oembed"
            f"?url={quote(video_url, safe='')}&format=json"
        )
        with urlopen(oembed_url, timeout=5) as response:
            data = json.loads(response.read().decode("utf-8"))
            return data.get("title", "")
    except Exception:
        return ""


def get_youtube_subtitles(youtube_url):
    """获取YouTube视频的英文人工字幕列表（非自动生成）"""
    video_id = extract_youtube_video_id(youtube_url)
    transcripts = _list_youtube_transcripts(video_id)

    subtitles = []
    seen_codes = set()

    for transcript in transcripts:
        language_code = (getattr(transcript, "language_code", "") or "").strip()
        if not _is_english_subtitle(language_code):
            continue
        if bool(getattr(transcript, "is_generated", False)):
            continue
        if language_code in seen_codes:
            continue

        seen_codes.add(language_code)
        subtitles.append(
            {
                "language_code": language_code,
                "language": getattr(transcript, "language", language_code),
            }
        )

    subtitles.sort(key=lambda item: (item["language_code"] != "en", item["language_code"]))

    return {
        "video_id": video_id,
        "video_title": _get_youtube_video_title(video_id),
        "subtitles": subtitles,
    }


def analyze_youtube_subtitle(youtube_url, language_code):
    """分析指定YouTube视频中的英文人工字幕"""
    if not language_code or not str(language_code).strip():
        raise ValueError("缺少language_code参数")

    video_id = extract_youtube_video_id(youtube_url)
    transcripts = _list_youtube_transcripts(video_id)
    normalized_code = str(language_code).strip().lower()
    selected_transcript = None
    english_manual_codes = []

    for transcript in transcripts:
        current_code = (getattr(transcript, "language_code", "") or "").strip()
        if not _is_english_subtitle(current_code):
            continue
        if bool(getattr(transcript, "is_generated", False)):
            continue

        english_manual_codes.append(current_code)
        if current_code.lower() == normalized_code:
            selected_transcript = transcript
            break

    if selected_transcript is None:
        if not english_manual_codes:
            raise FileNotFoundError("该视频没有可用的英文人工字幕")
        raise FileNotFoundError(
            f"未找到 language_code={language_code} 的英文人工字幕"
        )

    transcript_items = selected_transcript.fetch()
    lines = []

    for item in transcript_items:
        if isinstance(item, dict):
            text = item.get("text", "")
        else:
            text = getattr(item, "text", "")
        text = html.unescape(str(text)).strip()
        if text:
            lines.append(text.replace("\n", " "))

    content = "\n".join(lines)
    return analyze_txt_content(content)


def get_srt_files():
    """获取inputs/srt目录下所有srt文件列表，按目录分组"""
    srt_dir = PROJECT_ROOT / "inputs" / "srt"
    files_by_dir = {}

    if srt_dir.exists():
        for srt_file in srt_dir.rglob("*.srt"):
            # 相对路径（用于前端显示和API调用）
            rel_path = srt_file.relative_to(PROJECT_ROOT)
            season = srt_file.parent.name

            if season not in files_by_dir:
                files_by_dir[season] = []

            files_by_dir[season].append(
                {
                    "path": str(rel_path).replace("\\", "/"),
                    "name": srt_file.name,
                }
            )

    # 对每个目录的文件排序
    for season in files_by_dir:
        files_by_dir[season].sort(key=lambda x: x["name"])

    # 转换为列表格式，按目录名排序
    result = [
        {
            "season": season,
            "files": files_by_dir[season],
        }
        for season in sorted(files_by_dir.keys())
    ]

    return result


def get_txt_files():
    """获取inputs/txt目录下所有txt文件列表"""
    txt_dir = PROJECT_ROOT / "inputs" / "txt"
    files = []

    if txt_dir.exists():
        for txt_file in sorted(txt_dir.glob("*.txt")):
            rel_path = txt_file.relative_to(PROJECT_ROOT)
            files.append(
                {
                    "path": str(rel_path).replace("\\", "/"),
                    "name": txt_file.stem,  # 不带扩展名的文件名
                }
            )

    return files


def get_learning_stats(granularity="day"):
    """获取学习统计数据（按天或按月）

    Args:
        granularity: "day" 或 "month"

    Returns:
        List[Dict]: [{"date": "2026-01-17", "cumulative": 10}, ...]
    """
    mastered_file = PROJECT_ROOT / "mastered_words.csv"

    if not mastered_file.exists():
        return []

    # 读取 mastered_words.csv
    date_counts = {}  # {date: count}

    try:
        with open(mastered_file, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not row or "word" not in row:
                    continue
                date = row.get("date", "").strip()
                if date:
                    if granularity == "month":
                        # 转换为月份格式 "2026-01"
                        date = date[:7] if len(date) >= 7 else date

                    date_counts[date] = date_counts.get(date, 0) + 1
    except Exception as e:
        print(f"警告: 读取 mastered_words.csv 时出错: {e}")
        return []

    # 按日期排序并计算累积值
    sorted_dates = sorted(date_counts.keys())
    cumulative = 0
    result = []

    for date in sorted_dates:
        cumulative += date_counts[date]
        result.append(
            {
                "date": date,
                "new_words": date_counts[date],
                "cumulative": cumulative,
            }
        )

    return result
