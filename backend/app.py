#!/usr/bin/env python3
"""
英文词频统计程序 - 后端API服务
"""
from flask import Flask, jsonify, request
from flask_cors import CORS
from srt_analyzer import (
    analyze_youtube_subtitle,
    get_youtube_subtitles,
    get_youtube_transcript_lines,
    get_learning_progress,
    get_learning_stats,
    get_unmastered_words,
    mark_word_mastered,
    unmark_word_mastered,
)

app = Flask(__name__)
CORS(app)  # 允许跨域请求


@app.route("/health", methods=["GET"])
def health():
    """健康检查接口"""
    return jsonify({"status": "ok", "message": "Backend is running"})


@app.route("/api/mark-mastered", methods=["POST"])
def mark_mastered():
    """标记单词为"烂熟于心" """
    try:
        data = request.get_json()
        word = data.get("word")

        if not word:
            return (
                jsonify({"status": "error", "message": "缺少word参数"}),
                400,
            )

        if mark_word_mastered(word):
            return jsonify({"status": "success", "message": "标记成功"})
        else:
            return jsonify({"status": "error", "message": "标记失败"}), 500
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/unmark-mastered", methods=["POST"])
def unmark_mastered():
    """取消单词的"烂熟于心"标记"""
    try:
        data = request.get_json()
        word = data.get("word")

        if not word:
            return (
                jsonify({"status": "error", "message": "缺少word参数"}),
                400,
            )

        if unmark_word_mastered(word):
            return jsonify({"status": "success", "message": "取消标记成功"})
        else:
            return jsonify({"status": "error", "message": "取消标记失败"}), 500
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/learning-progress", methods=["GET"])
def learning_progress():
    """获取3000/5000/10000词的学习进度"""
    try:
        progress = get_learning_progress()
        return jsonify({"status": "success", "progress": progress})
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"获取学习进度时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/unmastered-words", methods=["GET"])
def unmastered_words():
    """获取指定词表中未掌握的单词列表"""
    try:
        label = request.args.get("label")
        if not label:
            return (
                jsonify({"status": "error", "message": "缺少label参数"}),
                400,
            )

        words = get_unmastered_words(label)
        return jsonify({"status": "success", "words": words})
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"获取未掌握单词列表时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/youtube-subtitles", methods=["POST"])
def youtube_subtitles():
    """解析YouTube视频字幕并返回英文人工字幕列表"""
    try:
        data = request.get_json() or {}
        youtube_url = (data.get("youtube_url") or "").strip()

        if not youtube_url:
            return (
                jsonify({"status": "error", "message": "缺少youtube_url参数"}),
                400,
            )

        result = get_youtube_subtitles(youtube_url)
        return jsonify({"status": "success", **result})
    except ValueError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except RuntimeError as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"解析YouTube字幕时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/analyze-youtube-subtitle", methods=["POST"])
def analyze_youtube_subtitle_api():
    """分析YouTube视频中的指定英文人工字幕"""
    try:
        data = request.get_json() or {}
        youtube_url = (data.get("youtube_url") or "").strip()
        language_code = (data.get("language_code") or "").strip()

        if not youtube_url:
            return (
                jsonify({"status": "error", "message": "缺少youtube_url参数"}),
                400,
            )
        if not language_code:
            return (
                jsonify({"status": "error", "message": "缺少language_code参数"}),
                400,
            )

        results = analyze_youtube_subtitle(youtube_url, language_code)
        return jsonify(
            {
                "status": "success",
                "results": results,
                "total_words": len(results),
            }
        )
    except ValueError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except FileNotFoundError as e:
        return jsonify({"status": "error", "message": str(e)}), 404
    except RuntimeError as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"分析YouTube字幕时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/youtube-transcript-lines", methods=["POST"])
def youtube_transcript_lines():
    """获取YouTube字幕时间轴（用于播放器逐句播放）"""
    try:
        data = request.get_json() or {}
        youtube_url = (data.get("youtube_url") or "").strip()
        language_code = (data.get("language_code") or "").strip()

        if not youtube_url:
            return (
                jsonify({"status": "error", "message": "缺少youtube_url参数"}),
                400,
            )
        if not language_code:
            return (
                jsonify({"status": "error", "message": "缺少language_code参数"}),
                400,
            )

        result = get_youtube_transcript_lines(youtube_url, language_code)
        return jsonify({"status": "success", **result})
    except ValueError as e:
        return jsonify({"status": "error", "message": str(e)}), 400
    except FileNotFoundError as e:
        return jsonify({"status": "error", "message": str(e)}), 404
    except RuntimeError as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"获取YouTube字幕时间轴时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/api/learning-stats", methods=["GET"])
def learning_stats():
    """获取学习统计数据（按天或按月）"""
    try:
        granularity = request.args.get("granularity", "day")
        if granularity not in ["day", "month"]:
            return (
                jsonify(
                    {
                        "status": "error",
                        "message": "granularity必须是day或month",
                    }
                ),
                400,
            )

        stats = get_learning_stats(granularity)
        return jsonify({"status": "success", "data": stats})
    except Exception as e:
        import traceback

        error_detail = traceback.format_exc()
        print(f"获取学习统计数据时出错: {error_detail}")
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8000)
