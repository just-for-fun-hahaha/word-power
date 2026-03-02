<template>
  <a-config-provider :locale="locale">
    <div id="app">
      <a-layout class="layout">
        <a-layout-header class="header">
          <h1 @click="goHome" style="cursor: pointer;">I Can See Your Progress</h1>
          <div style="display: flex; align-items: center; gap: 8px; margin-left: auto;">
            <a-button
              type="default"
              @click="goHome"
              v-if="currentPage !== 'home'"
            >
              <template #icon>
                <HomeOutlined />
              </template>
              首页
            </a-button>
            <a-button
              type="primary"
              @click="showStatsPage = true"
              v-if="currentPage === 'srt' && !showStatsPage"
            >
              <template #icon>
                <BarChartOutlined />
              </template>
              统计图表
            </a-button>
            <a-button
              type="default"
              @click="showStatsPage = false"
              v-if="currentPage === 'srt' && showStatsPage"
            >
              <template #icon>
                <ArrowLeftOutlined />
              </template>
              返回
            </a-button>
          </div>
        </a-layout-header>

        <a-layout-content class="main-content">
          <!-- ========== 首页 ========== -->
          <div v-if="currentPage === 'home'" class="home-page">
            <div class="home-title">
              <h2>选择学习材料</h2>
              <p>选择你要分析的字幕类型</p>
            </div>
            <div class="home-buttons">
              <div class="home-card" @click="currentPage = 'srt'">
                <div class="home-card-icon">🎬</div>
                <div class="home-card-title">美剧字幕</div>
                <div class="home-card-desc">分析 SRT 字幕文件词频，筛选高价值词汇</div>
              </div>
              <div class="home-card" @click="currentPage = 'ted'">
                <div class="home-card-icon">🎤</div>
                <div class="home-card-title">TED字幕</div>
                <div class="home-card-desc">导入 TXT 文本，按顺序列出所有单词</div>
              </div>
            </div>
          </div>

          <!-- ========== 美剧字幕页面 ========== -->
          <div v-if="currentPage === 'srt'">
          <!-- 统计页面 -->
          <div v-if="showStatsPage" class="stats-page">
            <div class="stats-header">
              <h2>每日学习情况统计</h2>
              <a-radio-group v-model:value="statsGranularity" @change="loadStatsData" button-style="solid">
                <a-radio-button value="day">按天</a-radio-button>
                <a-radio-button value="month">按月</a-radio-button>
              </a-radio-group>
            </div>
            <div class="stats-charts-container">
              <div class="stats-chart-item">
                <h3>累积掌握词汇数量</h3>
                <div ref="cumulativeChartContainer" style="width: 100%; height: 400px;"></div>
              </div>
              <div class="stats-chart-item">
                <h3>每日新增词汇数量</h3>
                <div ref="newWordsChartContainer" style="width: 100%; height: 400px;"></div>
              </div>
            </div>
          </div>

          <!-- 主页面 -->
          <div v-else class="content-wrapper">
            <!-- 左侧：表格区域 -->
            <div class="table-section">
              <div class="section-header">
                <h2>词频统计结果</h2>
              </div>

              <a-table
                ref="tableRef"
                :columns="columns"
                :data-source="filteredResults"
                :pagination="pagination"
                :scroll="{ x: 'max-content', y: 'calc(100vh - 320px)' }"
                row-key="word"
                :loading="loading"
                :row-class-name="(record) => (record.mastered ? 'mastered-row' : '')"
                @change="handleTableChange"
              >
                <template #headerCell="{ column }">
                  <template v-if="column.key === 'word'">
                    <div style="display: flex; align-items: center; gap: 8px">
                      <a-button
                        type="link"
                        size="default"
                        title="将当前页所有单词标记为烂熟于心"
                        @click="markCurrentPageMastered"
                        style="padding: 0; height: auto; font-size: 16px"
                      >
                        <CheckCircleOutlined style="color: #52c41a; font-size: 18px;" />
                      </a-button>
                      <span>单词</span>
                    </div>
                  </template>
                </template>
                <template #bodyCell="{ column, record, index }">
                  <template v-if="column.key === 'index'">
                    {{ index + 1 }}
                  </template>
                  <template v-if="column.key === 'word'">
                    <div
                      style="display: flex; align-items: center; gap: 8px"
                      :style="record.mastered ? { opacity: 0.5 } : {}"
                    >
                      <a-button
                        v-if="!record.mastered"
                        type="text"
                        size="small"
                        title="标记为烂熟于心"
                        @click="markWordMastered(record.word)"
                        style="padding: 0; min-width: auto; flex-shrink: 0;"
                      >
                        <template #icon>
                          <CheckCircleOutlined style="color: #52c41a" />
                        </template>
                      </a-button>
                      <a-button
                        v-else
                        type="text"
                        size="small"
                        title="取消标记"
                        @click="unmarkWordMastered(record.word)"
                        style="padding: 0; min-width: auto; flex-shrink: 0;"
                      >
                        <template #icon>
                          <CheckCircleFilled style="color: #999" />
                        </template>
                      </a-button>
                      <strong style="font-size: 20px; font-weight: 600;">{{ record.word }}</strong>
                    </div>
                  </template>
                  <template v-if="column.key === 'tags'">
                    <a-tag
                      v-for="tag in record.tags"
                      :key="tag"
                      :color="
                        tag === '常用3000'
                          ? 'green'
                          : tag === '常用5000'
                          ? 'blue'
                          : tag === '常用10000'
                          ? 'orange'
                          : 'default'
                      "
                      style="cursor: pointer;"
                      @click.stop="filterByTag(tag)"
                      :style="
                        selectedTagFilter === tag
                          ? 'border: 2px solid #1890ff; font-weight: 600;'
                          : ''
                      "
                    >
                      {{ tag }}
                    </a-tag>
                    <span v-if="record.tags.length === 0" style="color: #ccc">-</span>
                  </template>
                </template>
              </a-table>
            </div>

            <!-- 右侧：配置区域 -->
            <div class="config-section">
              <div class="section-header">
                <h2>分析与统计</h2>
              </div>

              <div class="config-content">
                <a-alert
                  v-if="error"
                  :message="error"
                  type="error"
                  show-icon
                  closable
                  @close="error = ''"
                  style="margin-bottom: 20px"
                />

                <!-- 上方左右布局：下拉框 + 学习进度 -->
                <div class="config-top-section">
                  <!-- 左侧：下拉框组 -->
                  <div class="config-selects-group">
                    <div class="section-header">
                      <h2>选择材料</h2>
                    </div>
                    <div class="config-item-inline">
                      <label>选择季：</label>
                      <a-select
                        v-model:value="selectedSeason"
                        placeholder="请选择季"
                        style="width: 200px"
                        :disabled="loading"
                        @change="handleSeasonChange"
                      >
                        <a-select-option
                          v-for="dir in srtFiles"
                          :key="dir.season"
                          :value="dir.season"
                        >
                          {{ dir.season }}
                        </a-select-option>
                      </a-select>
                    </div>

                    <div class="config-item-inline">
                      <label>选择集：</label>
                      <a-select
                        v-model:value="selectedFile"
                        placeholder="请选择文件"
                        style="width: 200px"
                        :disabled="loading || !selectedSeason"
                      >
                        <a-select-option
                          v-for="file in currentFiles"
                          :key="file.path"
                          :value="file.path"
                        >
                          {{ file.name }}
                        </a-select-option>
                      </a-select>
                    </div>

                    <a-button
                      type="primary"
                      :loading="loading"
                      :disabled="!selectedFile"
                      @click="analyzeFile"
                      size="large"
                      class="analyze-button"
                    >
                      开始分析
                    </a-button>
                  </div>

                  <!-- 右侧：学习进度 -->
                  <div class="learning-progress-section" v-if="learningProgress">
                    <div class="section-header">
                      <h2>学习进度（全局）</h2>
                    </div>
                    <div class="progress-content">
                      <div
                        class="progress-item"
                        v-for="(progress, label) in learningProgress"
                        :key="label"
                        style="cursor: pointer;"
                        @click="showUnmasteredWords(label, progress)"
                      >
                        <div class="progress-header">
                          <span class="progress-label">常用{{ label }}</span>
                          <span class="progress-percentage"
                            >{{ progress.mastered }} / {{ progress.total }} ({{
                              progress.percentage
                            }}%)</span
                          >
                        </div>
                        <a-progress
                          :percent="progress.percentage"
                          :stroke-color="
                            label === '3000'
                              ? '#52c41a'
                              : label === '5000'
                              ? '#1890ff'
                              : '#fa8c16'
                          "
                          :show-info="false"
                          size="small"
                        />
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 下方：数据概览 -->
                <div class="overview-section" v-if="results.length > 0">
                  <div class="section-header">
                    <h2>统计概览</h2>
                  </div>
                  <div class="overview-content">
                    <div class="overview-item">
                      <div class="overview-label">词数</div>
                      <div class="overview-value">{{ totalWordCount }}</div>
                    </div>
                    <div class="overview-item">
                      <div class="overview-label">词汇量（不重复）</div>
                      <div class="overview-value">{{ uniqueWordCount }}</div>
                    </div>
                    <div class="overview-item">
                      <div class="overview-label">烂熟于心</div>
                      <div class="overview-value mastered-count">
                        {{ masteredCount }}
                      </div>
                    </div>
                    <div class="overview-item" v-if="tagCounts.common3000.total > 0">
                      <div class="overview-label">常用3000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{
                          tagCounts.common3000.unmastered
                        }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tagCounts.common3000.total }}</span
                          >熟<span class="value-mastered">{{ tagCounts.common3000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tagCounts.common5000.total > 0">
                      <div class="overview-label">常用5000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{
                          tagCounts.common5000.unmastered
                        }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tagCounts.common5000.total }}</span
                          >熟<span class="value-mastered">{{ tagCounts.common5000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tagCounts.common10000.total > 0">
                      <div class="overview-label">常用10000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{
                          tagCounts.common10000.unmastered
                        }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tagCounts.common10000.total }}</span
                          >熟<span class="value-mastered">{{ tagCounts.common10000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tagCounts.nonCommon.total > 0">
                      <div class="overview-label">非10000内</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tagCounts.nonCommon.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tagCounts.nonCommon.total }}</span
                          >熟<span class="value-mastered">{{ tagCounts.nonCommon.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 预留其他配置选项的位置 -->
              </div>
            </div>
          </div>
          </div>

          <!-- ========== TED字幕页面 ========== -->
          <div v-if="currentPage === 'ted'" class="content-wrapper">
            <!-- 左侧：表格区域 -->
            <div class="table-section">
              <div class="section-header">
                <h2>单词列表</h2>
              </div>

              <a-table
                :columns="tedColumns"
                :data-source="tedFilteredResults"
                :pagination="tedPagination"
                :scroll="{ x: 'max-content', y: 'calc(100vh - 320px)' }"
                row-key="word"
                :loading="tedLoading"
                :row-class-name="(record) => (record.mastered ? 'mastered-row' : '')"
                @change="handleTedTableChange"
              >
                <template #headerCell="{ column }">
                  <template v-if="column.key === 'word'">
                    <div style="display: flex; align-items: center; gap: 8px">
                      <a-button
                        type="link"
                        size="default"
                        title="将当前页所有单词标记为烂熟于心"
                        @click="markTedCurrentPageMastered"
                        style="padding: 0; height: auto; font-size: 16px"
                      >
                        <CheckCircleOutlined style="color: #52c41a; font-size: 18px;" />
                      </a-button>
                      <span>单词</span>
                    </div>
                  </template>
                </template>
                <template #bodyCell="{ column, record, index }">
                  <template v-if="column.key === 'index'">
                    {{ (tedPagination.current - 1) * tedPagination.pageSize + index + 1 }}
                  </template>
                  <template v-if="column.key === 'word'">
                    <div
                      style="display: flex; align-items: center; gap: 8px"
                      :style="record.mastered ? { opacity: 0.5 } : {}"
                    >
                      <a-button
                        v-if="!record.mastered"
                        type="text"
                        size="small"
                        title="标记为烂熟于心"
                        @click="markWordMastered(record.word, 'ted')"
                        style="padding: 0; min-width: auto; flex-shrink: 0;"
                      >
                        <template #icon>
                          <CheckCircleOutlined style="color: #52c41a" />
                        </template>
                      </a-button>
                      <a-button
                        v-else
                        type="text"
                        size="small"
                        title="取消标记"
                        @click="unmarkWordMastered(record.word, 'ted')"
                        style="padding: 0; min-width: auto; flex-shrink: 0;"
                      >
                        <template #icon>
                          <CheckCircleFilled style="color: #999" />
                        </template>
                      </a-button>
                      <strong style="font-size: 20px; font-weight: 600;">{{ record.word }}</strong>
                    </div>
                  </template>
                  <template v-if="column.key === 'tags'">
                    <a-tag
                      v-for="tag in record.tags"
                      :key="tag"
                      :color="
                        tag === '常用3000'
                          ? 'green'
                          : tag === '常用5000'
                          ? 'blue'
                          : tag === '常用10000'
                          ? 'orange'
                          : 'default'
                      "
                      style="cursor: pointer;"
                      @click.stop="filterTedByTag(tag)"
                      :style="
                        tedSelectedTagFilter === tag
                          ? 'border: 2px solid #1890ff; font-weight: 600;'
                          : ''
                      "
                    >
                      {{ tag }}
                    </a-tag>
                    <span v-if="record.tags.length === 0" style="color: #ccc">-</span>
                  </template>
                </template>
              </a-table>
            </div>

            <!-- 右侧：配置区域 -->
            <div class="config-section">
              <div class="section-header">
                <h2>分析与统计</h2>
              </div>

              <div class="config-content">
                <a-alert
                  v-if="tedError"
                  :message="tedError"
                  type="error"
                  show-icon
                  closable
                  @close="tedError = ''"
                  style="margin-bottom: 20px"
                />

                <div class="config-top-section">
                  <div class="config-selects-group">
                    <div class="section-header">
                      <h2>选择材料</h2>
                    </div>
                    <div class="config-item-inline">
                      <label>来源：</label>
                      <a-radio-group
                        v-model:value="tedSourceType"
                        :disabled="tedLoading || youtubeLoading"
                        button-style="solid"
                      >
                        <a-radio-button value="txt">本地TXT</a-radio-button>
                        <a-radio-button value="youtube">YouTube链接</a-radio-button>
                      </a-radio-group>
                    </div>

                    <div v-if="tedSourceType === 'txt'" class="config-item-inline">
                      <label>选择文件：</label>
                      <a-select
                        v-model:value="selectedTxtFile"
                        placeholder="请选择TXT文件"
                        style="width: 320px"
                        :disabled="tedLoading || youtubeLoading"
                      >
                        <a-select-option
                          v-for="file in txtFiles"
                          :key="file.path"
                          :value="file.path"
                        >
                          {{ file.name }}
                        </a-select-option>
                      </a-select>
                    </div>

                    <template v-else>
                      <div class="config-item-inline">
                        <label>YouTube：</label>
                        <a-input
                          v-model:value="youtubeUrl"
                          placeholder="粘贴YouTube视频链接"
                          style="width: 320px"
                          :disabled="tedLoading || youtubeLoading"
                          allow-clear
                        />
                      </div>

                      <a-button
                        type="default"
                        :loading="youtubeLoading"
                        :disabled="tedLoading || !youtubeUrl.trim()"
                        @click="loadYoutubeSubtitles"
                        style="width: 320px"
                      >
                        解析字幕列表
                      </a-button>

                      <div class="config-item-inline">
                        <label>英文字幕：</label>
                        <a-select
                          v-model:value="selectedYoutubeSubtitle"
                          placeholder="请选择英文人工字幕"
                          style="width: 320px"
                          :disabled="
                            tedLoading ||
                            youtubeLoading ||
                            youtubeSubtitles.length === 0
                          "
                        >
                          <a-select-option
                            v-for="subtitle in youtubeSubtitles"
                            :key="subtitle.language_code"
                            :value="subtitle.language_code"
                          >
                            {{ subtitle.language }} ({{ subtitle.language_code }})
                          </a-select-option>
                        </a-select>
                      </div>

                      <div
                        v-if="youtubeVideoTitle"
                        style="color: #666; font-size: 13px; line-height: 1.5"
                      >
                        视频：{{ youtubeVideoTitle }}
                      </div>
                    </template>

                    <a-button
                      type="primary"
                      :loading="tedLoading"
                      :disabled="!tedCanAnalyze"
                      @click="analyzeTedFile"
                      size="large"
                      class="analyze-button"
                    >
                      开始解析
                    </a-button>
                  </div>

                  <!-- 右侧：学习进度 -->
                  <div class="learning-progress-section" v-if="learningProgress">
                    <div class="section-header">
                      <h2>学习进度（全局）</h2>
                    </div>
                    <div class="progress-content">
                      <div
                        class="progress-item"
                        v-for="(progress, label) in learningProgress"
                        :key="label"
                        style="cursor: pointer;"
                        @click="showUnmasteredWords(label, progress)"
                      >
                        <div class="progress-header">
                          <span class="progress-label">常用{{ label }}</span>
                          <span class="progress-percentage"
                            >{{ progress.mastered }} / {{ progress.total }} ({{
                              progress.percentage
                            }}%)</span
                          >
                        </div>
                        <a-progress
                          :percent="progress.percentage"
                          :stroke-color="
                            label === '3000'
                              ? '#52c41a'
                              : label === '5000'
                              ? '#1890ff'
                              : '#fa8c16'
                          "
                          :show-info="false"
                          size="small"
                        />
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 统计概览 -->
                <div class="overview-section" v-if="tedResults.length > 0">
                  <div class="section-header">
                    <h2>统计概览</h2>
                  </div>
                  <div class="overview-content">
                    <div class="overview-item">
                      <div class="overview-label">词汇量（不重复）</div>
                      <div class="overview-value">{{ tedResults.length }}</div>
                    </div>
                    <div class="overview-item">
                      <div class="overview-label">烂熟于心</div>
                      <div class="overview-value mastered-count">
                        {{ tedResults.filter(item => item.mastered).length }}
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common3000.total > 0">
                      <div class="overview-label">常用3000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common3000.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tedTagCounts.common3000.total }}</span
                          >熟<span class="value-mastered">{{ tedTagCounts.common3000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common5000.total > 0">
                      <div class="overview-label">常用5000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common5000.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tedTagCounts.common5000.total }}</span
                          >熟<span class="value-mastered">{{ tedTagCounts.common5000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common10000.total > 0">
                      <div class="overview-label">常用10000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common10000.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tedTagCounts.common10000.total }}</span
                          >熟<span class="value-mastered">{{ tedTagCounts.common10000.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.nonCommon.total > 0">
                      <div class="overview-label">非10000内</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.nonCommon.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tedTagCounts.nonCommon.total }}</span
                          >熟<span class="value-mastered">{{ tedTagCounts.nonCommon.mastered }}</span>）</span
                        >
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </a-layout-content>
      </a-layout>
    </div>

    <!-- 未学习单词弹框 -->
    <a-modal
      v-model:open="unmasteredWordsModal.visible"
      :title="`常用${unmasteredWordsModal.label} - 未学习单词`"
      width="900px"
      :footer="null"
      :loading="unmasteredWordsModal.loading"
    >
      <div v-if="unmasteredWordsModal.loading" style="text-align: center; padding: 40px">
        <a-spin size="large" />
      </div>
      <div v-else-if="unmasteredWordsModal.words.length === 0" style="text-align: center; padding: 40px; color: #999">
        没有未学习的单词
      </div>
      <div v-else>
        <a-table
          :columns="unmasteredWordsColumns"
          :data-source="unmasteredWordsTableData"
          :pagination="unmasteredWordsPaginationConfig"
          :scroll="{ x: 'max-content' }"
          row-key="rowIndex"
          size="small"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key.startsWith('col')">
              <template v-if="record.words">
                <div style="display: flex; align-items: center; gap: 4px; padding: 4px 8px;">
                  <template v-if="getWordForColumn(record, column.key)">
                    <a-button
                      v-if="
                        !unmasteredWordsModal.masteredWords.has(
                          getWordForColumn(record, column.key)
                        )
                      "
                      type="text"
                      size="small"
                      title="标记为烂熟于心"
                      @click="markWordMastered(getWordForColumn(record, column.key))"
                      style="padding: 0; min-width: auto; height: 20px; flex-shrink: 0;"
                    >
                      <template #icon>
                        <CheckCircleOutlined style="color: #52c41a; font-size: 14px;" />
                      </template>
                    </a-button>
                    <CheckCircleFilled
                      v-else
                      style="color: #999; font-size: 14px; flex-shrink: 0;"
                      title="已标记为烂熟于心"
                    />
                    <span
                      :style="{
                        fontSize: '18px',
                        opacity: unmasteredWordsModal.masteredWords.has(
                          getWordForColumn(record, column.key)
                        )
                          ? 0.5
                          : 1,
                      }"
                    >
                      {{ getWordForColumn(record, column.key) }}
                    </span>
                  </template>
                </div>
              </template>
            </template>
          </template>
        </a-table>
      </div>
    </a-modal>
  </a-config-provider>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick, h } from "vue";
