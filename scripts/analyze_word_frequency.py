#!/usr/bin/env python3
"""
分析SRT字幕文件，统计词频（动词转为原型）
"""
import csv
import os
import re
import signal
import sys
import zipfile
from collections import Counter
from pathlib import Path

try:
    import nltk
    from nltk.corpus import wordnet
    from nltk.stem import WordNetLemmatizer
    from nltk.tag import pos_tag
except ImportError:
    print("错误: 请先安装 nltk")
    print("运行: cd backend && source venv/bin/activate && pip install nltk")
    sys.exit(1)

# 获取项目根目录
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent

# 设置NLTK数据路径到项目目录
NLTK_DATA_DIR = PROJECT_ROOT / "nltk_data"
NLTK_DATA_DIR.mkdir(exist_ok=True)

# 将项目目录设置为NLTK数据的唯一路径（或最高优先级）
nltk.data.path.clear()  # 清空默认路径
nltk.data.path.insert(0, str(NLTK_DATA_DIR))

# 初始化词形还原器
lemmatizer = WordNetLemmatizer()


def get_nltk_data_path():
    """获取NLTK数据路径"""
    data_paths = nltk.data.path
    # 返回第一个存在的路径，或者默认路径
    for path in data_paths:
        path_obj = Path(path)
        if path_obj.exists() and any(path_obj.iterdir()):
            return path
    return data_paths[0] if data_paths else "未知"


def is_valid_zip_file(file_path):
    """检查zip文件是否有效"""
    try:
        if not os.path.exists(file_path):
            return False
        with zipfile.ZipFile(file_path, "r") as zip_ref:
            zip_ref.testzip()
        return True
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError):
        return False


class TimeoutError(Exception):
    pass


def timeout_handler(signum, frame):
    raise TimeoutError("下载超时")


def download_with_timeout(package_name, download_dir, timeout=180):
    """带超时的NLTK数据下载"""
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(timeout)
    try:
        nltk.download(package_name, download_dir=download_dir, quiet=True)
    finally:
        signal.alarm(0)


def ensure_nltk_data():
    """确保NLTK所需数据已下载"""
    data_path = get_nltk_data_path()
    print(f"NLTK数据路径: {data_path}")
    print()

    # punkt数据
    punkt_zip = NLTK_DATA_DIR / "tokenizers" / "punkt.zip"
    try:
        nltk.data.find("tokenizers/punkt")
        print("✓ punkt数据已存在")
    except (LookupError, zipfile.BadZipFile, OSError):
        if punkt_zip.exists() and not is_valid_zip_file(str(punkt_zip)):
            punkt_zip.unlink()
        print("正在下载punkt数据...")
        try:
            download_with_timeout("punkt", str(NLTK_DATA_DIR))
            print("✓ punkt数据下载完成")
        except TimeoutError:
            print("✗ punkt数据下载超时（3分钟）")
            raise
        except Exception as e:
            print(f"✗ punkt数据下载失败: {e}")
            raise

    # POS tagger数据（包括英文版本）
    tagger_zip = NLTK_DATA_DIR / "taggers" / "averaged_perceptron_tagger.zip"
    try:
        nltk.data.find("taggers/averaged_perceptron_tagger")
        nltk.data.find("taggers/averaged_perceptron_tagger_eng")
        print("✓ POS tagger数据已存在")
    except (LookupError, zipfile.BadZipFile, OSError):
        if tagger_zip.exists() and not is_valid_zip_file(str(tagger_zip)):
            tagger_zip.unlink()
        print("正在下载POS tagger数据...")
        try:
            download_with_timeout(
                "averaged_perceptron_tagger", str(NLTK_DATA_DIR)
            )
            download_with_timeout(
                "averaged_perceptron_tagger_eng", str(NLTK_DATA_DIR)
            )
            print("✓ POS tagger数据下载完成")
        except TimeoutError:
            print("✗ POS tagger数据下载超时（3分钟）")
            raise
        except Exception as e:
            print(f"✗ POS tagger数据下载失败: {e}")
            raise

    # wordnet数据
    wordnet_zip = NLTK_DATA_DIR / "corpora" / "wordnet.zip"
    try:
        nltk.data.find("corpora/wordnet")
        print("✓ wordnet数据已存在")
    except (LookupError, zipfile.BadZipFile, OSError):
        if wordnet_zip.exists() and not is_valid_zip_file(str(wordnet_zip)):
            wordnet_zip.unlink()
        print("正在下载wordnet数据...")
        try:
            download_with_timeout("wordnet", str(NLTK_DATA_DIR), timeout=600)
            print("✓ wordnet数据下载完成")
        except TimeoutError:
            print("✗ wordnet数据下载超时（10分钟）")
            raise
        except Exception as e:
            print(f"✗ wordnet数据下载失败: {e}")
            raise

    print()


