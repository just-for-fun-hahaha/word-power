#!/usr/bin/env python3
"""
SRT文件分析模块
"""
import csv
import re
from collections import Counter
from datetime import datetime
from pathlib import Path

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
    """加载words_freq.csv词频数据和标签"""
    freq_file = PROJECT_ROOT / "words_freq.csv"
    word_freq = {}
    word_labels = {}

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
                        label = row.get(
                            "label", ""
                        ).strip()  # 获取标签列，如果没有则为空
                        word_freq[word] = freq
                        if label:
                            word_labels[word] = label
                    except (ValueError, KeyError):
                        # 跳过格式错误的行
                        continue
        except Exception as e:
            print(f"警告: 读取 words_freq.csv 时出错: {e}")

    return word_freq, word_labels


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
    global_freq, word_labels = load_word_freq()

    # 加载已标记为"烂熟于心"的单词
    mastered_words = load_mastered_words()

    # 构建结果（按全局词频排序）
    results = []
    for word, count in word_count.items():
        global_frequency = global_freq.get(word, 0)

        # 从CSV中获取标签
        label = word_labels.get(word, "")
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


def get_srt_files():
    """获取inputs目录下所有srt文件列表，按目录分组"""
    inputs_dir = PROJECT_ROOT / "inputs"
    files_by_dir = {}

    if inputs_dir.exists():
        for srt_file in inputs_dir.rglob("*.srt"):
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