import zhCN from "ant-design-vue/es/locale/zh_CN";
import {
  CheckCircleOutlined,
  CheckCircleFilled,
  CloseOutlined,
  BarChartOutlined,
  ArrowLeftOutlined,
  HomeOutlined,
} from "@ant-design/icons-vue";
import { message, Modal } from "ant-design-vue";

const locale = zhCN;

// 页面导航状态
const currentPage = ref("home"); // 'home' | 'srt' | 'ted'

function goHome() {
  currentPage.value = "home";
  showStatsPage.value = false;
}

// 统计页面相关状态
const showStatsPage = ref(false);
const statsGranularity = ref("day");
const cumulativeChartContainer = ref(null);
const newWordsChartContainer = ref(null);
let cumulativeChartInstance = null;
let newWordsChartInstance = null;

const columns = [
  {
    title: "序号",
    key: "index",
    width: 80,
    align: "left",
  },
  {
    title: "单词",
    dataIndex: "word",
    key: "word",
    width: 200,
    fixed: "left",
    align: "left",
  },
  {
    title: "全剧词频",
    dataIndex: "frequency",
    key: "frequency",
    width: 120,
    align: "left",
    sorter: (a, b) => a.frequency - b.frequency,
  },
  {
    title: "本集词频",
    dataIndex: "count",
    key: "count",
    width: 120,
    align: "left",
    sorter: (a, b) => a.count - b.count,
  },
  {
    title: "标签",
    key: "tags",
    width: 150,
    align: "left",
  },
];

