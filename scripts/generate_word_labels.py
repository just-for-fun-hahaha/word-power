#!/usr/bin/env python3
"""
生成单词标签CSV文件
基于 words_3000.txt, words_5000.txt, words_10000.txt 生成 word_labels.csv
优先级：3000 > 5000 > 10000（高优先级覆盖低优先级）
"""
import csv
from pathlib import Path

# 获取项目根目录
PROJECT_ROOT = Path(__file__).parent.parent

# 词表文件路径（按优先级从低到高）
TAG_FILES = [
    ("10000", PROJECT_ROOT / "words_10000.txt"),
    ("5000", PROJECT_ROOT / "words_5000.txt"),
    ("3000", PROJECT_ROOT / "words_3000.txt"),
]

# 输出文件
OUTPUT_FILE = PROJECT_ROOT / "word_labels.csv"


def generate_word_labels():
    """生成单词标签CSV文件"""
    word_labels = {}

    # 按优先级从低到高加载，高优先级会覆盖低优先级
    for label, file_path in TAG_FILES:
        if not file_path.exists():
            print(f"警告: 文件不存在，跳过: {file_path}")
            continue

        count = 0
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                for line in f:
                    word = line.strip().lower()
                    if word:
                        word_labels[word] = label
                        count += 1
            print(f"已加载 {file_path.name}: {count} 个单词（标签: {label}）")
        except Exception as e:
            print(f"错误: 读取 {file_path} 时出错: {e}")
            continue

    if not word_labels:
        print("错误: 没有加载到任何单词标签")
        return False

    # 写入CSV文件
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["word", "label"])
            # 按单词排序
            for word in sorted(word_labels.keys()):
                writer.writerow([word, word_labels[word]])

        print(f"\n成功生成标签文件: {OUTPUT_FILE}")
        print(f"总计: {len(word_labels)} 个单词")
        
        # 统计各标签数量
        label_counts = {}
        for label in word_labels.values():
            label_counts[label] = label_counts.get(label, 0) + 1
        
        print("\n标签统计:")
        for label in ["3000", "5000", "10000"]:
            count = label_counts.get(label, 0)
            print(f"  常用{label}: {count} 个单词")
        
        return True
    except Exception as e:
        print(f"错误: 写入 {OUTPUT_FILE} 时出错: {e}")
        return False


if __name__ == "__main__":
    import sys

    print("=" * 60)
    print("生成单词标签CSV文件")
    print("=" * 60)
    print()

    success = generate_word_labels()

    if success:
        print("\n✓ 完成！")
        sys.exit(0)
    else:
        print("\n✗ 失败！")
        sys.exit(1)
