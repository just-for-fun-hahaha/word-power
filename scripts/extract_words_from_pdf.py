#!/usr/bin/env python3
"""
从PDF文件中提取单词并保存为txt文件
支持处理：
- American_Oxford_5000_by_CEFR_level.pdf (从B2开始，到vulnerable结束)
- American_Oxford_3000_by_CEFR_level.pdf (从A1开始，到zone结束)
"""
import re
import sys
from pathlib import Path

try:
    import pdfplumber
except ImportError:
    print("错误: 请先安装 pdfplumber: pip install pdfplumber")
    sys.exit(1)

# PDF配置文件
PDF_CONFIGS = {
    "5000": {
        "filename": "American_Oxford_5000_by_CEFR_level.pdf",
        "start_marker": "B2",
        "end_marker": "vulnerable",
        "output_file": "words_5000.txt",
        "first_word": "absorb",
        "last_word": "vulnerable",
    },
    "3000": {
        "filename": "American_Oxford_3000_by_CEFR_level.pdf",
        "start_marker": "A1",
        "end_marker": "zone",
        "output_file": "words_3000.txt",
        "first_word": "a",
        "last_word": "zone",
    },
}


def extract_text_from_pdf(pdf_path):
    """从PDF文件中提取所有文本"""
    text_content = []

    try:
        with pdfplumber.open(pdf_path) as pdf:
            print(f"正在处理PDF文件: {pdf_path}")
            print(f"总页数: {len(pdf.pages)}")

            for i, page in enumerate(pdf.pages):
                text = page.extract_text()
                if text:
                    text_content.append(text)
                if (i + 1) % 10 == 0:
                    print(f"已处理 {i + 1}/{len(pdf.pages)} 页...")

            print("PDF文本提取完成")
    except Exception as e:
        print(f"提取PDF文本时出错: {e}")
        sys.exit(1)

    return "\n".join(text_content)


def extract_words_from_content(
    text, start_marker, end_marker, first_word=None, last_word=None
):
    """从文本中提取单词，从指定标记之后开始，到指定标记结束"""
    # 找到起始标记的位置
    start_index = text.find(start_marker)
    if start_index == -1:
        print(f"警告: 未找到'{start_marker}'标记，将从文本开头开始提取")
        start_index = 0
    else:
        # 从标记之后开始
        start_index = start_index + len(start_marker)
        print(f"找到'{start_marker}'标记，从位置 {start_index} 开始提取")

    # 截取从起始标记之后的内容
    content = text[start_index:]

    # 找到结束标记的位置（最后一个单词）
    end_marker_index = content.rfind(end_marker)
    if end_marker_index == -1:
        print(f"警告: 未找到'{end_marker}'结束标记")
        end_index = len(content)
    else:
        # 提取到结束标记之后（包含结束标记）
        # 找到结束标记单词的结束位置
        end_marker_end = end_marker_index + len(end_marker)
        # 向后查找可能的空白字符或单词边界
        while end_marker_end < len(content) and (
            content[end_marker_end].isalnum() or content[end_marker_end] == "-"
        ):
            end_marker_end += 1
        end_index = end_marker_end
        print(f"找到结束标记'{end_marker}'，提取到位置 {end_index}")

    # 截取有效内容
    content = content[:end_index]

    # 使用正则表达式匹配英文单词（字母，可能包含连字符）
    # 单词至少1个字符，以字母开头和结尾
    word_pattern = r"\b[a-zA-Z]+(?:-[a-zA-Z]+)*\b"

    words = re.findall(word_pattern, content)

    # 过滤掉纯数字，保留单字母单词（因为3000词的第一个词可能是'a'）
    words = [w.lower() for w in words if not w.isdigit()]

    # 去重
    unique_words = list(set(words))

    # 按字母序排序
    unique_words.sort()

    # 验证第一个和最后一个单词
    if first_word and unique_words and unique_words[0] != first_word:
        print(f"警告: 第一个单词不是'{first_word}'，而是'{unique_words[0]}'")
    if last_word and unique_words and unique_words[-1] != last_word:
        print(f"警告: 最后一个单词不是'{last_word}'，而是'{unique_words[-1]}'")

    return unique_words


def load_existing_words(word_file):
    """加载已存在的单词列表"""
    if not word_file.exists():
        return set()

    words = set()
    try:
        with open(word_file, "r", encoding="utf-8") as f:
            for line in f:
                word = line.strip().lower()
                if word:
                    words.add(word)
    except Exception as e:
        print(f"警告: 读取文件 {word_file} 时出错: {e}")

    return words


def process_pdf(config_key, project_root):
    """处理单个PDF文件"""
    config = PDF_CONFIGS[config_key]
    pdf_path = project_root / config["filename"]
    output_path = project_root / config["output_file"]

    # 检查PDF文件是否存在
    if not pdf_path.exists():
        print(f"警告: 找不到PDF文件: {pdf_path}")
        return False

    print("=" * 60)
    print(f"处理 {config_key}词PDF: {config['filename']}")
    print("=" * 60)

    # 提取PDF文本
    text = extract_text_from_pdf(pdf_path)

    if not text.strip():
        print("警告: PDF中未提取到文本内容")
        return False

    # 提取单词
    print("\n正在提取单词...")
    words = extract_words_from_content(
        text,
        start_marker=config["start_marker"],
        end_marker=config["end_marker"],
        first_word=config["first_word"],
        last_word=config["last_word"],
    )

    print(f"共提取到 {len(words)} 个唯一单词")

    # 如果是5000词，需要排除3000词中已存在的单词
    if config_key == "5000":
        words_3000_file = project_root / "words_3000.txt"
        existing_words = load_existing_words(words_3000_file)

        if existing_words:
            original_count = len(words)
            words = [w for w in words if w.lower() not in existing_words]
            excluded_count = original_count - len(words)
            print(f"已排除 {excluded_count} 个在3000词中已存在的单词")
            print(f"保留 {len(words)} 个新单词（3000-5000词）")
        else:
            print("警告: 未找到 words_3000.txt，将保留所有提取的单词")

    # 保存到txt文件
    try:
        with open(output_path, "w", encoding="utf-8") as f:
            for word in words:
                f.write(word + "\n")

        print(f"\n单词已保存到: {output_path}")
        print(f"文件大小: {output_path.stat().st_size} 字节")
        print(f"共 {len(words)} 个单词（已按字母序排序）")

        # 显示前10个和最后10个单词作为预览
        print("\n前10个单词:")
        for i, word in enumerate(words[:10], 1):
            print(f"  {i:2d}. {word}")
        if len(words) > 20:
            print("\n最后10个单词:")
            for i, word in enumerate(words[-10:], len(words) - 9):
                print(f"  {i:2d}. {word}")
        print()
        return True
    except Exception as e:
        print(f"保存文件时出错: {e}")
        return False


def main():
    # 获取脚本所在目录的父目录（项目根目录）
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    print("=" * 60)
    print("PDF单词提取工具")
    print("=" * 60)
    print()

    # 按顺序处理：先3000词，再5000词（5000词会排除3000词）
    success_count = 0
    for config_key in ["3000", "5000"]:
        if config_key in PDF_CONFIGS:
            if process_pdf(config_key, project_root):
                success_count += 1

    print("=" * 60)
    if success_count > 0:
        print(f"处理完成！成功处理 {success_count} 个PDF文件")
        print("注意: words_5000.txt 已排除 words_3000.txt 中的单词")
    else:
        print("未找到任何可处理的PDF文件")
    print("=" * 60)


if __name__ == "__main__":
    main()