const srtFiles = ref([]);
const selectedSeason = ref("");
const selectedFile = ref("");
const results = ref([]);
const totalWords = ref(0);
const loading = ref(false);
const error = ref("");
const tableRef = ref(null);
const learningProgress = ref(null); // 学习进度数据
const pagination = ref({
  current: 1,
  pageSize: 20,
  showSizeChanger: true,
  pageSizeOptions: ["10", "20", "50", "100"],
  showTotal: (total) => `共 ${total} 条`,
});

// 标签过滤
const selectedTagFilter = ref(null); // null表示不过滤，可以是 "常用3000", "常用5000", "常用10000", "非10000内"

// 过滤后的结果
const filteredResults = computed(() => {
  if (!selectedTagFilter.value) {
    return results.value;
  }
  
  if (selectedTagFilter.value === "非10000内") {
    return results.value.filter((item) => {
      return (
        !item.tags.includes("常用3000") &&
        !item.tags.includes("常用5000") &&
        !item.tags.includes("常用10000")
      );
    });
  }
  
  return results.value.filter((item) =>
    item.tags.includes(selectedTagFilter.value)
  );
});

const currentFiles = computed(() => {
  const season = srtFiles.value.find(
    (dir) => dir.season === selectedSeason.value
  );
  return season ? season.files : [];
});

