# 英文词频统计程序设计

## 技术选型

- 开发语言：vue3+python3
- 依赖与虚拟环境：pip3+venv
- 核心依赖：pandas,nltk
- 前端框架：Vue 3 + Vite
- 后端框架：Flask

## 项目结构

```
word-power/
├── frontend/          # 前端项目（Vue3）
│   ├── src/          # 源代码目录
│   ├── package.json  # 前端依赖配置
│   └── vite.config.js # Vite配置文件
├── backend/          # 后端项目（Python/Flask）
│   ├── app.py        # Flask应用入口
│   ├── requirements.txt # Python依赖列表
│   └── venv/         # Python虚拟环境（自动生成）
├── scripts/          # 前置处理脚本目录
│   ├── extract_words_from_pdf.py      # PDF单词提取
│   ├── analyze_word_frequency.py      # SRT字幕词频统计
│   └── generate_word_labels.py        # 生成单词标签CSV
├── Makefile          # 统一启动脚本
└── README.md         # 项目说明文档
```

### 安装依赖

```bash
# 安装所有依赖（前端+后端）
make install

# 或者分别安装
make install-frontend  # 只安装前端依赖
make install-backend   # 只安装后端依赖（创建虚拟环境）
```

### 启动开发服务器

```bash
# 同时启动前后端开发服务器（推荐）
make dev

# 或者分别启动
make dev-frontend  # 前端：http://localhost:3000
make dev-backend   # 后端：http://localhost:8000
```

### 其他命令

```bash
make help          # 查看所有可用命令
make clean         # 清理生成的文件（node_modules, venv等）
```

### 使用脚本

**PDF单词提取：**
```bash
cd backend && source venv/bin/activate
cd ../scripts && python extract_words_from_pdf.py
```
提取PDF中的单词到 `words_5000.txt` 和 `words_3000.txt`

**词频统计：**
```bash
cd backend && source venv/bin/activate
cd ../scripts && python analyze_word_frequency.py
```
分析 `inputs/` 目录下的SRT字幕文件，输出 `words_freq.csv`（词频统计，动词已转为原型）

**过滤Google单词列表：**
```bash
cd backend && source venv/bin/activate
cd ../scripts && python filter_google_words.py
```
过滤 `google-10000-words.txt` 中的真实单词，输出 `words_10000.txt`（使用与词频统计相同的验证逻辑）

**生成单词标签文件：**
```bash
python3 scripts/generate_word_labels.py
```
基于 `words_3000.txt`、`words_5000.txt`、`words_10000.txt` 生成 `word_labels.csv`（统一管理单词标签，提高性能）
- 优先级：3000 > 5000 > 10000（高优先级覆盖低优先级）
- 首次使用前或更新词表文件后需要运行此脚本

**脚本参数：**
```bash
# 词频统计
python analyze_word_frequency.py -i inputs -o words_freq.csv

# 过滤Google单词
python filter_google_words.py -i google-10000-words.txt -o words_10000.txt
```

### 手动启动（不使用Makefile）

**前端：**
```bash
cd frontend
npm install
npm run dev
```

**后端：**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```
