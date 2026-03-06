# Word Power（纯前端版）

一个用于英语学习的本地网页工具：
- 输入 YouTube 链接
- 导入本地字幕（`.srt/.vtt/.json`）
- 进入播放器做句子级跟读与 AB 练习
- 对当前字幕做词汇分析、标记已掌握词、查看学习统计

## 部署方式

只保留一种部署方式：`GitHub Pages`。
- 不再考虑本地 `file://` 或本地静态服务器部署。
- Mac、iPad 都通过同一个 GitHub Pages 地址访问。
- 本地构建后提交 `dist/` 目录，由 GitHub Pages 从 `main/dist` 发布。

## 技术栈

- 前端：Vue 3 + Vite + Ant Design Vue + ECharts
- 字幕下载脚本（可选）：Python + `youtube-transcript-api`

## 项目结构

```text
word-power/
├── requirements.txt            # Python 脚本依赖
├── venv/                       # 可选，本地虚拟环境
├── frontend/
│   ├── public/
│   │   └── word_labels.csv      # 默认词表（启动时自动加载）
│   └── src/App.vue              # 主应用（播放器 + 词汇学习）
├── scripts/
│   └── download_youtube_subtitles.py  # 按链接下载字幕到本地
├── mastered_words.csv           # 历史掌握词示例数据
└── word_labels.csv              # 词表源文件
```

## Make 命令（推荐）

```bash
make help
```

常用命令：
- `make install`：安装前端依赖
- `make dev`：启动本地开发服务器
- `make test`：执行构建测试（检查是否可正常打包）
- `make build`：生成生产构建
- `make pages-build`：构建并同步 GitHub Pages 发布目录（`main/dist`）
- `make preview`：本地预览构建结果（端口 `4173`）
- `make clean`：清理构建产物
- `make clean-all`：清理构建产物和依赖

## GitHub Pages 部署（唯一方案）

### 1) 发布方式

仓库采用 `Deploy from a branch`：
- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/dist`

不再使用 `.github/workflows/deploy-pages.yml` 的 Actions 发布流程。

### 2) 生成发布目录

在仓库根目录执行：

```bash
make pages-build
```

行为：
- 在 `frontend` 执行 `VITE_BASE=./ npm run build`
- 清理旧的 `dist/`
- 将 `frontend/dist/*` 同步到 `dist/`

### 3) 提交并发布

构建完成后提交并推送到 `main`，Pages 会自动从 `main/dist` 发布。

### 4) 访问地址

发布成功后访问：
- `https://<你的GitHub用户名>.github.io/<你的仓库名>/`

这个地址在 Mac 和 iPad 上都可直接访问。

## 使用流程

1. 首次打开页面：
   - 词表会优先自动读取同目录 `word_labels.csv`（失败时再手动上传）
   - 学习数据文件（JSON 或 `mastered_words.csv`）需手动导入
2. 系统会显示当前“词表版本”和“学习数据版本”（使用文件名作为版本标识）。
3. 首页输入 YouTube 链接并选择本地字幕文件（`.srt/.vtt/.json`）。
4. 点击“开始解析”，解析成功后点击“开始学习”。
5. 在播放器页可进行单句播放、顺序播放、AB 播放（自动循环）、词汇分析。

## 学习数据持久化（浏览器）

- 默认存储：`localStorage`
- 上传后版本名固定为：`word_labels.csv`、`mastered_words.csv` / `learning_data.csv`（新上传会覆盖旧数据）
- 可导出：`导出学习数据`（CSV，含掌握词 + 视频历史）、`导出掌握词CSV`（兼容 `mastered_words.csv`）
- 导出文件名会自动附加导出时间戳（`YYYYMMDD-HHmmss`），便于备份识别
- 可导入：`learning_data.csv`、`mastered_words.csv`（`word,date`）

跨设备迁移方式：在旧设备导出，再在新设备导入。

## 词表（word_labels.csv）

- 页面启动时会优先自动读取同目录下的 `word_labels.csv`。
- 自动读取成功后会缓存到浏览器本地，并显示版本为 `word_labels.csv`。
- 如果自动读取失败，仍可在页面中手动上传词表文件。

## YouTube 字幕下载脚本（可选）

如果你没有现成字幕文件，可用 `scripts/download_youtube_subtitles.py` 下载后再导入页面。  
脚本的安装与使用说明已写在脚本头部注释中。