// 统计数据
const totalWordCount = computed(() => {
  return results.value.reduce((sum, item) => sum + item.count, 0);
});

const uniqueWordCount = computed(() => {
  return results.value.length;
});

const masteredCount = computed(() => {
  return results.value.filter((item) => item.mastered).length;
});

const unmasteredCount = computed(() => {
  return results.value.filter((item) => !item.mastered).length;
});

const tagCounts = computed(() => {
  const counts = {
    common3000: { total: 0, mastered: 0, unmastered: 0 },
    common5000: { total: 0, mastered: 0, unmastered: 0 },
    common10000: { total: 0, mastered: 0, unmastered: 0 },
    nonCommon: { total: 0, mastered: 0, unmastered: 0 },
  };
  results.value.forEach((item) => {
    // 判断是否在常用词表中
    const isInCommonList =
      item.tags.includes("常用3000") ||
      item.tags.includes("常用5000") ||
      item.tags.includes("常用10000");

    if (item.tags.includes("常用3000")) {
      counts.common3000.total++;
      if (item.mastered) {
        counts.common3000.mastered++;
      } else {
        counts.common3000.unmastered++;
      }
    }
    if (item.tags.includes("常用5000")) {
      counts.common5000.total++;
      if (item.mastered) {
        counts.common5000.mastered++;
      } else {
        counts.common5000.unmastered++;
      }
    }
    if (item.tags.includes("常用10000")) {
      counts.common10000.total++;
      if (item.mastered) {
        counts.common10000.mastered++;
      } else {
        counts.common10000.unmastered++;
      }
    }
    // 非10000内的词（不在任何常用词表中）
    if (!isInCommonList) {
      counts.nonCommon.total++;
      if (item.mastered) {
        counts.nonCommon.mastered++;
      } else {
        counts.nonCommon.unmastered++;
      }
    }
  });
  return counts;
});

onMounted(async () => {
  await Promise.all([loadSrtFiles(), loadTxtFiles(), loadLearningProgress()]);
});

// 监听统计页面显示状态，自动加载数据
watch(showStatsPage, async (newVal) => {
  if (newVal) {
    // 等待 DOM 渲染完成
    await nextTick();
    if (cumulativeChartContainer.value && newWordsChartContainer.value) {
      loadStatsData();
    }
  } else {
    // 清理图表实例
    if (cumulativeChartInstance) {
      cumulativeChartInstance.dispose();
      cumulativeChartInstance = null;
    }
    if (newWordsChartInstance) {
      newWordsChartInstance.dispose();
      newWordsChartInstance = null;
    }
  }
});