ensure_nltk_data()

# 预加载常用单词列表（可选，用于额外验证）
VALID_WORDS_CACHE = set()


def load_word_lists():
    """加载预定义的单词列表作为额外验证"""
    global VALID_WORDS_CACHE

    if VALID_WORDS_CACHE:
        return

    word_files = [
        PROJECT_ROOT / "words_5000.txt",
        PROJECT_ROOT / "words_3000.txt",
    ]

    for word_file in word_files:
        if word_file.exists():
            try:
                with open(word_file, "r", encoding="utf-8") as f:
                    words = {
                        line.strip().lower() for line in f if line.strip()
                    }
                    VALID_WORDS_CACHE.update(words)
            except Exception:
                pass

    if VALID_WORDS_CACHE:
        print(f"已加载 {len(VALID_WORDS_CACHE)} 个预定义单词")


def load_word_label_dicts():
    """加载词表文件，返回单词到标签的映射字典"""
    label_dicts = {}

    # 按优先级顺序加载（3000 > 5000 > 10000）
    word_lists = [
        (PROJECT_ROOT / "words_3000.txt", "3000"),
        (PROJECT_ROOT / "words_5000.txt", "5000"),
        (PROJECT_ROOT / "words_10000.txt", "10000"),
    ]

    for word_file, label in word_lists:
        if word_file.exists():
            try:
                words = set()
                with open(word_file, "r", encoding="utf-8") as f:
                    for line in f:
                        word = line.strip().lower()
                        if word:
                            words.add(word)
                label_dicts[label] = words
                print(f"已加载 {len(words)} 个{label}词")
            except Exception as e:
                print(f"警告: 读取 {word_file} 时出错: {e}")

    return label_dicts


def get_word_label(word, label_dicts):
    """获取单词的标签（3000、5000、10000），按优先级返回"""
    word_lower = word.lower()

    # 按优先级检查（3000 > 5000 > 10000）
    for label in ["3000", "5000", "10000"]:
        if label in label_dicts and word_lower in label_dicts[label]:
            return label

    return ""  # 不在任何词表中


def is_valid_word(word):
    """
    验证单词是否为有效的英文单词
    排除：拼写错误、人名、无意义的词
    """
    word = word.lower().strip()

    # 过滤单字符（除了'a'和'i'）
    if len(word) == 1 and word not in ["a", "i"]:
        return False

    # 过滤由相同字符重复组成的短词（如 "aa", "aaa", "bb" 等）
    # 这些通常不是有效的英文单词
    if len(word) <= 3 and len(set(word)) == 1:
        return False

    # 检查是否在WordNet词典中（最可靠的方法）
    if wordnet.synsets(word):
        # 但需要进一步检查：如果是太短且只包含重复字符的词，即使WordNet中有也过滤掉
        # 因为WordNet中可能包含一些特殊缩写或错误条目
        if len(word) <= 3 and len(set(word)) == 1:
            return False
        return True

    # 检查是否在预定义的单词列表中
    if VALID_WORDS_CACHE and word in VALID_WORDS_CACHE:
        return True

    # 过滤常见的人名模式（首字母大写通常是人名，但这里都是小写）
    # 一些明显不是单词的模式
    if word.startswith("www.") or word.startswith("http"):
        return False

    return False


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
    """清洗SRT字幕内容，移除时间轴标记和序号"""
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
    """将单词转换为原型（主要是动词）"""
    if not words:
        return []

    tagged_words = pos_tag(words)

    lemmatized_words = []
    for word, pos in tagged_words:
        wordnet_pos = get_wordnet_pos(word, pos)
        lemma = lemmatizer.lemmatize(word, pos=wordnet_pos)
        lemmatized_words.append(lemma)

    return lemmatized_words


