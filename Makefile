SHELL := /bin/bash
FRONTEND_DIR := frontend

.PHONY: help install dev build test pages-build preview clean clean-all

help: ## 显示可用命令
	@echo "可用命令："
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

install: ## 安装前端依赖
	cd $(FRONTEND_DIR) && npm install

dev: ## 启动前端开发服务
	cd $(FRONTEND_DIR) && npm run dev

build: ## 构建生产包
	cd $(FRONTEND_DIR) && npm run build

test: ## 构建测试（检查是否可打包）
	cd $(FRONTEND_DIR) && npm run build

pages-build: ## GitHub Pages 路径构建：make pages-build REPO=word-power
	@if [ -z "$(REPO)" ]; then \
		echo "请传入 REPO 参数，例如: make pages-build REPO=word-power"; \
		exit 1; \
	fi
	cd $(FRONTEND_DIR) && VITE_BASE="/$(REPO)/" npm run build

preview: ## 预览构建产物（默认4173）
	cd $(FRONTEND_DIR) && npm run preview -- --host --port 4173

clean: ## 清理构建产物
	rm -rf $(FRONTEND_DIR)/dist

clean-all: clean ## 清理构建产物和前端依赖
	rm -rf $(FRONTEND_DIR)/node_modules