// 加载统计数据
async function loadStatsData() {
  if (!cumulativeChartContainer.value || !newWordsChartContainer.value) return;

  try {
    const response = await fetch(`/api/learning-stats?granularity=${statsGranularity.value}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    if (data.status === "success") {
      renderCharts(data.data);
    } else {
      message.error("加载统计数据失败: " + data.message);
    }
  } catch (err) {
    message.error("加载统计数据失败: " + err.message);
    console.error("加载统计数据失败:", err);
  }
}

// 渲染图表（需要先安装 echarts）
async function renderCharts(statsData) {
  // 动态导入 echarts
  const echarts = await import("echarts");
  
  if (!cumulativeChartContainer.value || !newWordsChartContainer.value) return;

  // 准备数据
  const dates = statsData.map((item) => item.date);
  const cumulative = statsData.map((item) => item.cumulative);
  const newWords = statsData.map((item) => item.new_words || 0);

  // 计算左侧Y轴最小值：从第一天的数据减去10开始
  let yAxisMin = 0;
  if (cumulative.length > 0 && cumulative[0] > 0) {
    yAxisMin = Math.max(0, cumulative[0] - 10);
  }

  // ===== 第一张图表：累积掌握词汇数量 =====
  // 如果已有图表实例，先销毁
  if (cumulativeChartInstance) {
    cumulativeChartInstance.dispose();
  }
  // 创建图表实例
  cumulativeChartInstance = echarts.init(cumulativeChartContainer.value);
  
  const cumulativeOption = {
    tooltip: {
      trigger: "axis",
      formatter: (params) => {
        const data = params[0];
        return `${data.name}<br/>累积掌握：${data.value} 个单词`;
      },
    },
    xAxis: {
      type: "category",
      data: dates,
      boundaryGap: false,
    },
    yAxis: {
      type: "value",
      name: "累积词汇数量",
      min: yAxisMin,
      axisLabel: {
        formatter: "{value}",
      },
    },
    series: [
      {
        name: "累积掌握词汇",
        type: "line",
        data: cumulative,
        smooth: true,
        areaStyle: {
          color: {
            type: "linear",
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: "rgba(24, 144, 255, 0.3)" },
              { offset: 1, color: "rgba(24, 144, 255, 0.05)" },
            ],
          },
        },
        lineStyle: {
          color: "#1890ff",
          width: 2,
        },
        itemStyle: {
          color: "#1890ff",
        },
      },
    ],
    grid: {
      left: "3%",
      right: "4%",
      bottom: "3%",
      containLabel: true,
    },
  };

  cumulativeChartInstance.setOption(cumulativeOption);

  // ===== 第二张图表：每日新增词汇数量 =====
  // 如果已有图表实例，先销毁
  if (newWordsChartInstance) {
    newWordsChartInstance.dispose();
  }
  // 创建图表实例
  newWordsChartInstance = echarts.init(newWordsChartContainer.value);
  
  const newWordsOption = {
    tooltip: {
      trigger: "axis",
      formatter: (params) => {
        const data = params[0];
        return `${data.name}<br/>每日新增：${data.value} 个单词`;
      },
    },
    xAxis: {
      type: "category",
      data: dates,
      boundaryGap: false,
    },
    yAxis: {
      type: "value",
      name: "每日新增数量",
      min: 0,
      axisLabel: {
        formatter: "{value}",
      },
    },
    series: [
      {
        name: "每日新增",
        type: "line",
        data: newWords,
        smooth: true,
        lineStyle: {
          color: "#52c41a",
          width: 2,
        },
        itemStyle: {
          color: "#52c41a",
        },
      },
    ],
    grid: {
      left: "3%",
      right: "4%",
      bottom: "3%",
      containLabel: true,
    },
  };

  newWordsChartInstance.setOption(newWordsOption);

  // 响应式调整
  const handleResize = () => {
    if (cumulativeChartInstance) {
      cumulativeChartInstance.resize();
    }
    if (newWordsChartInstance) {
      newWordsChartInstance.resize();
    }
  };
  
  window.addEventListener("resize", handleResize);
}

onUnmounted(() => {
  if (cumulativeChartInstance) {
    cumulativeChartInstance.dispose();
    cumulativeChartInstance = null;
  }
  if (newWordsChartInstance) {
    newWordsChartInstance.dispose();
    newWordsChartInstance = null;
  }
});

async function loadLearningProgress() {
  try {
    const response = await fetch("/api/learning-progress");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    if (data.status === "success") {
      learningProgress.value = data.progress;
    } else {
      console.error("加载学习进度失败:", data.message);
    }
  } catch (err) {
    console.error("加载学习进度失败:", err);
  }
}

function handleSeasonChange() {
  selectedFile.value = "";
  results.value = [];
  selectedTagFilter.value = null;
  pagination.value.current = 1;
}

function handleTableChange(pag) {
  pagination.value.current = pag.current;
  pagination.value.pageSize = pag.pageSize;
}

function filterByTag(tag) {
  if (selectedTagFilter.value === tag) {
    // 如果点击的是已选中的标签，则取消过滤
    selectedTagFilter.value = null;
  } else {
    selectedTagFilter.value = tag;
  }
  // 重置到第一页
  pagination.value.current = 1;
}

// 未学习单词弹框相关
const unmasteredWordsModal = ref({
  visible: false,
  label: "",
  words: [],
  loading: false,
  masteredWords: new Set(), // 在弹框中已标记的单词集合
});
const unmasteredWordsPagination = ref({
  current: 1,
  pageSize: 50, // 10行 * 5列 = 50个单词
});

// 未学习单词表格列（5列）
const unmasteredWordsColumns = Array.from({ length: 5 }, (_, i) => ({
  title: "",
  key: `col${i}`,
  width: 160,
  align: "left",
}));

// 计算未学习单词表格数据（5列）
const unmasteredWordsTableData = computed(() => {
  const { words } = unmasteredWordsModal.value;
  if (!words.length) return [];

  const current = unmasteredWordsPagination.value.current;
  const pageSize = unmasteredWordsPagination.value.pageSize;
  const startIndex = (current - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  const pageWords = words.slice(startIndex, endIndex);

  // 将单词数组转换为5列的行数据
  const rows = [];
  const colsPerRow = 5;
  for (let i = 0; i < pageWords.length; i += colsPerRow) {
    const rowWords = pageWords.slice(i, i + colsPerRow);
    rows.push({
      rowIndex: Math.floor(i / colsPerRow),
      words: rowWords,
    });
  }
  return rows;
});

// 未学习单词的分页配置
const unmasteredWordsPaginationConfig = computed(() => {
  const total = unmasteredWordsModal.value.words.length;
  const pageSize = unmasteredWordsPagination.value.pageSize;
  return {
    current: unmasteredWordsPagination.value.current,
    pageSize: pageSize,
    total: total,
    showSizeChanger: false,
    showTotal: (total) => `共 ${total} 个未学习单词`,
    onChange: (page) => {
      unmasteredWordsPagination.value.current = page;
    },
  };
});

// 根据列key获取对应位置的单词
function getWordForColumn(record, columnKey) {
  if (!record.words) return null;
  const colIndex = parseInt(columnKey.replace("col", ""));
  return record.words[colIndex] || null;
}

async function showUnmasteredWords(label, progress) {
  // 如果所有单词都已掌握，不显示弹框
  if (progress.mastered >= progress.total) {
    message.info("所有单词都已掌握！");
    return;
  }

  unmasteredWordsModal.value.label = label;
  unmasteredWordsModal.value.visible = true;
  unmasteredWordsModal.value.loading = true;
  unmasteredWordsModal.value.words = [];
  unmasteredWordsModal.value.masteredWords = new Set(); // 重置已标记单词集合
  unmasteredWordsPagination.value.current = 1;

  try {
    const response = await fetch(`/api/unmastered-words?label=${label}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    if (data.status === "success") {
      unmasteredWordsModal.value.words = data.words;
    } else {
      message.error("加载未学习单词失败: " + data.message);
      unmasteredWordsModal.value.visible = false;
    }
  } catch (err) {
    message.error("加载未学习单词失败: " + err.message);
    unmasteredWordsModal.value.visible = false;
  } finally {
    unmasteredWordsModal.value.loading = false;
  }
}

async function loadSrtFiles() {
  try {
    const response = await fetch("/api/srt-files");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    if (data.status === "success") {
      srtFiles.value = data.files;
    } else {
      error.value = "加载文件列表失败: " + (data.message || "未知错误");
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    error.value = "无法连接到服务器: " + errorMsg;
    console.error("加载SRT文件列表失败:", err);
  }
}

async function analyzeFile() {
  if (!selectedFile.value) {
    return;
  }

  loading.value = true;
  error.value = "";
  results.value = [];

  try {
    const response = await fetch("/api/analyze-srt", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        file_path: selectedFile.value,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();

    if (data.status === "success") {
      results.value = data.results.map((item) => ({
        ...item,
        frequency: item.frequency || 0,
        mastered: item.mastered || false,
        mastered_date: item.mastered_date || "",
      }));
      totalWords.value = data.total_words;
      // 重置过滤和分页
      selectedTagFilter.value = null;
      pagination.value.current = 1;
    } else {
      error.value = "分析失败: " + (data.message || "未知错误");
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    error.value = "请求失败: " + errorMsg;
    console.error("分析文件失败:", err);
  } finally {
    loading.value = false;
  }
}

async function markWordMastered(word, source = 'srt') {
  try {
    const response = await fetch("/api/mark-mastered", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ word }),
    });

    const data = await response.json();

    if (data.status === "success") {
      message.success("已标记为烂熟于心");
      if (source === 'ted') {
        // 更新TED结果
        const item = tedResults.value.find((r) => r.word === word);
        if (item) {
          item.mastered = true;
          item.mastered_date = new Date().toISOString().split("T")[0];
          const unmastered = tedResults.value.filter((r) => !r.mastered);
          const mastered = tedResults.value.filter((r) => r.mastered);
          tedResults.value = [...unmastered, ...mastered];
        }
      } else {
        // 更新SRT结果
        const item = results.value.find((r) => r.word === word);
        if (item) {
          item.mastered = true;
          item.mastered_date = new Date().toISOString().split("T")[0];
          results.value.sort((a, b) => {
            if (a.mastered !== b.mastered) {
              return a.mastered ? 1 : -1;
            }
            return b.frequency - a.frequency;
          });
        }
      }
      // 如果是在未学习单词弹框中标记，将单词添加到已标记集合（保留在原位，置灰显示）
      if (unmasteredWordsModal.value.visible) {
        unmasteredWordsModal.value.masteredWords.add(word);
      }
      // 刷新学习进度
      await loadLearningProgress();
    } else {
      message.error("标记失败: " + data.message);
    }
  } catch (err) {
    message.error("请求失败: " + err.message);
  }
}

async function unmarkWordMastered(word, source = 'srt') {
  try {
    const response = await fetch("/api/unmark-mastered", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ word }),
    });

    const data = await response.json();

    if (data.status === "success") {
      message.success("已取消标记");
      if (source === 'ted') {
        const item = tedResults.value.find((r) => r.word === word);
        if (item) {
          item.mastered = false;
          item.mastered_date = "";
          const unmastered = tedResults.value.filter((r) => !r.mastered);
          const mastered = tedResults.value.filter((r) => r.mastered);
          tedResults.value = [...unmastered, ...mastered];
        }
      } else {
        const item = results.value.find((r) => r.word === word);
        if (item) {
          item.mastered = false;
          item.mastered_date = "";
          results.value.sort((a, b) => {
            if (a.mastered !== b.mastered) {
              return a.mastered ? 1 : -1;
            }
            return b.frequency - a.frequency;
          });
        }
      }
      // 刷新学习进度
      await loadLearningProgress();
    } else {
      message.error("取消标记失败: " + data.message);
    }
  } catch (err) {
    message.error("请求失败: " + err.message);
  }
}