def process_srt_file(file_path):
    """处理单个SRT文件，返回单词列表"""
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        print(f"警告: 无法读取文件 {file_path}: {e}")
        return []

    cleaned_content = clean_srt_content(content)
    words = extract_words_from_text(cleaned_content)
    lemmatized_words = lemmatize_words(words)

    return lemmatized_words


def analyze_subtitles(input_dir=None, output_file=None):
    """分析inputs目录下的所有SRT文件，统计词频并保存到CSV"""
    if input_dir is None:
        input_dir = PROJECT_ROOT / "inputs"
    else:
        input_dir = Path(input_dir)

    if output_file is None:
        output_file = PROJECT_ROOT / "words_freq.csv"
    else:
        output_file = Path(output_file)

    if not input_dir.exists():
        print(f"错误: 输入目录不存在: {input_dir}")
        return False

    print(f"正在扫描目录: {input_dir}")

    srt_files = list(input_dir.rglob("*.srt"))

    if not srt_files:
        print(f"警告: 在 {input_dir} 中未找到.srt文件")
        return False

    print(f"找到 {len(srt_files)} 个字幕文件")

    # 加载预定义单词列表
    load_word_lists()

    # 加载词表标签字典
    print("\n正在加载词表标签...")
    label_dicts = load_word_label_dicts()

    all_words = []
    processed_count = 0
    invalid_count = 0
    # 缓存验证结果，避免重复验证同一单词
    validation_cache = {}

    for srt_file in srt_files:
        words = process_srt_file(srt_file)

        # 验证单词
        valid_words = []
        for word in words:
            # 使用缓存避免重复验证
            if word not in validation_cache:
                validation_cache[word] = is_valid_word(word)

            if validation_cache[word]:
                valid_words.append(word)
            else:
                invalid_count += 1

        all_words.extend(valid_words)
        processed_count += 1

        if processed_count % 10 == 0:
            print(f"已处理 {processed_count}/{len(srt_files)} 个文件...")

    print(f"处理完成，共处理 {processed_count} 个文件")
    if invalid_count > 0:
        print(
            f"已过滤 {invalid_count} 个无效单词实例"
            "（拼写错误、人名、无意义词等）"
        )

    print("正在统计词频...")
    word_freq = Counter(all_words)

    sorted_word_freq = sorted(word_freq.items(), key=lambda x: (-x[1], x[0]))

    print(f"正在保存结果到 {output_file}...")
    try:
        with open(output_file, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["word", "frequency", "label"])
            for word, freq in sorted_word_freq:
                label = get_word_label(word, label_dicts)
                writer.writerow([word, freq, label])

        print(f"成功！共统计 {len(sorted_word_freq)} 个唯一单词")
        print(f"结果已保存到: {output_file}")

        # 统计标签分布
        label_counts = {"3000": 0, "5000": 0, "10000": 0, "": 0}
        for word, _ in sorted_word_freq:
            label = get_word_label(word, label_dicts)
            label_counts[label if label else ""] += 1

        print("\n标签分布:")
        print(f"  3000词: {label_counts['3000']} 个")
        print(f"  5000词: {label_counts['5000']} 个")
        print(f"  10000词: {label_counts['10000']} 个")
        print(f"  无标签: {label_counts['']} 个")

        print("\n前10个高频词:")
        for i, (word, freq) in enumerate(sorted_word_freq[:10], 1):
            label = get_word_label(word, label_dicts)
            label_str = f"[{label}]" if label else ""
            print(f"  {i:2d}. {word:20s} {freq:6d} {label_str}")

        return True
    except Exception as e:
        print(f"保存CSV文件时出错: {e}")
        return False


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="分析SRT字幕文件词频")
    parser.add_argument(
        "-i", "--input", default=None, help="输入目录（默认: inputs）"
    )
    parser.add_argument(
        "-o", "--output", default=None, help="输出文件（默认: words_freq.csv）"
    )

    args = parser.parse_args()

    analyze_subtitles(args.input, args.output)
