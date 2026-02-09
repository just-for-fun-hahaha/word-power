.PHONY: help install-frontend install-backend install dev-frontend dev-backend dev fmt fmt-python fmt-frontend clean

help: ## 显示帮助信息
	@echo "可用的命令："
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install-frontend: ## 安装前端依赖
	@echo "正在安装前端依赖..."
	cd frontend && npm install

install-backend: ## 安装后端依赖（创建虚拟环境并安装）
	@echo "正在设置后端虚拟环境..."
	cd backend && python3 -m venv venv
	cd backend && source venv/bin/activate && pip install -r requirements.txt
	@echo "后端依赖安装完成！"

install: install-frontend install-backend ## 安装所有依赖（前端+后端）

dev-frontend: ## 启动前端开发服务器
	@echo "启动前端开发服务器..."
	cd frontend && npm run dev

dev-backend: ## 启动后端开发服务器
	@echo "启动后端开发服务器..."
	cd backend && source venv/bin/activate && python app.py

dev: ## 同时启动前后端开发服务器（推荐）
	@echo "正在启动前后端开发服务器..."
	@echo "前端: http://localhost:3000"
	@echo "后端: http://localhost:8000"
	@make -j2 dev-frontend dev-backend

fmt-python: ## 格式化Python代码（使用black和isort）
	@echo "正在格式化Python代码..."
	@if [ -f backend/venv/bin/activate ]; then \
		. backend/venv/bin/activate && black --line-length 79 --target-version py38 scripts/ backend/; \
		. backend/venv/bin/activate && isort --profile black scripts/ backend/; \
	else \
		echo "错误: 未找到虚拟环境，请先运行 'make install-backend'"; \
		exit 1; \
	fi
	@echo "Python代码格式化完成！"

fmt-frontend: ## 格式化前端代码（使用prettier，如果已安装）
	@echo "正在格式化前端代码..."
	@if [ -f frontend/node_modules/.bin/prettier ]; then \
		cd frontend && npm run format 2>/dev/null || echo "未配置prettier"; \
	else \
		echo "未安装prettier，跳过前端格式化"; \
	fi

fmt: fmt-python fmt-frontend ## 格式化所有代码（Python + 前端）

clean: ## 清理生成的文件
	@echo "正在清理..."
	rm -rf frontend/node_modules
	rm -rf frontend/dist
	rm -rf backend/venv
	rm -rf backend/__pycache__
	@echo "清理完成！"