function markCurrentPageMastered() {
  if (!results.value.length) {
    return;
  }

  // 获取当前页的数据
  const currentPage = pagination.value.current || 1;
  const pageSize = pagination.value.pageSize || 20;
  const startIndex = (currentPage - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  
  // 获取当前页的数据（只标记未标记的）
  const initialWords = results.value
    .slice(startIndex, endIndex)
    .filter((item) => !item.mastered);

  if (initialWords.length === 0) {
    message.info("当前页没有未标记的单词");
    return;
  }

  // 创建响应式的单词列表（存储单词的完整对象）
  const wordsToMark = ref([...initialWords]);
  let modalInstance = null;

  // 创建更新内容的函数
  const createContent = () => {
    return h("div", [
      h("p", { style: "margin-bottom: 12px" }, [
        `将要标记 `,
        h("strong", { style: "color: #1890ff" }, wordsToMark.value.length),
        ` 个单词：`,
      ]),
      h(
        "div",
        {
          style:
            "max-height: 300px; overflow-y: auto; border: 1px solid #d9d9d9; border-radius: 4px; padding: 12px; background: #fafafa",
        },
        [
          wordsToMark.value.length === 0
            ? h("p", { style: "color: #999; text-align: center; padding: 20px" }, "已移除所有单词")
            : h(
                "div",
                {
                  style:
                    "display: flex; flex-wrap: wrap; gap: 8px; line-height: 1.8",
                },
                wordsToMark.value.map((item) =>
                  h(
                    "span",
                    {
                      key: item.word,
                      style:
                        "display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px; background: #fff; border: 1px solid #d9d9d9; border-radius: 4px; font-size: 13px",
                    },
                    [
                      item.word,
                      h(
                        "span",
                        {
                          style:
                            "cursor: pointer; color: #999; display: inline-flex; align-items: center; padding: 2px; transition: color 0.2s",
                          onMouseenter: (e) => {
                            e.target.style.color = "#ff4d4f";
                          },
                          onMouseleave: (e) => {
                            e.target.style.color = "#999";
                          },
                          onClick: () => {
                            // 从列表中移除该单词
                            const wordIndex = wordsToMark.value.findIndex((w) => w.word === item.word);
                            if (wordIndex > -1) {
                              wordsToMark.value.splice(wordIndex, 1);
                              // 重新创建 Modal 以更新显示
                              if (modalInstance) {
                                Modal.destroyAll();
                                modalInstance = Modal.confirm({
                                  title: "确认标记为烂熟于心",
                                  width: 500,
                                  content: createContent(),
                                  okText: "确认标记",
                                  cancelText: "取消",
                                  onOk: handleOk,
                                });
                              }
                            }
                          },
                        },
                        [h(CloseOutlined, { style: "font-size: 12px" })]
                      ),
                    ]
                  )
                ),
              ),
        ]
      ),
    ]);
  };

  // 处理确认标记
  const handleOk = async () => {
    // 如果所有单词都被删除了，提示用户
    if (wordsToMark.value.length === 0) {
      message.info("没有要标记的单词");
      return;
    }

    // 批量标记
    let successCount = 0;
    let failCount = 0;

    for (const item of wordsToMark.value) {
      try {
        const response = await fetch("/api/mark-mastered", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ word: item.word }),
        });

        const data = await response.json();

        if (data.status === "success") {
          // 在results中找到对应的项并更新
          const resultItem = results.value.find((r) => r.word === item.word);
          if (resultItem) {
            resultItem.mastered = true;
            resultItem.mastered_date = new Date().toISOString().split("T")[0];
          }
          successCount++;
        } else {
          failCount++;
        }
      } catch (err) {
        failCount++;
      }
    }

    // 重新排序：已标记的排到最后
    results.value.sort((a, b) => {
      if (a.mastered !== b.mastered) {
        return a.mastered ? 1 : -1;
      }
      return b.frequency - a.frequency;
    });

    // 刷新学习进度
    await loadLearningProgress();

    if (successCount > 0) {
      message.success(`成功标记 ${successCount} 个单词为烂熟于心`);
    }
    if (failCount > 0) {
      message.warning(`${failCount} 个单词标记失败`);
    }
  };

  // 显示确认对话框
  modalInstance = Modal.confirm({
    title: "确认标记为烂熟于心",
    width: 500,
    content: createContent(),
    okText: "确认标记",
    cancelText: "取消",
    onOk: handleOk,
  });
}

// ========== TED字幕页面相关 ==========

const tedColumns = [
  {
    title: "序号",
    key: "index",
    width: 80,
    align: "left",
  },
  {
    title: "单词",
    dataIndex: "word",
    key: "word",
    width: 200,
    fixed: "left",
    align: "left",
  },
  {
    title: "标签",
    key: "tags",
    width: 150,
    align: "left",
  },
];

const txtFiles = ref([]);
const tedSourceType = ref("txt");
const selectedTxtFile = ref("");
const youtubeUrl = ref("");
const parsedYoutubeUrl = ref("");
const youtubeVideoTitle = ref("");
const youtubeSubtitles = ref([]);
const selectedYoutubeSubtitle = ref("");
const youtubeLoading = ref(false);
const tedResults = ref([]);
const tedLoading = ref(false);
const tedError = ref("");
const tedSelectedTagFilter = ref(null);
const tedPagination = ref({
  current: 1,
  pageSize: 20,
  showSizeChanger: true,
  pageSizeOptions: ["10", "20", "50", "100"],
  showTotal: (total) => `共 ${total} 条`,
});

const tedCanAnalyze = computed(() => {
  if (tedSourceType.value === "txt") {
    return !!selectedTxtFile.value;
  }
  return (
    !!youtubeUrl.value.trim() &&
    youtubeUrl.value.trim() === parsedYoutubeUrl.value &&
    !!selectedYoutubeSubtitle.value
  );
});

watch(tedSourceType, () => {
  tedError.value = "";
  tedResults.value = [];
  tedSelectedTagFilter.value = null;
  tedPagination.value.current = 1;
});

watch(youtubeUrl, (newUrl) => {
  if (newUrl.trim() === parsedYoutubeUrl.value) {
    return;
  }
  selectedYoutubeSubtitle.value = "";
  youtubeSubtitles.value = [];
  youtubeVideoTitle.value = "";
});

const tedFilteredResults = computed(() => {
  if (!tedSelectedTagFilter.value) {
    return tedResults.value;
  }

  if (tedSelectedTagFilter.value === "非10000内") {
    return tedResults.value.filter((item) => {
      return (
        !item.tags.includes("常用3000") &&
        !item.tags.includes("常用5000") &&
        !item.tags.includes("常用10000")
      );
    });
  }

  return tedResults.value.filter((item) =>
    item.tags.includes(tedSelectedTagFilter.value)
  );
});

