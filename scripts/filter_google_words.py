#!/usr/bin/env python3
"""
过滤google-10000-words.txt中的真实单词，保存到words_10000.txt
使用与analyze_word_frequency.py相同的验证逻辑
"""
import signal
import sys
import zipfile
from pathlib import Path

try:
    import nltk
    from nltk.corpus import wordnet
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

# 预加载常用单词列表（可选，用于额外验证）
VALID_WORDS_CACHE = set()


def is_valid_zip_file(file_path):
    """检查zip文件是否有效"""
    try:
        if not file_path.exists():
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
    # wordnet数据
    wordnet_zip = NLTK_DATA_DIR / "corpora" / "wordnet.zip"
    try:
        nltk.data.find("corpora/wordnet")
        print("✓ wordnet数据已存在")
    except (LookupError, zipfile.BadZipFile, OSError):
        if wordnet_zip.exists() and not is_valid_zip_file(wordnet_zip):
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


def is_valid_word(word):
    """
    验证单词是否为有效的英文单词
    排除：拼写错误、人名、无意义的词
    与analyze_word_frequency.py中的实现保持一致
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


def load_existing_word_sets(project_root):
    """加载已存在的3000和5000词列表"""
    words_3000_file = project_root / "words_3000.txt"
    words_5000_file = project_root / "words_5000.txt"

    existing_words = set()

    # 加载3000词
    if words_3000_file.exists():
        try:
            with open(words_3000_file, "r", encoding="utf-8") as f:
                for line in f:
                    word = line.strip().lower()
                    if word:
                        existing_words.add(word)
            print(f"已加载 {len(existing_words)} 个3000词")
        except Exception as e:
            print(f"警告: 读取 words_3000.txt 时出错: {e}")

    # 加载5000词
    if words_5000_file.exists():
        try:
            count = 0
            with open(words_5000_file, "r", encoding="utf-8") as f:
                for line in f:
                    word = line.strip().lower()
                    if word:
                        existing_words.add(word)
                        count += 1
            print(f"已加载 {count} 个5000词（3000-5000部分）")
        except Exception as e:
            print(f"警告: 读取 words_5000.txt 时出错: {e}")

    return existing_words


def filter_google_words(input_file=None, output_file=None):
    """过滤google-10000-words.txt中的真实单词，排除3000和5000词中已存在的"""
    if input_file is None:
        input_file = PROJECT_ROOT / "google-10000-words.txt"
    else:
        input_file = Path(input_file)

    if output_file is None:
        output_file = PROJECT_ROOT / "words_10000.txt"
    else:
        output_file = Path(output_file)

    if not input_file.exists():
        print(f"错误: 输入文件不存在: {input_file}")
        return False

    print(f"正在读取文件: {input_file}")

    # 加载预定义单词列表（用于验证）
    load_word_lists()

    # 加载已存在的3000和5000词列表（需要排除）
    print("\n正在加载已存在的词表...")
    existing_words = load_existing_word_sets(PROJECT_ROOT)
    if existing_words:
        print(f"共 {len(existing_words)} 个已存在的单词将被排除")

    valid_words = []
    invalid_count = 0
    excluded_count = 0
    total_count = 0

    try:
        with open(input_file, "r", encoding="utf-8") as f:
            for line in f:
                word = line.strip()
                if not word:
                    continue

                total_count += 1
                word_lower = word.lower()

                # 先检查是否在3000或5000词中已存在
                if word_lower in existing_words:
                    excluded_count += 1
                    continue

                # 然后验证是否为有效单词
                if is_valid_word(word):
                    valid_words.append(word_lower)
                else:
                    invalid_count += 1

                # 每处理1000个单词显示一次进度
                if total_count % 1000 == 0:
                    print(
                        f"已处理 {total_count} 个单词，有效: {len(valid_words)}, "
                        f"已排除: {excluded_count}, 无效: {invalid_count}"
                    )

    except Exception as e:
        print(f"读取文件时出错: {e}")
        return False

    print("\n处理完成:")
    print(f"  总单词数: {total_count}")
    print(f"  有效单词（5000-10000部分）: {len(valid_words)}")
    print(f"  已排除（3000-5000词中已存在）: {excluded_count}")
    print(f"  无效单词: {invalid_count}")

    # 去重并排序
    unique_words = sorted(set(valid_words))

    print(f"  唯一单词: {len(unique_words)}")

    # 保存结果
    print(f"\n正在保存结果到 {output_file}...")
    try:
        with open(output_file, "w", encoding="utf-8") as f:
            for word in unique_words:
                f.write(word + "\n")

        print(f"成功！已保存 {len(unique_words)} 个有效单词到: {output_file}")
        print(
            "注意: words_10000.txt 已排除 words_3000.txt 和 words_5000.txt 中的单词"
        )
        return True
    except Exception as e:
        print(f"保存文件时出错: {e}")
        return False


if __name__ == "__main__":
    import argparse

    # 确保NLTK数据已下载
    ensure_nltk_data()

    parser = argparse.ArgumentParser(
        description="过滤google-10000-words.txt中的真实单词"
    )
    parser.add_argument(
        "-i",
        "--input",
        default=None,
        help="输入文件（默认: google-10000-words.txt）",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="输出文件（默认: words_10000.txt）",
    )

    args = parser.parse_args()

    filter_google_words(args.input, args.output)