const tedTagCounts = computed(() => {
  const counts = {
    common3000: { total: 0, mastered: 0, unmastered: 0 },
    common5000: { total: 0, mastered: 0, unmastered: 0 },
    common10000: { total: 0, mastered: 0, unmastered: 0 },
    nonCommon: { total: 0, mastered: 0, unmastered: 0 },
  };
  tedResults.value.forEach((item) => {
    const isInCommonList =
      item.tags.includes("常用3000") ||
      item.tags.includes("常用5000") ||
      item.tags.includes("常用10000");

    if (item.tags.includes("常用3000")) {
      counts.common3000.total++;
      if (item.mastered) counts.common3000.mastered++;
      else counts.common3000.unmastered++;
    }
    if (item.tags.includes("常用5000")) {
      counts.common5000.total++;
      if (item.mastered) counts.common5000.mastered++;
      else counts.common5000.unmastered++;
    }
    if (item.tags.includes("常用10000")) {
      counts.common10000.total++;
      if (item.mastered) counts.common10000.mastered++;
      else counts.common10000.unmastered++;
    }
    if (!isInCommonList) {
      counts.nonCommon.total++;
      if (item.mastered) counts.nonCommon.mastered++;
      else counts.nonCommon.unmastered++;
    }
  });
  return counts;
});

async function loadTxtFiles() {
  try {
    const response = await fetch("/api/txt-files");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    if (data.status === "success") {
      txtFiles.value = data.files;
    } else {
      tedError.value = "加载文件列表失败: " + (data.message || "未知错误");
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = "无法连接到服务器: " + errorMsg;
    console.error("加载TXT文件列表失败:", err);
  }
}

async function loadYoutubeSubtitles() {
  const url = youtubeUrl.value.trim();
  if (!url) {
    return;
  }

  youtubeLoading.value = true;
  tedError.value = "";
  parsedYoutubeUrl.value = "";
  youtubeSubtitles.value = [];
  selectedYoutubeSubtitle.value = "";
  youtubeVideoTitle.value = "";

  try {
    const response = await fetch("/api/youtube-subtitles", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        youtube_url: url,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();

    if (data.status === "success") {
      youtubeSubtitles.value = data.subtitles || [];
      youtubeVideoTitle.value = data.video_title || "";
      parsedYoutubeUrl.value = url;

      if (youtubeSubtitles.value.length > 0) {
        selectedYoutubeSubtitle.value = youtubeSubtitles.value[0].language_code;
        message.success(
          `找到 ${youtubeSubtitles.value.length} 条英文人工字幕`
        );
      } else {
        tedError.value = "未找到英文字幕（非自动生成）";
      }
    } else {
      tedError.value = "解析字幕失败: " + (data.message || "未知错误");
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = "请求失败: " + errorMsg;
    console.error("解析YouTube字幕列表失败:", err);
  } finally {
    youtubeLoading.value = false;
  }
}

async function analyzeTedFile() {
  if (!tedCanAnalyze.value) return;

  tedLoading.value = true;
  tedError.value = "";
  tedResults.value = [];

  try {
    const endpoint =
      tedSourceType.value === "txt"
        ? "/api/analyze-txt"
        : "/api/analyze-youtube-subtitle";
    const payload =
      tedSourceType.value === "txt"
        ? { file_path: selectedTxtFile.value }
        : {
            youtube_url: youtubeUrl.value.trim(),
            language_code: selectedYoutubeSubtitle.value,
          };

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();

    if (data.status === "success") {
      tedResults.value = data.results.map((item) => ({
        ...item,
        mastered: item.mastered || false,
        mastered_date: item.mastered_date || "",
      }));
      tedSelectedTagFilter.value = null;
      tedPagination.value.current = 1;
    } else {
      tedError.value = "解析失败: " + (data.message || "未知错误");
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = "请求失败: " + errorMsg;
    console.error("解析字幕失败:", err);
  } finally {
    tedLoading.value = false;
  }
}

function handleTedTableChange(pag) {
  tedPagination.value.current = pag.current;
  tedPagination.value.pageSize = pag.pageSize;
}

function filterTedByTag(tag) {
  if (tedSelectedTagFilter.value === tag) {
    tedSelectedTagFilter.value = null;
  } else {
    tedSelectedTagFilter.value = tag;
  }
  tedPagination.value.current = 1;
}

function markTedCurrentPageMastered() {
  if (!tedResults.value.length) return;

  const currentPage = tedPagination.value.current || 1;
  const pageSize = tedPagination.value.pageSize || 20;
  const startIndex = (currentPage - 1) * pageSize;
  const endIndex = startIndex + pageSize;

  const currentPageData = tedFilteredResults.value.slice(startIndex, endIndex);
  const initialWords = currentPageData.filter((item) => !item.mastered);

  if (initialWords.length === 0) {
    message.info("当前页没有未标记的单词");
    return;
  }

  const wordsToMark = ref([...initialWords]);
  let modalInstance = null;

  const createContent = () => {
    return h("div", [
      h("p", { style: "margin-bottom: 12px" }, [
        `将要标记 `,
        h("strong", { style: "color: #1890ff" }, wordsToMark.value.length),
        ` 个单词：`,
      ]),
      h(
        "div",
        {
          style:
            "max-height: 300px; overflow-y: auto; border: 1px solid #d9d9d9; border-radius: 4px; padding: 12px; background: #fafafa",
        },
        [
          wordsToMark.value.length === 0
            ? h("p", { style: "color: #999; text-align: center; padding: 20px" }, "已移除所有单词")
            : h(
                "div",
                {
                  style: "display: flex; flex-wrap: wrap; gap: 8px; line-height: 1.8",
                },
                wordsToMark.value.map((item) =>
                  h(
                    "span",
                    {
                      key: item.word,
                      style:
                        "display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px; background: #fff; border: 1px solid #d9d9d9; border-radius: 4px; font-size: 13px",
                    },
                    [
                      item.word,
                      h(
                        "span",
                        {
                          style:
                            "cursor: pointer; color: #999; display: inline-flex; align-items: center; padding: 2px; transition: color 0.2s",
                          onMouseenter: (e) => { e.target.style.color = "#ff4d4f"; },
                          onMouseleave: (e) => { e.target.style.color = "#999"; },
                          onClick: () => {
                            const wordIndex = wordsToMark.value.findIndex((w) => w.word === item.word);
                            if (wordIndex > -1) {
                              wordsToMark.value.splice(wordIndex, 1);
                              if (modalInstance) {
                                Modal.destroyAll();
                                modalInstance = Modal.confirm({
                                  title: "确认标记为烂熟于心",
                                  width: 500,
                                  content: createContent(),
                                  okText: "确认标记",
                                  cancelText: "取消",
                                  onOk: handleOk,
                                });
                              }
                            }
                          },
                        },
                        [h(CloseOutlined, { style: "font-size: 12px" })]
                      ),
                    ]
                  )
                ),
              ),
        ]
      ),
    ]);
  };

  const handleOk = async () => {
    if (wordsToMark.value.length === 0) {
      message.info("没有要标记的单词");
      return;
    }

    let successCount = 0;
    let failCount = 0;

    for (const item of wordsToMark.value) {
      try {
        const response = await fetch("/api/mark-mastered", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ word: item.word }),
        });
        const data = await response.json();
        if (data.status === "success") {
          const resultItem = tedResults.value.find((r) => r.word === item.word);
          if (resultItem) {
            resultItem.mastered = true;
            resultItem.mastered_date = new Date().toISOString().split("T")[0];
          }
          successCount++;
        } else {
          failCount++;
        }
      } catch (err) {
        failCount++;
      }
    }

    // 重新排序：已标记的排到最后，未标记的保持原始顺序
    const unmastered = tedResults.value.filter((r) => !r.mastered);
    const mastered = tedResults.value.filter((r) => r.mastered);
    tedResults.value = [...unmastered, ...mastered];

    await loadLearningProgress();

    if (successCount > 0) {
      message.success(`成功标记 ${successCount} 个单词为烂熟于心`);
    }
    if (failCount > 0) {
      message.warning(`${failCount} 个单词标记失败`);
    }
  };

  modalInstance = Modal.confirm({
    title: "确认标记为烂熟于心",
    width: 500,
    content: createContent(),
    okText: "确认标记",
    cancelText: "取消",
    onOk: handleOk,
  });
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen,
    Ubuntu, Cantarell, sans-serif;
}

#app {
  min-height: 100vh;
}

.layout {
  min-height: 100vh;
}

.header {
  background: linear-gradient(135deg, #ff6b6b 0%, #ffa500 50%, #ffd700 100%);
  padding: 20px 40px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header h1 {
  color: #fff;
  margin: 0;
  font-size: 28px;
  font-weight: 700;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  letter-spacing: 1px;
}

.main-content {
  background: #f0f2f5;
  padding: 20px;
  min-height: calc(100vh - 64px);
}

.content-wrapper {
  display: flex;
  gap: 20px;
  max-width: 100%;
  height: calc(100vh - 104px);
}

/* 左侧表格区域 */
.table-section {
  flex: 1;
  width: 50%;
  background: #fff;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  min-width: 0; /* 允许flex收缩 */
}

.section-header {
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 2px solid #e6f7ff;
}

.section-header h2 {
  color: #1890ff;
  margin: 0 0 4px 0;
  font-size: 18px;
  font-weight: 600;
}

.section-header p {
  color: #666;
  font-size: 14px;
  margin: 0;
}

.section-header .placeholder {
  color: #999;
  font-style: italic;
}

/* 右侧配置区域 */
.config-section {
  flex: 1;
  width: 50%;
  background: #fff;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  min-width: 280px;
}

.config-content {
  flex: 1;
  overflow-y: auto;
}

.config-item {
  margin-bottom: 20px;
}

.config-item label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #262626;
  font-size: 14px;
}

/* 上方左右布局 */
.config-top-section {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
  align-items: flex-start;
}

/* 下拉框和按钮的布局 */
.config-selects-group {
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
  min-width: 0;
}

.config-item-inline {
  display: flex;
  align-items: center;
  gap: 8px;
}

.config-item-inline label {
  display: inline-block;
  margin: 0;
  font-weight: 500;
  color: #262626;
  font-size: 14px;
  white-space: nowrap;
  min-width: 60px;
}

.analyze-button {
  height: 64px; /* 2个下拉框的高度 (32px * 2) */
  padding: 0 32px;
  font-size: 16px;
  font-weight: 600;
  align-self: flex-start;
  margin-top: 4px;
}

/* 概览信息样式 */
.overview-section {
  margin-bottom: 24px;
  padding-bottom: 20px;
  border-bottom: 1px solid #e8e8e8;
}

.overview-content {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}

.overview-item {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 16px 12px;
  background: #f5f5f5;
  border-radius: 8px;
  text-align: center;
  min-height: 80px;
}

.overview-label {
  color: #666;
  font-size: 13px;
  margin-bottom: 8px;
}

.overview-value {
  font-size: 24px;
  font-weight: 600;
  line-height: 1.2;
}

.overview-value.mastered-count {
  color: #52c41a;
}

.overview-value .value-total {
  color: #1890ff; /* 蓝色：总词数 */
}

.overview-value .value-mastered {
  color: #52c41a; /* 绿色：烂熟于心 */
}

.overview-value .value-unmastered {
  color: #ff4d4f; /* 红色：待学习 */
  font-size: 28px; /* 待学习数字更大更突出 */
}

.overview-value .value-detail {
  color: #666;
  font-size: 18px;
  font-weight: 400;
  margin-left: 4px;
}

/* 学习进度样式 */
.learning-progress-section {
  flex: 1;
  min-width: 0;
}

.progress-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.progress-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.progress-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.progress-label {
  color: #666;
  font-size: 14px;
  font-weight: 500;
}

.progress-percentage {
  color: #1890ff;
  font-size: 14px;
  font-weight: 600;
}

/* Ant Design 主题色覆盖 */
:deep(.ant-btn-primary) {
  background: #1890ff;
  border-color: #1890ff;
}

:deep(.ant-btn-primary:hover) {
  background: #40a9ff;
  border-color: #40a9ff;
}

:deep(.ant-table-thead > tr > th) {
  background: #e6f7ff;
  color: #1890ff;
  font-weight: 600;
}

:deep(.ant-table-tbody > tr:hover > td) {
  background: #e6f7ff;
}

/* 单词列字体放大 */
:deep(.ant-table-tbody > tr > td strong) {
  font-size: 20px !important;
  font-weight: 600 !important;
}

/* 单词列单元格整体样式 */
:deep(.ant-table-tbody > tr > td:first-of-type) {
  font-size: 20px !important;
  overflow: visible !important;
  padding-right: 12px !important;
}

:deep(.ant-table-thead > tr > th:first-of-type) {
  font-size: 16px !important;
}

/* 确保单词列容器不裁剪内容 */
:deep(.ant-table-cell:first-of-type) {
  overflow: visible !important;
}

/* 表格分页器样式 */
:deep(.ant-table-pagination) {
  margin: 8px 0 0 0;
  padding-top: 8px;
  border-top: 1px solid #f0f0f0;
}

:deep(.ant-select-focused .ant-select-selector) {
  border-color: #1890ff;
}

:deep(.ant-select-selector:hover) {
  border-color: #40a9ff;
}

/* 已标记为"烂熟于心"的行样式 */
:deep(.mastered-row) {
  opacity: 0.5;
  background-color: #f5f5f5 !important;
}

:deep(.mastered-row:hover) {
  opacity: 0.7;
  background-color: #e8e8e8 !important;
}

/* 响应式设计 */
@media (max-width: 1024px) {
  .content-wrapper {
    flex-direction: column;
    height: auto;
  }

  .table-section {
    height: 500px;
  }

  .config-section {
    width: 100%;
  }
}

@media (max-width: 768px) {
  .header {
    padding: 15px 20px;
  }

  .header h1 {
    font-size: 20px;
  }

  .main-content {
    padding: 15px;
  }

  .content-wrapper {
    gap: 15px;
  }

  .table-section,
  .config-section {
    padding: 15px;
  }
}

/* 首页样式 */
.home-page {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 150px);
  padding: 40px;
}

.home-title {
  text-align: center;
  margin-bottom: 48px;
}

.home-title h2 {
  font-size: 32px;
  font-weight: 700;
  color: #262626;
  margin: 0 0 8px 0;
}

.home-title p {
  font-size: 16px;
  color: #666;
  margin: 0;
}

.home-buttons {
  display: flex;
  gap: 40px;
  justify-content: center;
  flex-wrap: wrap;
}

.home-card {
  background: #fff;
  border-radius: 16px;
  padding: 48px 40px;
  width: 300px;
  text-align: center;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
  border: 2px solid transparent;
}

.home-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 12px 32px rgba(24, 144, 255, 0.15);
  border-color: #1890ff;
}

.home-card-icon {
  font-size: 64px;
  margin-bottom: 20px;
  line-height: 1;
}

.home-card-title {
  font-size: 24px;
  font-weight: 700;
  color: #262626;
  margin-bottom: 12px;
}

.home-card-desc {
  font-size: 14px;
  color: #888;
  line-height: 1.6;
}

/* 统计页面样式 */
.stats-page {
  background: #fff;
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.stats-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid #e8e8e8;
}

.stats-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: #262626;
}

.stats-charts-container {
  display: flex;
  flex-direction: column;
  gap: 32px;
  width: 100%;
}

.stats-chart-item {
  width: 100%;
}

.stats-chart-item h3 {
  margin: 0 0 16px 0;
  font-size: 16px;
  font-weight: 600;
  color: #262626;
}

@media (max-width: 480px) {
  .header h1 {
    font-size: 18px;
  }

  .section-header h2 {
    font-size: 16px;
  }
}
</style>
