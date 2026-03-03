<template>
  <a-config-provider :locale="locale">
    <div id="app">
      <a-layout class="layout">
        <a-layout-header class="header">
          <button class="header-home-btn" title="首页" @click="goHome">
            <HomeOutlined />
          </button>
          <div class="header-main">
            <h1 class="header-title" @click="goHome">I Can See Your Progress</h1>
            <div class="header-nav">
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'player' }"
                :disabled="!canOpenPlayerPage"
                @click="goPlayerPage"
              >
                播放器
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'ted' && !showStatsPage }"
                @click="goTedAnalysisPage"
              >
                词汇分析
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'ted' && showStatsPage }"
                @click="goTedStatsPage"
              >
                统计图表
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'settings' }"
                @click="goSettingsPage"
              >
                系统设置
              </button>
            </div>
          </div>
        </a-layout-header>

        <a-layout-content class="main-content">
          <!-- ========== 首页 ========== -->
          <div v-if="currentPage === 'home'" class="home-player-page">
            <div
              class="home-player-entry"
              :class="{ 'no-history': playerHistoryVideos.length === 0 }"
            >
              <div class="home-entry-row">
                <a-input
                  class="home-link-input"
                  v-model:value="homeYoutubeUrl"
                  placeholder="粘贴 YouTube 视频链接"
                  :disabled="homeParseLoading"
                  allow-clear
                  @pressEnter="parseHomeVideo"
                />
                <a-button
                  :disabled="homeParseLoading"
                  @click="triggerHomeSubtitleUpload"
                >
                  上传字幕
                </a-button>
                <span
                  class="home-upload-status"
                  :class="{ ready: !!homeSubtitleFileName }"
                >
                  {{ homeSubtitleFileName || "未上传字幕" }}
                </span>
                <a-button
                  type="primary"
                  :loading="homeParseLoading"
                  :disabled="!homeYoutubeUrl.trim() || !homeSubtitleFile"
                  @click="parseHomeVideo"
                >
                  开始解析
                </a-button>
                <input
                  ref="homeSubtitleInputRef"
                  type="file"
                  style="display: none"
                  :disabled="homeParseLoading"
                  @change="handleHomeSubtitleFileChange"
                />
              </div>
              <a-alert
                v-if="homeError"
                :message="homeError"
                type="error"
                show-icon
                closable
                @close="homeError = ''"
                style="margin-top: 12px"
              />
              <div v-if="homeSubtitleOptions.length > 0" class="home-entry-next">
                <a-select
                  v-model:value="homeSelectedSubtitle"
                  placeholder="选择英文人工字幕"
                  style="width: min(280px, 100%)"
                >
                  <a-select-option
                    v-for="subtitle in homeSubtitleOptions"
                    :key="subtitle.language_code"
                    :value="subtitle.language_code"
                  >
                    {{ subtitle.language }} ({{ subtitle.language_code }})
                  </a-select-option>
                </a-select>
                <a-button
                  type="primary"
                  :disabled="!homeCanStartLearning"
                  @click="startLearningFromHome"
                >
                  开始学习
                </a-button>
                <a-button
                  :disabled="!homeCanStartLearning"
                  @click="goToSubtitleAnalysisFromHome"
                >
                  字幕词汇分析
                </a-button>
              </div>
              <div v-if="homeParsedTitle" class="home-entry-video-title">
                视频：{{ homeParsedTitle }}
              </div>
            </div>

            <div v-if="playerHistoryVideos.length > 0" class="home-history-card">
              <div class="home-history-header">
                <div class="section-header">
                  <h2>已添加视频</h2>
                  <p v-if="homeHistorySelectionMode">
                    已选择 {{ homeSelectedHistoryIds.length }} 个视频
                  </p>
                  <p v-else>点击卡片可直接开始学习</p>
                </div>
                <div class="home-history-toolbar">
                  <a-button size="small" @click="toggleHomeHistorySelectionMode">
                    {{ homeHistorySelectionMode ? "取消选择" : "选择" }}
                  </a-button>
                  <a-button
                    v-if="homeHistorySelectionMode"
                    size="small"
                    danger
                    :disabled="homeSelectedHistoryIds.length === 0"
                    @click="removeSelectedHistoryVideos"
                  >
                    删除选中
                  </a-button>
                </div>
              </div>
              <div class="home-history-grid">
                <div
                  v-for="item in playerHistoryVideos"
                  :key="item.id"
                  class="home-history-card-item"
                  :class="{
                    selected: isHomeHistorySelected(item.id),
                    'selection-mode': homeHistorySelectionMode,
                  }"
                  @click="handleHomeHistoryCardClick(item)"
                >
                  <div
                    v-if="homeHistorySelectionMode"
                    class="home-history-card-check"
                  >
                    {{ isHomeHistorySelected(item.id) ? "已选中" : "点击选择" }}
                  </div>
                  <div
                    class="home-history-thumb"
                    :class="{ placeholder: !getHistoryThumbnailUrl(item) }"
                  >
                    <img
                      v-if="getHistoryThumbnailUrl(item)"
                      :src="getHistoryThumbnailUrl(item)"
                      :alt="getHistoryDisplayTitle(item)"
                      loading="lazy"
                    />
                    <span v-else>无缩略图</span>
                  </div>
                  <div class="home-history-title">
                    {{ getHistoryDisplayTitle(item) }}
                  </div>
                  <div class="home-history-url">{{ item.url }}</div>
                  <div class="home-history-meta">
                    字幕 {{ (item.subtitleLines || []).length }} 句
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- ========== 系统设置 ========== -->
          <div v-if="currentPage === 'settings'" class="settings-page">
            <div class="settings-card">
              <div class="section-header">
                <h2>系统设置</h2>
                <p>管理词表与学习数据（学习数据即掌握词）</p>
              </div>
              <div class="settings-actions">
                <a-button type="primary" @click="triggerImportLearningData">
                  导入学习数据
                </a-button>
                <a-button @click="exportLearningData">
                  导出学习数据
                </a-button>
                <a-button @click="triggerWordLabelsUpload">
                  导入词表
                </a-button>
                <span class="settings-meta">
                  词表词数：{{ wordLabelsCount }}
                </span>
                <span class="settings-meta">
                  词表版本：{{ wordLabelsVersion || "未上传" }}
                </span>
                <span class="settings-meta">
                  学习数据版本：{{ learningDataVersion || "未上传" }}
                </span>
                <input
                  ref="learningDataInputRef"
                  type="file"
                  accept=".csv"
                  style="display: none"
                  @change="handleImportLearningData"
                />
                <input
                  ref="wordLabelsInputRef"
                  type="file"
                  accept=".csv"
                  style="display: none"
                  @change="handleWordLabelsUpload"
                />
              </div>
            </div>
          </div>

          <!-- ========== TED字幕页面 ========== -->
          <div v-if="currentPage === 'ted'">
            <div v-if="showStatsPage" class="stats-page">
              <div class="stats-header">
                <h2>每日学习情况统计</h2>
                <a-radio-group
                  v-model:value="statsGranularity"
                  @change="loadStatsData"
                  button-style="solid"
                >
                  <a-radio-button value="day">按天</a-radio-button>
                  <a-radio-button value="month">按月</a-radio-button>
                </a-radio-group>
              </div>
              <div class="stats-charts-container">
                <div class="stats-chart-item">
                  <h3>累积掌握词汇数量</h3>
                  <div
                    ref="cumulativeChartContainer"
                    style="width: 100%; height: 400px;"
                  ></div>
                </div>
                <div class="stats-chart-item">
                  <h3>每日新增词汇数量</h3>
                  <div
                    ref="newWordsChartContainer"
                    style="width: 100%; height: 400px;"
                  ></div>
                </div>
              </div>
            </div>

            <div v-else class="content-wrapper">
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
                          : tag === '常用10000+'
                          ? 'volcano'
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
                              : label === '10000+'
                              ? '#d46b08'
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
                    <div class="overview-item" v-if="tedTagCounts.common10000Plus.total > 0">
                      <div class="overview-label">常用10000+</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common10000Plus.unmastered }}</span>
                        <span class="value-detail"
                          >（总<span class="value-total">{{ tedTagCounts.common10000Plus.total }}</span
                          >熟<span class="value-mastered">{{ tedTagCounts.common10000Plus.mastered }}</span>）</span
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
          </div>

          <!-- ========== 英语播放器页面 ========== -->
          <div v-if="currentPage === 'player'" class="player-page">
            <a-alert
              v-if="playerError"
              :message="playerError"
              type="error"
              show-icon
              closable
              @close="playerError = ''"
              style="margin-bottom: 16px"
            />

            <div class="player-content">
              <div class="player-video-panel">
                <div class="player-video-wrapper">
                  <div id="english-learning-player"></div>
                </div>
                <div class="player-video-controls">
                  <div class="player-video-main-controls">
                    <a-button
                      class="player-icon-btn"
                      title="上一句"
                      @click="playPrevSubtitle"
                      :disabled="!canJumpSubtitle"
                    >
                      <template #icon>
                        <StepBackwardOutlined />
                      </template>
                    </a-button>
                    <a-button
                      class="player-icon-btn player-icon-btn-play"
                      type="primary"
                      :title="playerIsPlaying ? '暂停' : '播放'"
                      @click="togglePlayerPlayPause"
                      :disabled="!canControlPlayback"
                    >
                      <template #icon>
                        <PauseOutlined v-if="playerIsPlaying" />
                        <CaretRightOutlined v-else />
                      </template>
                    </a-button>
                    <a-button
                      class="player-icon-btn"
                      title="下一句"
                      @click="playNextSubtitle"
                      :disabled="!canJumpSubtitle"
                    >
                      <template #icon>
                        <StepForwardOutlined />
                      </template>
                    </a-button>
                  </div>
                  <div class="player-video-secondary-controls">
                    <a-button
                      class="player-secondary-btn"
                      :type="playerAbSelectionMode ? 'primary' : 'default'"
                      @click="toggleAbSelectionMode"
                    >
                      AB播放
                    </a-button>
                    <a-button
                      class="player-secondary-btn"
                      :disabled="!canCopyAbRangeText"
                      @click="copyAbSubtitleRange"
                    >
                      AB复制
                    </a-button>
                    <a-button
                      class="player-secondary-btn"
                      type="dashed"
                      :loading="tedLoading"
                      :disabled="!canAnalyzeCurrentPlayerSubtitle"
                      @click="analyzeCurrentSubtitleVocabulary"
                    >
                      词汇分析
                    </a-button>
                  </div>
                  <span v-if="playerAbSelectionMode" class="player-ab-hint">
                    请选择两句作为 A / B（再次点击 AB 按钮可退出）
                  </span>
                  <span
                    v-else-if="canPlayAbRange"
                    class="player-ab-hint"
                  >
                    A {{ formatSubtitleTime(playerTranscriptLines[playerAbStartIndex]?.start) }}
                    · B {{ formatSubtitleTime(playerTranscriptLines[playerAbEndIndex]?.start) }}
                  </span>
                </div>
              </div>

              <div class="player-subtitle-panel">
                <div
                  v-if="playerTranscriptLoading"
                  style="height: 100%; display: flex; justify-content: center; align-items: center;"
                >
                  <a-spin size="large" />
                </div>

                <div
                  v-else-if="playerTranscriptLines.length === 0"
                  class="player-subtitle-empty"
                >
                  暂无字幕内容
                </div>

                <div
                  v-else
                  ref="playerSubtitleListRef"
                  class="player-subtitle-list"
                >
                  <div
                    v-for="(line, idx) in playerTranscriptLines"
                    :key="`${line.start}-${idx}`"
                    :data-sub-index="idx"
                    class="player-subtitle-item"
                    :class="{
                      active: idx === activePlayerSubtitleIndex,
                      'in-ab-range': isIndexInAbRange(idx),
                      'ab-select-mode': playerAbSelectionMode,
                    }"
                  >
                    <div
                      v-if="playerAbSelectionMode"
                      class="player-ab-select-cell"
                      @click.stop
                    >
                      <a-checkbox
                        :checked="isAbCandidate(idx)"
                        @change="toggleAbCandidate(idx)"
                      />
                    </div>
                    <div
                      class="player-subtitle-time"
                      role="button"
                      tabindex="0"
                      :title="playerAbSelectionMode ? '选择该句作为 AB 片段' : '播放该句字幕'"
                      @click="handleSubtitleTimeClick(line, idx)"
                      @keydown.enter.prevent="handleSubtitleTimeClick(line, idx)"
                      @keydown.space.prevent="handleSubtitleTimeClick(line, idx)"
                    >
                      {{ formatSubtitleTime(line.start) }}
                    </div>
                    <div
                      class="player-subtitle-text"
                      v-html="renderSubtitleTextWithUnknownWords(line.text)"
                    ></div>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </a-layout-content>
      </a-layout>
    </div>

    <a-modal
      v-model:open="setupDataModalOpen"
      title="初始化词表与学习数据"
      :closable="false"
      :keyboard="false"
      :mask-closable="false"
      :footer="null"
      width="640px"
    >
      <div class="setup-modal-body">
        <p class="setup-modal-desc">
          首次使用或版本缺失时，会优先读取同目录 word_labels.csv；若读取失败，再手动导入词表和学习数据文件。
        </p>

        <div class="setup-modal-item">
          <div class="setup-modal-item-title">1. 导入词表（word_labels.csv）</div>
          <input
            type="file"
            accept=".csv"
            @change="handleSetupWordLabelsFileChange"
          />
          <div class="setup-modal-meta">
            当前词表版本：{{ wordLabelsVersion || "未上传" }}
          </div>
          <div class="setup-modal-meta">
            本次选择文件：{{ setupWordLabelsFileName || "未选择文件" }}
          </div>
        </div>

        <div class="setup-modal-item">
          <div class="setup-modal-item-title">
            2. 导入学习数据（mastered_words.csv）
          </div>
          <input
            type="file"
            accept=".csv"
            @change="handleSetupLearningDataFileChange"
          />
          <div class="setup-modal-meta">
            当前学习数据版本：{{ learningDataVersion || "未上传" }}
          </div>
          <div class="setup-modal-meta">
            本次选择文件：{{ setupLearningDataFileName || "未选择文件" }}
          </div>
        </div>

        <div class="setup-modal-actions">
          <a-button
            type="primary"
            :disabled="!isDataSetupReady"
            @click="closeSetupModal"
          >
            开始使用
          </a-button>
        </div>
      </div>
    </a-modal>

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
          row-key="rowIndex"
          :scroll="{ x: 820, y: 420 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="getWordForColumn(record, column.key)">
              <div style="display: flex; align-items: center; gap: 8px">
                <template
                  v-if="
                    !unmasteredWordsModal.masteredWords.has(
                      getWordForColumn(record, column.key)
                    )
                  "
                >
                  <a-button
                    type="text"
                    size="small"
                    style="padding: 0; min-width: auto;"
                    @click="markWordMastered(getWordForColumn(record, column.key))"
                  >
                    <template #icon>
                      <CheckCircleOutlined style="color: #52c41a; font-size: 14px;" />
                    </template>
                  </a-button>
                </template>
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
              </div>
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
  HomeOutlined,
  StepBackwardOutlined,
  StepForwardOutlined,
  CaretRightOutlined,
  PauseOutlined,
} from "@ant-design/icons-vue";
import { message, Modal } from "ant-design-vue";

const locale = zhCN;

const PLAYER_HISTORY_STORAGE_KEY = "word_power_player_history_v2";
const MASTERED_WORDS_STORAGE_KEY = "word_power_mastered_words_v1";
const WORD_LABELS_STORAGE_KEY = "word_power_word_labels_map_v1";
const WORD_LABELS_VERSION_STORAGE_KEY = "word_power_word_labels_version_v1";
const LEARNING_DATA_VERSION_STORAGE_KEY = "word_power_learning_data_version_v1";
const FIXED_WORD_LABELS_FILE_NAME = "word_labels.csv";
const FIXED_MASTERED_WORDS_FILE_NAME = "mastered_words.csv";
const BASE_WORD_LABELS = ["3000", "5000", "10000"];
const FALLBACK_WORD_LABEL = "10000+";
const FALLBACK_WORD_TOTAL = 20000;
const PLAYER_TIMER_INTERVAL_MS = 80;
const SINGLE_LINE_STOP_BUFFER = 0.04;
const SINGLE_LINE_EARLY_PAUSE_SEC = 0.12;
const SINGLE_LINE_MIN_DURATION_SEC = 0.12;
const SINGLE_LINE_NEXT_GUARD_SEC = 0.01;

// 页面导航状态
const currentPage = ref("home"); // 'home' | 'ted' | 'player' | 'settings'
const showStatsPage = ref(false);
const statsGranularity = ref("day");

function goHome() {
  currentPage.value = "home";
  showStatsPage.value = false;
}

function openTedPage() {
  showStatsPage.value = false;
  currentPage.value = "ted";
}

function goPlayerPage() {
  if (!canOpenPlayerPage.value) {
    message.info("请先添加并解析一个视频");
    return;
  }
  showStatsPage.value = false;
  currentPage.value = "player";
}

function goTedAnalysisPage() {
  openTedPage();
}

function goTedStatsPage() {
  currentPage.value = "ted";
  showStatsPage.value = true;
}

function goSettingsPage() {
  showStatsPage.value = false;
  currentPage.value = "settings";
}

// ===== 图表状态 =====
const cumulativeChartContainer = ref(null);
const newWordsChartContainer = ref(null);
let cumulativeChartInstance = null;
let newWordsChartInstance = null;
let chartResizeHandler = null;

// ===== 学习数据（本地） =====
const learningProgress = ref(null);
const masteredWords = ref({}); // {word: date}
const wordLabelsMap = ref(new Map()); // Map<word, label>
const wordLabelsVersion = ref("");
const learningDataVersion = ref("");
const setupWordLabelsFileName = ref("");
const setupLearningDataFileName = ref("");
const setupDataModalOpen = ref(false);

const wordLabelsCount = computed(() => wordLabelsMap.value.size);
const isDataSetupReady = computed(() => {
  return (
    wordLabelsMap.value.size > 0 &&
    !!wordLabelsVersion.value &&
    !!learningDataVersion.value
  );
});

const labelWordSets = computed(() => {
  const sets = {
    "3000": new Set(),
    "5000": new Set(),
    "10000": new Set(),
  };

  wordLabelsMap.value.forEach((label, word) => {
    if (BASE_WORD_LABELS.includes(label)) {
      sets[label].add(word);
    }
  });

  return sets;
});

const learningDataInputRef = ref(null);
const wordLabelsInputRef = ref(null);

// ===== 首页状态 =====
const homeYoutubeUrl = ref("");
const homeParseLoading = ref(false);
const homeError = ref("");
const homeParsedUrl = ref("");
const homeParsedTitle = ref("");
const homeParsedVideoId = ref("");
const homeSubtitleOptions = ref([]);
const homeSelectedSubtitle = ref("");
const homeSubtitleFile = ref(null);
const homeSubtitleFileName = ref("");
const homeSubtitleInputRef = ref(null);
const homeParsedLines = ref([]);
const homeHistorySelectionMode = ref(false);
const homeSelectedHistoryIds = ref([]);

const homeCanStartLearning = computed(() => {
  return (
    !!homeYoutubeUrl.value.trim() &&
    !!homeParsedVideoId.value &&
    homeYoutubeUrl.value.trim() === homeParsedUrl.value &&
    !!homeSelectedSubtitle.value &&
    homeParsedLines.value.length > 0
  );
});

const canOpenPlayerPage = computed(() => !!playerVideoId.value);

// ===== TED页面状态 =====
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

const youtubeUrl = ref("");
const parsedYoutubeUrl = ref("");
const youtubeVideoTitle = ref("");
const youtubeSubtitles = ref([]);
const selectedYoutubeSubtitle = ref("");
const youtubeLoading = ref(false);
const tedLoading = ref(false);
const tedError = ref("");
const tedResults = ref([]);
const tedSubtitleFile = ref(null);
const tedSubtitleFileName = ref("");
const tedSubtitleLines = ref([]);

const lastTedAnalysisMeta = ref({
  source: "",
  youtube_url: "",
  language_code: "",
  subtitle_hash: "",
});

const tedSelectedTagFilter = ref(null);
const tedPagination = ref({
  current: 1,
  pageSize: 20,
  showSizeChanger: true,
  pageSizeOptions: ["10", "20", "50", "100"],
  showTotal: (total) => `共 ${total} 条`,
});

const tedCanAnalyze = computed(() => {
  return (
    !!youtubeUrl.value.trim() &&
    youtubeUrl.value.trim() === parsedYoutubeUrl.value &&
    !!selectedYoutubeSubtitle.value &&
    tedSubtitleLines.value.length > 0
  );
});

watch(youtubeUrl, (newUrl) => {
  if (newUrl.trim() === parsedYoutubeUrl.value) {
    return;
  }
  selectedYoutubeSubtitle.value = "";
  youtubeSubtitles.value = [];
  youtubeVideoTitle.value = "";
  tedSubtitleLines.value = [];
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
        !item.tags.includes("常用10000") &&
        !item.tags.includes("常用10000+")
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
    common10000Plus: { total: 0, mastered: 0, unmastered: 0 },
    nonCommon: { total: 0, mastered: 0, unmastered: 0 },
  };

  tedResults.value.forEach((item) => {
    const isInCommonList =
      item.tags.includes("常用3000") ||
      item.tags.includes("常用5000") ||
      item.tags.includes("常用10000") ||
      item.tags.includes("常用10000+");

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
    if (item.tags.includes("常用10000+")) {
      counts.common10000Plus.total++;
      if (item.mastered) counts.common10000Plus.mastered++;
      else counts.common10000Plus.unmastered++;
    }
    if (!isInCommonList) {
      counts.nonCommon.total++;
      if (item.mastered) counts.nonCommon.mastered++;
      else counts.nonCommon.unmastered++;
    }
  });

  return counts;
});

// ===== 未学习单词弹框 =====
const unmasteredWordsModal = ref({
  visible: false,
  label: "",
  words: [],
  loading: false,
  masteredWords: new Set(),
});
const unmasteredWordsPagination = ref({
  current: 1,
  pageSize: 50,
});

const unmasteredWordsColumns = Array.from({ length: 5 }, (_, i) => ({
  title: "",
  key: `col${i}`,
  width: 160,
  align: "left",
}));

const unmasteredWordsTableData = computed(() => {
  const { words } = unmasteredWordsModal.value;
  if (!words.length) return [];

  const current = unmasteredWordsPagination.value.current;
  const pageSize = unmasteredWordsPagination.value.pageSize;
  const startIndex = (current - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  const pageWords = words.slice(startIndex, endIndex);

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

const unmasteredWordsPaginationConfig = computed(() => {
  const total = unmasteredWordsModal.value.words.length;
  const pageSize = unmasteredWordsPagination.value.pageSize;
  return {
    current: unmasteredWordsPagination.value.current,
    pageSize,
    total,
    showSizeChanger: false,
    showTotal: (value) => `共 ${value} 个未学习单词`,
    onChange: (page) => {
      unmasteredWordsPagination.value.current = page;
    },
  };
});

function getWordForColumn(record, columnKey) {
  if (!record.words) return null;
  const colIndex = parseInt(columnKey.replace("col", ""), 10);
  return record.words[colIndex] || null;
}

// ===== 播放器状态 =====
let youtubeIframeApiPromise = null;
let englishPlayerInstance = null;
let englishPlayerTimer = null;
let playerMountPromise = null;

const playerYoutubeUrl = ref("");
const playerParsedYoutubeUrl = ref("");
const playerVideoId = ref("");
const playerVideoTitle = ref("");
const playerSubtitleOptions = ref([]);
const playerSelectedSubtitle = ref("");
const playerSubtitleFileName = ref("");
const playerLocalSubtitleLines = ref([]);

const playerHistoryVideos = ref([]);
const playerMetaLoading = ref(false);
const playerTranscriptLoading = ref(false);
const playerError = ref("");
const playerInitError = ref("");
const playerIframeReady = ref(false);
const playerTranscriptLines = ref([]);
const playerCurrentTime = ref(0);
const playerSubtitleListRef = ref(null);
const playerAbStartIndex = ref(-1);
const playerAbEndIndex = ref(-1);
const playerAbSelectionMode = ref(false);
const playerAbSelectionCandidates = ref([]);
const playerIsPlaying = ref(false);
const playerPlaybackTarget = ref(null);
const playerPinnedSubtitleIndex = ref(-1);

const playerCanLoadTranscript = computed(() => {
  return (
    !!playerVideoId.value &&
    !!playerSelectedSubtitle.value &&
    playerYoutubeUrl.value.trim() === playerParsedYoutubeUrl.value
  );
});

const canPlayAbRange = computed(() => {
  return (
    playerAbStartIndex.value >= 0 &&
    playerAbEndIndex.value >= 0 &&
    playerAbStartIndex.value < playerTranscriptLines.value.length &&
    playerAbEndIndex.value < playerTranscriptLines.value.length
  );
});

const canCopyAbRangeText = computed(() => {
  return canPlayAbRange.value && playerTranscriptLines.value.length > 0;
});

const canControlPlayback = computed(() => {
  return playerTranscriptLines.value.length > 0;
});

const canJumpSubtitle = computed(() => {
  return playerTranscriptLines.value.length > 0;
});

const canAnalyzeCurrentPlayerSubtitle = computed(() => {
  return !!playerParsedYoutubeUrl.value && playerTranscriptLines.value.length > 0;
});

const playerTranscriptHash = computed(() => {
  return computeTranscriptHash(playerTranscriptLines.value);
});

const playerUnknownWordsFromTedAnalysis = computed(() => {
  if (
    lastTedAnalysisMeta.value.source !== "youtube" ||
    lastTedAnalysisMeta.value.youtube_url !== playerParsedYoutubeUrl.value ||
    lastTedAnalysisMeta.value.subtitle_hash !== playerTranscriptHash.value
  ) {
    return new Set();
  }

  return new Set(
    tedResults.value
      .filter((item) => !item.mastered)
      .map((item) => (item.word || "").toLowerCase())
      .filter((word) => !!word)
  );
});

const playerTranscriptWordSet = computed(() => {
  const set = new Set();
  playerTranscriptLines.value.forEach((line) => {
    extractWordsFromText(line.text || "").forEach((word) => set.add(word));
  });
  return set;
});

const activePlayerSubtitleIndex = computed(() => {
  const lines = playerTranscriptLines.value;
  const pinnedIndex = playerPinnedSubtitleIndex.value;
  if (pinnedIndex >= 0 && pinnedIndex < lines.length) {
    return pinnedIndex;
  }

  const time = playerCurrentTime.value;
  if (!lines.length || time < 0) {
    return -1;
  }

  let left = 0;
  let right = lines.length - 1;
  let found = -1;

  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    if (lines[mid].start <= time) {
      found = mid;
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }

  if (found === -1) {
    return -1;
  }

  if (time <= lines[found].end) {
    return found;
  }

  const nextIndex = found + 1;
  if (
    nextIndex < lines.length &&
    time >= lines[nextIndex].start &&
    time <= lines[nextIndex].end
  ) {
    return nextIndex;
  }

  return found;
});

watch(playerYoutubeUrl, (newUrl) => {
  if (newUrl.trim() === playerParsedYoutubeUrl.value) {
    return;
  }

  playerVideoId.value = "";
  playerVideoTitle.value = "";
  playerSubtitleOptions.value = [];
  playerSelectedSubtitle.value = "";
  playerSubtitleFileName.value = "";
  playerLocalSubtitleLines.value = [];
  playerTranscriptLines.value = [];
  playerCurrentTime.value = 0;
  clearPinnedSubtitleIndex();
  clearAbSelection();
  playerPlaybackTarget.value = null;
  destroyEnglishPlayer();
});

watch(homeYoutubeUrl, (newUrl) => {
  if (newUrl.trim() === homeParsedUrl.value) {
    return;
  }
  homeParsedUrl.value = "";
  homeParsedTitle.value = "";
  homeParsedVideoId.value = "";
  homeSubtitleOptions.value = [];
  homeSelectedSubtitle.value = "";
  homeParsedLines.value = [];
});

watch(playerAbSelectionMode, () => {
  playerPlaybackTarget.value = null;
  playerAbSelectionCandidates.value = [];
});

watch(currentPage, async (newPage, oldPage) => {
  if (oldPage === "player" && newPage !== "player") {
    destroyEnglishPlayer();
  }

  if (
    newPage === "player" &&
    playerVideoId.value &&
    playerTranscriptLines.value.length > 0
  ) {
    try {
      await mountEnglishPlayer(playerVideoId.value);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      playerError.value = `播放器初始化失败: ${errorMsg}`;
    }
  }
});

watch(activePlayerSubtitleIndex, (index, prev) => {
  if (index < 0 || index === prev || !playerSubtitleListRef.value) {
    return;
  }

  const activeNode = playerSubtitleListRef.value.querySelector(
    `[data-sub-index="${index}"]`
  );
  if (activeNode) {
    activeNode.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }
});

onMounted(async () => {
  loadMasteredWordsFromStorage();
  loadPlayerHistory();
  loadWordLabelsFromStorage();
  loadDataVersionsFromStorage();
  await tryLoadWordLabelsFromLocalIfNeeded();
  ensureSetupModalState();
  await loadLearningProgress();
  window.addEventListener("keydown", handlePlayerKeyboardShortcuts);
});

watch(isDataSetupReady, (ready) => {
  setupDataModalOpen.value = !ready;
});

onUnmounted(() => {
  if (cumulativeChartInstance) {
    cumulativeChartInstance.dispose();
    cumulativeChartInstance = null;
  }
  if (newWordsChartInstance) {
    newWordsChartInstance.dispose();
    newWordsChartInstance = null;
  }
  if (chartResizeHandler) {
    window.removeEventListener("resize", chartResizeHandler);
    chartResizeHandler = null;
  }
  destroyEnglishPlayer();
  window.removeEventListener("keydown", handlePlayerKeyboardShortcuts);
});

watch(showStatsPage, async (newVal) => {
  if (newVal) {
    await nextTick();
    if (cumulativeChartContainer.value && newWordsChartContainer.value) {
      await loadStatsData();
    }
  } else {
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

// ===== 工具函数 =====
function normalizeYoutubeUrl(value) {
  return String(value || "").trim();
}

function extractYoutubeVideoId(youtubeUrl) {
  const value = normalizeYoutubeUrl(youtubeUrl);
  if (!value) {
    throw new Error("缺少YouTube链接");
  }

  const idPattern = /^[A-Za-z0-9_-]{11}$/;
  if (idPattern.test(value)) {
    return value;
  }

  let parsed;
  try {
    parsed = new URL(value.startsWith("http") ? value : `https://${value}`);
  } catch {
    throw new Error("无效的YouTube链接");
  }

  const host = parsed.hostname.toLowerCase();
  const path = parsed.pathname.replace(/^\/+/, "");
  let videoId = "";

  if (host === "youtu.be" || host === "www.youtu.be") {
    videoId = path.split("/")[0] || "";
  } else if (host.includes("youtube.com") || host.includes("youtube-nocookie.com")) {
    if (path === "watch") {
      videoId = parsed.searchParams.get("v") || "";
    } else if (path.startsWith("embed/")) {
      videoId = path.split("/")[1] || "";
    } else if (path.startsWith("shorts/") || path.startsWith("live/")) {
      videoId = path.split("/")[1] || "";
    }
  }

  if (!idPattern.test(videoId)) {
    throw new Error("无效的YouTube视频链接");
  }

  return videoId;
}

const GENERIC_YOUTUBE_TITLE_PATTERN = /^YouTube 视频 \([A-Za-z0-9_-]{11}\)$/;

function extractYoutubeVideoIdSafe(youtubeUrl) {
  try {
    return extractYoutubeVideoId(youtubeUrl);
  } catch {
    return "";
  }
}

function isGenericYoutubeTitle(title) {
  const normalized = String(title || "").trim();
  return !normalized || GENERIC_YOUTUBE_TITLE_PATTERN.test(normalized);
}

function getYoutubeThumbnailUrl(videoId) {
  const normalizedId = String(videoId || "").trim();
  if (!normalizedId) return "";
  return `https://i.ytimg.com/vi/${normalizedId}/hqdefault.jpg`;
}

async function fetchYoutubeVideoTitle(youtubeUrl) {
  const normalizedUrl = normalizeYoutubeUrl(youtubeUrl);
  if (!normalizedUrl) return "";

  const endpoint =
    `https://www.youtube.com/oembed?url=${encodeURIComponent(normalizedUrl)}&format=json`;
  const response = await fetch(endpoint, { method: "GET" });
  if (!response.ok) {
    throw new Error("拉取视频标题失败");
  }

  const data = await response.json();
  return normalizeSubtitleText(String(data?.title || ""));
}

function getHistoryVideoId(item) {
  const directId = String(item?.videoId || "").trim();
  if (directId) return directId;
  return extractYoutubeVideoIdSafe(item?.url || "");
}

function getHistoryThumbnailUrl(item) {
  return getYoutubeThumbnailUrl(getHistoryVideoId(item));
}

function getHistoryDisplayTitle(item) {
  const rawTitle = String(item?.title || "").trim();
  if (rawTitle && !isGenericYoutubeTitle(rawTitle)) {
    return rawTitle;
  }

  const videoId = getHistoryVideoId(item);
  if (videoId) {
    return `YouTube 视频 ${videoId}`;
  }

  return rawTitle || String(item?.url || "").trim() || "YouTube 视频";
}

function stripHtmlTags(value) {
  return String(value || "").replace(/<[^>]*>/g, "");
}

function decodeHtmlEntities(value) {
  const textarea = document.createElement("textarea");
  textarea.innerHTML = value;
  return textarea.value;
}

function normalizeSubtitleText(value) {
  return decodeHtmlEntities(stripHtmlTags(value || "")).replace(/\s+/g, " ").trim();
}

function parseTimestampToSeconds(raw) {
  const value = String(raw || "").trim().replace(",", ".");
  if (!value) {
    return NaN;
  }

  const parts = value.split(":");
  if (parts.length < 2 || parts.length > 3) {
    return NaN;
  }

  const secPart = Number(parts[parts.length - 1]);
  const minPart = Number(parts[parts.length - 2]);
  const hourPart = parts.length === 3 ? Number(parts[0]) : 0;

  if ([secPart, minPart, hourPart].some((n) => Number.isNaN(n))) {
    return NaN;
  }

  return hourPart * 3600 + minPart * 60 + secPart;
}

function normalizeSubtitleLines(lines) {
  const normalized = lines
    .map((line, index) => {
      const start = Number(line.start || 0);
      const end = Number(line.end || 0);
      const duration = Number(line.duration || Math.max(0, end - start));
      const text = normalizeSubtitleText(line.text || "");

      if (!text || Number.isNaN(start)) {
        return null;
      }

      const safeEnd =
        !Number.isNaN(end) && end > start
          ? end
          : start + (duration > 0 ? duration : 2);

      return {
        index,
        start: Number(start.toFixed(3)),
        end: Number(safeEnd.toFixed(3)),
        duration: Number(Math.max(0.1, safeEnd - start).toFixed(3)),
        text,
      };
    })
    .filter(Boolean)
    .sort((a, b) => a.start - b.start);

  return normalized;
}

function parseSrtContent(content) {
  const blocks = content.replace(/\r/g, "").split(/\n\s*\n/);
  const lines = [];

  for (const block of blocks) {
    const rawLines = block
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);

    if (!rawLines.length) continue;

    let timeLineIndex = rawLines.findIndex((line) => line.includes("-->"));
    if (timeLineIndex === -1) continue;

    const timeLine = rawLines[timeLineIndex];
    const match = timeLine.match(
      /(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})/
    );
    if (!match) continue;

    const start = parseTimestampToSeconds(match[1]);
    const end = parseTimestampToSeconds(match[2]);
    if (Number.isNaN(start) || Number.isNaN(end)) continue;

    const text = rawLines.slice(timeLineIndex + 1).join(" ");
    lines.push({ start, end, text });
  }

  return normalizeSubtitleLines(lines);
}

function parseVttContent(content) {
  const cleaned = content
    .replace(/^\uFEFF?WEBVTT[^\n]*\n+/i, "")
    .replace(/\r/g, "");
  const blocks = cleaned.split(/\n\s*\n/);
  const lines = [];

  for (const block of blocks) {
    const rawLines = block
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    if (!rawLines.length) continue;

    let timeLineIndex = rawLines.findIndex((line) => line.includes("-->"));
    if (timeLineIndex === -1) continue;

    const timeLine = rawLines[timeLineIndex].split(" ");
    const start = parseTimestampToSeconds(timeLine[0]);
    const end = parseTimestampToSeconds(timeLine[2]);

    if (Number.isNaN(start) || Number.isNaN(end)) continue;

    const text = rawLines.slice(timeLineIndex + 1).join(" ");
    lines.push({ start, end, text });
  }

  return normalizeSubtitleLines(lines);
}

function parseJsonSubtitleContent(content) {
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error("JSON字幕文件格式错误");
  }

  const rawLines = Array.isArray(parsed) ? parsed : parsed?.lines;
  if (!Array.isArray(rawLines)) {
    throw new Error("JSON字幕文件缺少 lines 数组");
  }

  return normalizeSubtitleLines(rawLines);
}

async function readFileAsText(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("读取文件失败"));
    reader.readAsText(file, "utf-8");
  });
}

async function parseSubtitleFile(file) {
  if (!file) {
    throw new Error("请先选择字幕文件");
  }

  const text = await readFileAsText(file);
  const lowerName = (file.name || "").toLowerCase();
  let lines = [];

  if (lowerName.endsWith(".srt")) {
    lines = parseSrtContent(text);
  } else if (lowerName.endsWith(".vtt")) {
    lines = parseVttContent(text);
  } else if (lowerName.endsWith(".json")) {
    lines = parseJsonSubtitleContent(text);
  } else {
    // 默认优先按SRT解析，失败再尝试VTT
    lines = parseSrtContent(text);
    if (!lines.length && /WEBVTT/i.test(text)) {
      lines = parseVttContent(text);
    }
  }

  if (!lines.length) {
    throw new Error("未解析到有效字幕，请检查文件格式（SRT/VTT/JSON）");
  }

  return lines;
}

function computeTranscriptHash(lines) {
  const base = lines
    .map((line) => `${line.start}-${line.end}-${line.text}`)
    .join("|");

  // 简单hash（FNV-1a变体）
  let hash = 2166136261;
  for (let i = 0; i < base.length; i++) {
    hash ^= base.charCodeAt(i);
    hash +=
      (hash << 1) +
      (hash << 4) +
      (hash << 7) +
      (hash << 8) +
      (hash << 24);
  }

  return `h${(hash >>> 0).toString(16)}`;
}

const WORD_PATTERN = /[a-zA-Z]+(?:['’][a-zA-Z]+)*(?:-[a-zA-Z]+(?:['’][a-zA-Z]+)*)*/g;
const VALID_SINGLE_CHAR_WORDS = new Set(["a", "i"]);
const HYPHEN_PREFIX_PARTS = new Set(["co", "re", "pre", "pro", "anti", "non", "de"]);
const CONTRACTION_EXACT_MAP = {
  "can't": ["can", "not"],
  "won't": ["will", "not"],
  "shan't": ["shall", "not"],
  "ain't": ["am", "not"],
};

function isValidWordToken(token) {
  return (
    /^[a-z]+$/.test(token) &&
    (token.length >= 2 || VALID_SINGLE_CHAR_WORDS.has(token))
  );
}

function normalizeNegativeContractionBase(base) {
  if (base === "ca") return "can";
  if (base === "wo") return "will";
  if (base === "sha") return "shall";
  return base;
}

function expandContractionToken(rawToken) {
  const token = rawToken.toLowerCase().replace(/’/g, "'");
  const exact = CONTRACTION_EXACT_MAP[token];
  if (exact) {
    return exact;
  }

  if (token.endsWith("n't") && token.length > 3) {
    const base = normalizeNegativeContractionBase(token.slice(0, -3));
    return [base, "not"];
  }
  if (token.endsWith("'re") && token.length > 3) {
    return [token.slice(0, -3), "are"];
  }
  if (token.endsWith("'ve") && token.length > 3) {
    return [token.slice(0, -3), "have"];
  }
  if (token.endsWith("'ll") && token.length > 3) {
    return [token.slice(0, -3), "will"];
  }
  if (token.endsWith("'m") && token.length > 2) {
    return [token.slice(0, -2), "am"];
  }
  if (token.endsWith("'d") && token.length > 2) {
    return [token.slice(0, -2)];
  }
  if (token.endsWith("'s") && token.length > 2) {
    return [token.slice(0, -2)];
  }

  return [token.replace(/'/g, "")];
}

function extractWordsFromText(text) {
  const rawTokens = text.match(WORD_PATTERN) || [];
  const words = [];

  rawTokens.forEach((token) => {
    const parts = token
      .toLowerCase()
      .split("-")
      .map((part) => part.trim())
      .filter(Boolean);
    const hasHyphen = parts.length > 1;

    parts.forEach((part, partIndex) => {
      const normalizedPart = part.replace(/['’]/g, "");
      if (
        hasHyphen &&
        partIndex < parts.length - 1 &&
        HYPHEN_PREFIX_PARTS.has(normalizedPart)
      ) {
        return;
      }

      expandContractionToken(part)
          .map((item) => item.trim())
          .filter(Boolean)
          .forEach((item) => {
            if (isValidWordToken(item)) {
              words.push(item);
            }
          });
    });
  });

  return words;
}

const LEMMA_PROTECTED_WORDS = new Set([
  "this",
  "analysis",
  "thesis",
  "crisis",
  "basis",
  "series",
  "species",
  "news",
  "neurips",
]);
const LEMMA_PROTECTED_SUFFIXES = ["is", "us", "ss", "ous", "ics", "ips"];
const LEMMA_IRREGULAR_MAP = {
  am: "be",
  are: "be",
  been: "be",
  does: "do",
  done: "do",
  did: "do",
  goes: "go",
  has: "have",
  is: "be",
  was: "be",
  were: "be",
};

function addLemmaCandidate(candidates, candidate) {
  if (!candidate || !isValidWordToken(candidate)) return;
  if (!candidates.includes(candidate)) {
    candidates.push(candidate);
  }
}

function isConsonant(char) {
  return /^[bcdfghjklmnpqrstvwxyz]$/.test(char);
}

function hasDoubleConsonantEnding(stem) {
  if (stem.length < 2) return false;
  const last = stem[stem.length - 1];
  const prev = stem[stem.length - 2];
  return last === prev && isConsonant(last);
}

function buildLemmaCandidates(word) {
  const w = word.toLowerCase();
  const candidates = [];
  if (w.length <= 3) {
    return candidates;
  }

  if (w.endsWith("ies") && w.length > 4 && /[^aeiou]ies$/.test(w)) {
    addLemmaCandidate(candidates, `${w.slice(0, -3)}y`);
  }
  if (w.endsWith("ied") && w.length > 4) {
    addLemmaCandidate(candidates, `${w.slice(0, -3)}y`);
  }
  if (w.endsWith("ing") && w.length > 5) {
    const stem = w.slice(0, -3);
    addLemmaCandidate(candidates, stem);
    if (!stem.endsWith("e")) {
      addLemmaCandidate(candidates, `${stem}e`);
    }
    if (hasDoubleConsonantEnding(stem)) {
      addLemmaCandidate(candidates, stem.slice(0, -1));
    }
  }
  if (w.endsWith("ed") && w.length > 4) {
    const stem = w.slice(0, -2);
    addLemmaCandidate(candidates, stem);
    if (!stem.endsWith("e")) {
      addLemmaCandidate(candidates, `${stem}e`);
    }
    if (hasDoubleConsonantEnding(stem)) {
      addLemmaCandidate(candidates, stem.slice(0, -1));
    }
  }
  if (w.endsWith("es") && w.length > 4) {
    if (/(?:sses|xes|zes|ches|shes)$/.test(w)) {
      addLemmaCandidate(candidates, w.slice(0, -2));
    }
    // cases -> case 这类复数也可在校验通过时回到原型
    addLemmaCandidate(candidates, w.slice(0, -1));
  }
  if (
    w.endsWith("s") &&
    w.length > 3 &&
    !LEMMA_PROTECTED_WORDS.has(w) &&
    !LEMMA_PROTECTED_SUFFIXES.some((suffix) => w.endsWith(suffix)) &&
    /[^aeiouy]s$/.test(w)
  ) {
    addLemmaCandidate(candidates, w.slice(0, -1));
  }

  return candidates;
}

function isReliableLemmaCandidate(source, candidate, contextWordSet) {
  if (!candidate || candidate === source) return false;
  if (!isValidWordToken(candidate) || candidate.length <= 2) return false;

  if (wordLabelsMap.value.has(candidate)) {
    return true;
  }
  if (contextWordSet?.has(candidate)) {
    return true;
  }

  return false;
}

function simpleLemmatize(word, contextWordSet = null) {
  const w = word.toLowerCase();
  const irregular = LEMMA_IRREGULAR_MAP[w];
  if (irregular) {
    return irregular;
  }

  const candidates = buildLemmaCandidates(w);
  for (const candidate of candidates) {
    if (isReliableLemmaCandidate(w, candidate, contextWordSet)) {
      return candidate;
    }
  }

  return w;
}

function parseWordLabelsCsv(csvText) {
  const map = new Map();
  const lines = csvText.replace(/\r/g, "").split("\n").filter(Boolean);
  if (!lines.length) {
    return map;
  }

  const startIndex = /word\s*,\s*label/i.test(lines[0]) ? 1 : 0;
  for (let i = startIndex; i < lines.length; i++) {
    const line = lines[i];
    const parts = line.split(",");
    if (parts.length < 2) continue;

    const word = parts[0].trim().toLowerCase();
    const label = parts[1].trim();
    if (!word || !BASE_WORD_LABELS.includes(label)) {
      continue;
    }

    map.set(word, label);
  }

  return map;
}

function parseMasteredWordsCsv(csvText) {
  const result = {};
  const lines = csvText.replace(/\r/g, "").split("\n").filter(Boolean);
  if (!lines.length) {
    return result;
  }

  const hasHeader = /word\s*,\s*date/i.test(lines[0]);
  const startIndex = hasHeader ? 1 : 0;

  for (let i = startIndex; i < lines.length; i++) {
    const raw = lines[i];
    const commaIndex = raw.indexOf(",");
    if (commaIndex < 0) continue;

    const word = raw.slice(0, commaIndex).trim().toLowerCase();
    const date = raw.slice(commaIndex + 1).trim().slice(0, 10);
    if (!word) continue;
    result[word] = date || new Date().toISOString().slice(0, 10);
  }

  return result;
}

function formatFileTimestamp(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  const second = String(date.getSeconds()).padStart(2, "0");
  return `${year}${month}${day}-${hour}${minute}${second}`;
}

function decodeBase64Utf8(base64Value) {
  const binary = atob(String(base64Value || ""));
  const bytes = Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function buildMasteredWordsCsv() {
  const rows = ["word,date"];
  const entries = Object.entries(masteredWords.value).sort((a, b) =>
    a[0].localeCompare(b[0])
  );
  entries.forEach(([word, date]) => {
    rows.push(`${word},${String(date || "").slice(0, 10)}`);
  });
  return `${rows.join("\n")}\n`;
}

function parseLearningDataCsv(csvText) {
  const lines = csvText.replace(/\r/g, "").split("\n").filter(Boolean);
  if (!lines.length) {
    return null;
  }

  if (lines[0].trim() !== "section,field_1,field_2,field_3") {
    return null;
  }

  const mastered = {};
  const history = [];
  const meta = {};

  for (let i = 1; i < lines.length; i++) {
    const [section = "", field1 = "", field2 = "", field3 = ""] = lines[i].split(",");
    if (section === "meta") {
      meta[field1.trim()] = [field2.trim(), field3.trim()].filter(Boolean).join(",");
      continue;
    }

    if (section === "mastered") {
      const word = field1.trim().toLowerCase();
      const date = field2.trim().slice(0, 10);
      if (word) {
        mastered[word] = date || new Date().toISOString().slice(0, 10);
      }
      continue;
    }

    if (section === "history") {
      const payload = field1.trim();
      if (!payload) continue;
      try {
        const raw = decodeBase64Utf8(payload);
        const parsed = JSON.parse(raw);
        if (parsed && parsed.id && parsed.url) {
          history.push(parsed);
        }
      } catch (err) {
        console.warn("解析一条历史记录失败，已跳过:", err);
      }
    }
  }

  return {
    mastered_words: mastered,
    player_history: history,
    meta,
  };
}

function loadWordLabelsFromStorage() {
  try {
    const raw = localStorage.getItem(WORD_LABELS_STORAGE_KEY);
    if (!raw) {
      wordLabelsMap.value = new Map();
      return;
    }

    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      wordLabelsMap.value = new Map();
      return;
    }

    const map = new Map();
    Object.entries(parsed).forEach(([word, label]) => {
      const normalizedWord = String(word || "").trim().toLowerCase();
      const normalizedLabel = String(label || "").trim();
      if (
        normalizedWord &&
        BASE_WORD_LABELS.includes(normalizedLabel)
      ) {
        map.set(normalizedWord, normalizedLabel);
      }
    });

    wordLabelsMap.value = map;
  } catch (err) {
    console.warn("读取词表失败:", err);
    wordLabelsMap.value = new Map();
  }
}

function saveWordLabelsToStorage() {
  const payload = {};
  wordLabelsMap.value.forEach((label, word) => {
    payload[word] = label;
  });
  localStorage.setItem(WORD_LABELS_STORAGE_KEY, JSON.stringify(payload));
}

function loadDataVersionsFromStorage() {
  wordLabelsVersion.value =
    localStorage.getItem(WORD_LABELS_VERSION_STORAGE_KEY) || "";
  learningDataVersion.value =
    localStorage.getItem(LEARNING_DATA_VERSION_STORAGE_KEY) || "";
}

function saveWordLabelsVersion(version) {
  wordLabelsVersion.value = version;
  localStorage.setItem(WORD_LABELS_VERSION_STORAGE_KEY, version);
}

function applyWordLabels(parsed, version = FIXED_WORD_LABELS_FILE_NAME) {
  wordLabelsMap.value = parsed;
  saveWordLabelsToStorage();
  saveWordLabelsVersion(version);
  refreshTedMasteredFlags();
}

async function tryLoadWordLabelsFromLocalIfNeeded() {
  if (wordLabelsMap.value.size > 0 && wordLabelsVersion.value) {
    return false;
  }

  try {
    const response = await fetch(`./${FIXED_WORD_LABELS_FILE_NAME}`, { method: "GET" });
    if (!response.ok) {
      return false;
    }

    const text = await response.text();
    const parsed = parseWordLabelsCsv(text);
    if (!parsed.size) {
      return false;
    }

    applyWordLabels(parsed, FIXED_WORD_LABELS_FILE_NAME);
    return true;
  } catch (err) {
    console.warn("读取本地词表失败:", err);
    return false;
  }
}

function saveLearningDataVersion(version) {
  learningDataVersion.value = version;
  localStorage.setItem(LEARNING_DATA_VERSION_STORAGE_KEY, version);
}

function ensureSetupModalState() {
  setupDataModalOpen.value = !isDataSetupReady.value;
}

function loadMasteredWordsFromStorage() {
  try {
    const raw = localStorage.getItem(MASTERED_WORDS_STORAGE_KEY);
    if (!raw) {
      masteredWords.value = {};
      return;
    }

    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      masteredWords.value = {};
      return;
    }

    const normalized = {};
    Object.entries(parsed).forEach(([word, date]) => {
      const normalizedWord = String(word || "").trim().toLowerCase();
      if (!normalizedWord) return;
      normalized[normalizedWord] = String(date || "").slice(0, 10) || "";
    });

    masteredWords.value = normalized;
  } catch (err) {
    console.warn("读取掌握单词失败:", err);
    masteredWords.value = {};
  }
}

function saveMasteredWordsToStorage() {
  localStorage.setItem(
    MASTERED_WORDS_STORAGE_KEY,
    JSON.stringify(masteredWords.value)
  );
}

function refreshTedMasteredFlags() {
  if (!tedResults.value.length) return;

  tedResults.value = tedResults.value.map((item) => {
    const masteredDate = masteredWords.value[item.word] || "";
    return {
      ...item,
      mastered: !!masteredDate,
      mastered_date: masteredDate,
    };
  });

  const unmastered = tedResults.value.filter((r) => !r.mastered);
  const mastered = tedResults.value.filter((r) => r.mastered);
  tedResults.value = [...unmastered, ...mastered];
}

function getWordLabel(word) {
  const normalizedWord = String(word || "").trim().toLowerCase();
  if (!normalizedWord) return FALLBACK_WORD_LABEL;

  const label = String(wordLabelsMap.value.get(normalizedWord) || "").trim();
  if (BASE_WORD_LABELS.includes(label)) {
    return label;
  }
  return FALLBACK_WORD_LABEL;
}

function getWordTags(word) {
  const label = getWordLabel(word);
  if (label === "3000") return ["常用3000"];
  if (label === "5000") return ["常用5000"];
  if (label === "10000") return ["常用10000"];
  return ["常用10000+"];
}

function analyzeSubtitleLines(lines) {
  const wordCounter = new Map();
  const transcriptWordSet = new Set();
  const normalizedLineWords = lines.map((line) => {
    const words = extractWordsFromText(line.text || "");
    words.forEach((word) => transcriptWordSet.add(word));
    return words;
  });

  for (const words of normalizedLineWords) {
    for (const rawWord of words) {
      const lemma = simpleLemmatize(rawWord, transcriptWordSet);
      if (!lemma) continue;
      wordCounter.set(lemma, (wordCounter.get(lemma) || 0) + 1);
    }
  }

  const results = Array.from(wordCounter.entries()).map(([word, count]) => {
    const masteredDate = masteredWords.value[word] || "";
    return {
      word,
      count,
      tags: getWordTags(word),
      mastered: !!masteredDate,
      mastered_date: masteredDate,
    };
  });

  results.sort((a, b) => {
    if (a.mastered !== b.mastered) {
      return a.mastered ? 1 : -1;
    }
    if (a.count !== b.count) {
      return b.count - a.count;
    }
    return a.word.localeCompare(b.word);
  });

  return results;
}

function buildLearningProgress() {
  const masteredSet = new Set(Object.keys(masteredWords.value));
  const sets = labelWordSets.value;
  const progress = {};

  BASE_WORD_LABELS.forEach((label) => {
    const words = sets[label];
    let mastered = 0;
    words.forEach((word) => {
      if (masteredSet.has(word)) {
        mastered++;
      }
    });

    const total = words.size;
    const percentage = total > 0 ? Number(((mastered / total) * 100).toFixed(1)) : 0;

    progress[label] = {
      total,
      mastered,
      percentage,
    };
  });

  let fallbackMastered = 0;
  masteredSet.forEach((word) => {
    if (getWordLabel(word) === FALLBACK_WORD_LABEL) {
      fallbackMastered++;
    }
  });

  const fallbackPercentage = Number(
    (Math.min(fallbackMastered, FALLBACK_WORD_TOTAL) / FALLBACK_WORD_TOTAL * 100).toFixed(1)
  );
  progress[FALLBACK_WORD_LABEL] = {
    total: FALLBACK_WORD_TOTAL,
    mastered: fallbackMastered,
    percentage: fallbackPercentage,
  };

  return progress;
}

async function loadLearningProgress() {
  learningProgress.value = buildLearningProgress();
}

function buildLearningStats(granularity = "day") {
  const dateCount = {};

  Object.values(masteredWords.value).forEach((dateRaw) => {
    const date = String(dateRaw || "").trim();
    if (!date) return;

    const key = granularity === "month" ? date.slice(0, 7) : date;
    if (!key) return;

    dateCount[key] = (dateCount[key] || 0) + 1;
  });

  const sortedDates = Object.keys(dateCount).sort();
  let cumulative = 0;

  return sortedDates.map((date) => {
    cumulative += dateCount[date];
    return {
      date,
      new_words: dateCount[date],
      cumulative,
    };
  });
}

async function loadStatsData() {
  const statsData = buildLearningStats(statsGranularity.value);
  await renderCharts(statsData);
}

async function renderCharts(statsData) {
  if (!cumulativeChartContainer.value || !newWordsChartContainer.value) return;

  const echarts = await import("echarts");

  const dates = statsData.map((item) => item.date);
  const cumulative = statsData.map((item) => item.cumulative);
  const newWords = statsData.map((item) => item.new_words || 0);

  let yAxisMin = 0;
  if (cumulative.length > 0 && cumulative[0] > 0) {
    yAxisMin = Math.max(0, cumulative[0] - 10);
  }

  if (cumulativeChartInstance) {
    cumulativeChartInstance.dispose();
  }
  cumulativeChartInstance = echarts.init(cumulativeChartContainer.value);

  cumulativeChartInstance.setOption({
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
  });

  if (newWordsChartInstance) {
    newWordsChartInstance.dispose();
  }
  newWordsChartInstance = echarts.init(newWordsChartContainer.value);

  newWordsChartInstance.setOption({
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
  });

  if (chartResizeHandler) {
    window.removeEventListener("resize", chartResizeHandler);
  }

  chartResizeHandler = () => {
    if (cumulativeChartInstance) cumulativeChartInstance.resize();
    if (newWordsChartInstance) newWordsChartInstance.resize();
  };
  window.addEventListener("resize", chartResizeHandler);
}

function triggerImportLearningData() {
  if (learningDataInputRef.value) {
    learningDataInputRef.value.click();
  }
}

function triggerWordLabelsUpload() {
  if (wordLabelsInputRef.value) {
    wordLabelsInputRef.value.click();
  }
}

function exportLearningData() {
  const ts = formatFileTimestamp();
  const csv = buildMasteredWordsCsv();
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `learning_data-${ts}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

async function importLearningDataFromFile(file) {
  const text = await readFileAsText(file);
  const lowerName = (file.name || "").toLowerCase();
  if (!lowerName.endsWith(".csv")) {
    throw new Error("仅支持 CSV 文件");
  }

  const parsedLearningData = parseLearningDataCsv(text);
  if (parsedLearningData) {
    masteredWords.value = parsedLearningData.mastered_words || {};
    saveMasteredWordsToStorage();

    if (Array.isArray(parsedLearningData.player_history)) {
      playerHistoryVideos.value = parsedLearningData.player_history
        .filter((item) => item && item.id && item.url)
        .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0))
        .slice(0, 30);
      savePlayerHistory();
    }

    saveLearningDataVersion(FIXED_MASTERED_WORDS_FILE_NAME);
    refreshTedMasteredFlags();
    await loadLearningProgress();
    ensureSetupModalState();
    return "学习数据 CSV 导入成功";
  }

  masteredWords.value = parseMasteredWordsCsv(text);
  saveMasteredWordsToStorage();
  saveLearningDataVersion(FIXED_MASTERED_WORDS_FILE_NAME);
  refreshTedMasteredFlags();
  await loadLearningProgress();
  ensureSetupModalState();
  return "学习数据 CSV 导入成功";
}

async function importWordLabelsFromFile(file) {
  const text = await readFileAsText(file);
  const parsed = parseWordLabelsCsv(text);
  if (!parsed.size) {
    throw new Error("词表为空或格式错误");
  }

  applyWordLabels(parsed, FIXED_WORD_LABELS_FILE_NAME);
  await loadLearningProgress();
  ensureSetupModalState();
  return `词表导入成功，共 ${parsed.size} 个单词`;
}

async function handleImportLearningData(event) {
  const file = event?.target?.files?.[0];
  if (!file) return;

  try {
    const successText = await importLearningDataFromFile(file);
    message.success(successText);
  } catch (err) {
    message.error(`导入失败: ${err.message || err}`);
  } finally {
    if (event?.target) {
      event.target.value = "";
    }
  }
}

async function handleWordLabelsUpload(event) {
  const file = event?.target?.files?.[0];
  if (!file) return;

  try {
    const successText = await importWordLabelsFromFile(file);
    message.success(successText);
  } catch (err) {
    message.error(`词表导入失败: ${err.message || err}`);
  } finally {
    if (event?.target) {
      event.target.value = "";
    }
  }
}

async function handleSetupWordLabelsFileChange(event) {
  const file = event?.target?.files?.[0];
  setupWordLabelsFileName.value = file?.name || "";
  if (!file) return;

  try {
    const successText = await importWordLabelsFromFile(file);
    message.success(successText);
  } catch (err) {
    message.error(`词表导入失败: ${err.message || err}`);
  } finally {
    if (event?.target) {
      event.target.value = "";
    }
  }
}

async function handleSetupLearningDataFileChange(event) {
  const file = event?.target?.files?.[0];
  setupLearningDataFileName.value = file?.name || "";
  if (!file) return;

  try {
    const successText = await importLearningDataFromFile(file);
    message.success(successText);
  } catch (err) {
    message.error(`学习数据导入失败: ${err.message || err}`);
  } finally {
    if (event?.target) {
      event.target.value = "";
    }
  }
}

function closeSetupModal() {
  if (!isDataSetupReady.value) {
    message.warning("请先导入词表和学习数据文件");
    return;
  }
  setupDataModalOpen.value = false;
}

function getWordsByLabel(label) {
  if (label === FALLBACK_WORD_LABEL) {
    return [];
  }
  return Array.from(labelWordSets.value[label] || []);
}

async function showUnmasteredWords(label, progress) {
  if (label === FALLBACK_WORD_LABEL) {
    message.info("10000+ 为默认标签，暂无完整词表，暂不支持未学习单词列表");
    return;
  }

  if (progress.mastered >= progress.total) {
    message.info("所有单词都已掌握！");
    return;
  }

  unmasteredWordsModal.value.label = label;
  unmasteredWordsModal.value.visible = true;
  unmasteredWordsModal.value.loading = true;
  unmasteredWordsModal.value.masteredWords = new Set();
  unmasteredWordsPagination.value.current = 1;

  try {
    const masteredSet = new Set(Object.keys(masteredWords.value));
    unmasteredWordsModal.value.words = getWordsByLabel(label)
      .filter((word) => !masteredSet.has(word))
      .sort();
  } finally {
    unmasteredWordsModal.value.loading = false;
  }
}

function applyWordMasteredStatus(word, mastered) {
  const normalizedWord = String(word || "").trim().toLowerCase();
  if (!normalizedWord) return;

  if (mastered) {
    masteredWords.value = {
      ...masteredWords.value,
      [normalizedWord]: new Date().toISOString().slice(0, 10),
    };
  } else {
    const next = { ...masteredWords.value };
    delete next[normalizedWord];
    masteredWords.value = next;
  }

  saveMasteredWordsToStorage();
}

async function markWordMastered(word) {
  applyWordMasteredStatus(word, true);
  refreshTedMasteredFlags();

  if (unmasteredWordsModal.value.visible) {
    unmasteredWordsModal.value.masteredWords.add(word);
  }

  await loadLearningProgress();
  message.success("已标记为烂熟于心");
}

async function unmarkWordMastered(word) {
  applyWordMasteredStatus(word, false);
  refreshTedMasteredFlags();
  await loadLearningProgress();
  message.success("已取消标记");
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

  const currentPageNo = tedPagination.value.current || 1;
  const pageSize = tedPagination.value.pageSize || 20;
  const startIndex = (currentPageNo - 1) * pageSize;
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
        "将要标记 ",
        h("strong", { style: "color: #1890ff" }, wordsToMark.value.length),
        " 个单词：",
      ]),
      h(
        "div",
        {
          style:
            "max-height: 300px; overflow-y: auto; border: 1px solid #d9d9d9; border-radius: 4px; padding: 12px; background: #fafafa",
        },
        [
          wordsToMark.value.length === 0
            ? h(
                "p",
                { style: "color: #999; text-align: center; padding: 20px" },
                "已移除所有单词"
              )
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
                          onMouseenter: (e) => {
                            e.target.style.color = "#ff4d4f";
                          },
                          onMouseleave: (e) => {
                            e.target.style.color = "#999";
                          },
                          onClick: () => {
                            const idx = wordsToMark.value.findIndex((w) => w.word === item.word);
                            if (idx > -1) {
                              wordsToMark.value.splice(idx, 1);
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
                )
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

    wordsToMark.value.forEach((item) => {
      applyWordMasteredStatus(item.word, true);
    });

    refreshTedMasteredFlags();
    await loadLearningProgress();
    message.success(`成功标记 ${wordsToMark.value.length} 个单词为烂熟于心`);
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

function handleHomeSubtitleFileChange(event) {
  const file = event?.target?.files?.[0] || null;
  homeSubtitleFile.value = file;
  homeSubtitleFileName.value = file?.name || "";
}

function triggerHomeSubtitleUpload() {
  if (!homeSubtitleInputRef.value) return;
  homeSubtitleInputRef.value.value = "";
  homeSubtitleInputRef.value.click();
}

function handleTedSubtitleFileChange(event) {
  const file = event?.target?.files?.[0] || null;
  tedSubtitleFile.value = file;
  tedSubtitleFileName.value = file?.name || "";
  tedSubtitleLines.value = [];
  selectedYoutubeSubtitle.value = "";
  youtubeSubtitles.value = [];
  parsedYoutubeUrl.value = "";
}

async function parseHomeVideo() {
  const url = normalizeYoutubeUrl(homeYoutubeUrl.value);
  if (!url) {
    homeError.value = "请输入YouTube链接";
    return;
  }
  if (!homeSubtitleFile.value) {
    homeError.value = "请先选择本地字幕文件";
    return;
  }

  homeParseLoading.value = true;
  homeError.value = "";
  homeParsedUrl.value = "";
  homeParsedTitle.value = "";
  homeParsedVideoId.value = "";
  homeSubtitleOptions.value = [];
  homeSelectedSubtitle.value = "";
  homeParsedLines.value = [];

  try {
    const videoId = extractYoutubeVideoId(url);
    const lines = await parseSubtitleFile(homeSubtitleFile.value);
    const fallbackTitle = `YouTube 视频 (${videoId})`;
    let resolvedTitle = fallbackTitle;
    try {
      const fetchedTitle = await fetchYoutubeVideoTitle(url);
      if (fetchedTitle) {
        resolvedTitle = fetchedTitle;
      }
    } catch (titleErr) {
      console.warn("读取YouTube标题失败，使用默认标题:", titleErr);
    }

    homeParsedUrl.value = url;
    homeParsedVideoId.value = videoId;
    homeParsedTitle.value = resolvedTitle;
    homeParsedLines.value = lines;

    homeSubtitleOptions.value = [
      {
        language_code: "local",
        language: `本地字幕 · ${homeSubtitleFileName.value || "未命名"}`,
      },
    ];
    homeSelectedSubtitle.value = "local";

    upsertPlayerHistory({
      url,
      videoId,
      title: resolvedTitle,
      subtitleCode: "local",
      subtitleFileName: homeSubtitleFileName.value,
      subtitleLines: lines,
    });

    message.success(`解析成功，共 ${lines.length} 句字幕`);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    homeError.value = `解析失败: ${errorMsg}`;
  } finally {
    homeParseLoading.value = false;
  }
}

async function startLearningFromHome() {
  if (!homeCanStartLearning.value) return;

  playerParsedYoutubeUrl.value = homeParsedUrl.value;
  playerYoutubeUrl.value = homeParsedUrl.value;
  playerVideoId.value = homeParsedVideoId.value;
  playerVideoTitle.value = homeParsedTitle.value;
  playerSubtitleOptions.value = homeSubtitleOptions.value.slice();
  playerSelectedSubtitle.value = homeSelectedSubtitle.value;
  playerSubtitleFileName.value = homeSubtitleFileName.value;
  playerLocalSubtitleLines.value = homeParsedLines.value.slice();
  currentPage.value = "player";
  await loadPlayerTranscript();
}

async function startLearningFromHistory(item) {
  if (!item || !item.url) return;

  homeYoutubeUrl.value = item.url;
  await parseAndLoadPlayerVideo(item.url, {
    title: item.title || "",
    subtitleLines: Array.isArray(item.subtitleLines) ? item.subtitleLines : [],
    subtitleFileName: item.subtitleFileName || "",
  });
}

function isHomeHistorySelected(historyId) {
  return homeSelectedHistoryIds.value.includes(historyId);
}

function toggleHomeHistorySelection(historyId) {
  if (!historyId) return;

  if (isHomeHistorySelected(historyId)) {
    homeSelectedHistoryIds.value = homeSelectedHistoryIds.value.filter(
      (id) => id !== historyId
    );
  } else {
    homeSelectedHistoryIds.value = [...homeSelectedHistoryIds.value, historyId];
  }
}

function toggleHomeHistorySelectionMode() {
  homeHistorySelectionMode.value = !homeHistorySelectionMode.value;
  if (!homeHistorySelectionMode.value) {
    homeSelectedHistoryIds.value = [];
  }
}

async function handleHomeHistoryCardClick(item) {
  if (!item || !item.id) return;

  if (homeHistorySelectionMode.value) {
    toggleHomeHistorySelection(item.id);
    return;
  }

  await startLearningFromHistory(item);
}

function removeHistoryVideo(historyId) {
  if (!historyId) return;
  playerHistoryVideos.value = playerHistoryVideos.value.filter(
    (item) => item.id !== historyId
  );
  homeSelectedHistoryIds.value = homeSelectedHistoryIds.value.filter(
    (id) => id !== historyId
  );
  if (!playerHistoryVideos.value.length) {
    homeHistorySelectionMode.value = false;
  }
  savePlayerHistory();
}

function removeSelectedHistoryVideos() {
  if (!homeSelectedHistoryIds.value.length) return;

  const selectedSet = new Set(homeSelectedHistoryIds.value);
  playerHistoryVideos.value = playerHistoryVideos.value.filter(
    (item) => !selectedSet.has(item.id)
  );
  savePlayerHistory();
  message.success(`已删除 ${selectedSet.size} 个视频`);
  homeSelectedHistoryIds.value = [];
  if (!playerHistoryVideos.value.length) {
    homeHistorySelectionMode.value = false;
  }
}

async function goToSubtitleAnalysisFromHome() {
  if (!homeCanStartLearning.value) return;

  youtubeUrl.value = homeParsedUrl.value;
  parsedYoutubeUrl.value = homeParsedUrl.value;
  youtubeVideoTitle.value = homeParsedTitle.value;
  youtubeSubtitles.value = homeSubtitleOptions.value.slice();
  selectedYoutubeSubtitle.value = homeSelectedSubtitle.value;
  tedSubtitleLines.value = homeParsedLines.value.slice();
  tedSubtitleFileName.value = homeSubtitleFileName.value;
  openTedPage();
  await nextTick();
  await analyzeTedFile();
}

function loadPlayerHistory() {
  try {
    const raw = localStorage.getItem(PLAYER_HISTORY_STORAGE_KEY);
    if (!raw) {
      playerHistoryVideos.value = [];
      homeHistorySelectionMode.value = false;
      homeSelectedHistoryIds.value = [];
      return;
    }

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      playerHistoryVideos.value = [];
      homeHistorySelectionMode.value = false;
      homeSelectedHistoryIds.value = [];
      return;
    }

    playerHistoryVideos.value = parsed
      .filter((item) => item && item.id && item.url)
      .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0));
    homeSelectedHistoryIds.value = [];
    homeHistorySelectionMode.value = false;
  } catch (err) {
    console.warn("读取播放器历史失败:", err);
    playerHistoryVideos.value = [];
    homeHistorySelectionMode.value = false;
    homeSelectedHistoryIds.value = [];
  }
}

function savePlayerHistory() {
  try {
    localStorage.setItem(
      PLAYER_HISTORY_STORAGE_KEY,
      JSON.stringify(playerHistoryVideos.value)
    );
  } catch (err) {
    console.warn("保存播放器历史失败:", err);
    message.warning("历史记录过大，已尝试仅保存最近记录");

    playerHistoryVideos.value = playerHistoryVideos.value.slice(0, 10).map((item) => ({
      ...item,
      subtitleLines: (item.subtitleLines || []).slice(0, 400),
    }));

    try {
      localStorage.setItem(
        PLAYER_HISTORY_STORAGE_KEY,
        JSON.stringify(playerHistoryVideos.value)
      );
    } catch (innerErr) {
      console.warn("降级后仍无法保存历史:", innerErr);
    }
  }
}

function upsertPlayerHistory({
  url,
  videoId,
  title,
  subtitleCode,
  subtitleFileName,
  subtitleLines,
}) {
  const normalizedUrl = normalizeYoutubeUrl(url);
  if (!normalizedUrl) return null;

  const now = Date.now();
  const existingIndex = playerHistoryVideos.value.findIndex(
    (item) => item.url === normalizedUrl
  );
  const existing = existingIndex >= 0 ? playerHistoryVideos.value[existingIndex] : null;

  const entry = {
    id: existing?.id || `${now}-${Math.random().toString(36).slice(2, 8)}`,
    url: normalizedUrl,
    videoId: videoId || existing?.videoId || "",
    title: title || existing?.title || normalizedUrl,
    subtitleCode: subtitleCode || existing?.subtitleCode || "local",
    subtitleFileName: subtitleFileName || existing?.subtitleFileName || "",
    subtitleLines:
      Array.isArray(subtitleLines) && subtitleLines.length
        ? subtitleLines
        : existing?.subtitleLines || [],
    lastUsedAt: now,
  };

  if (existingIndex >= 0) {
    playerHistoryVideos.value.splice(existingIndex, 1, entry);
  } else {
    playerHistoryVideos.value.push(entry);
  }

  playerHistoryVideos.value = playerHistoryVideos.value
    .slice()
    .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0))
    .slice(0, 30);
  savePlayerHistory();

  return entry;
}

async function loadYoutubeSubtitles() {
  const url = normalizeYoutubeUrl(youtubeUrl.value);
  if (!url) {
    tedError.value = "请输入YouTube链接";
    return;
  }
  if (!tedSubtitleFile.value) {
    tedError.value = "请先选择本地字幕文件";
    return;
  }

  youtubeLoading.value = true;
  tedError.value = "";
  parsedYoutubeUrl.value = "";
  youtubeSubtitles.value = [];
  selectedYoutubeSubtitle.value = "";
  youtubeVideoTitle.value = "";
  tedSubtitleLines.value = [];

  try {
    const videoId = extractYoutubeVideoId(url);
    const lines = await parseSubtitleFile(tedSubtitleFile.value);

    parsedYoutubeUrl.value = url;
    youtubeVideoTitle.value = `YouTube 视频 (${videoId})`;
    tedSubtitleLines.value = lines;
    youtubeSubtitles.value = [
      {
        language_code: "local",
        language: `本地字幕 · ${tedSubtitleFileName.value || "未命名"}`,
      },
    ];
    selectedYoutubeSubtitle.value = "local";

    message.success(`字幕解析成功，共 ${lines.length} 句`);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = `解析字幕失败: ${errorMsg}`;
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
    const analyzed = analyzeSubtitleLines(tedSubtitleLines.value);
    tedResults.value = analyzed;
    lastTedAnalysisMeta.value = {
      source: "youtube",
      youtube_url: youtubeUrl.value.trim(),
      language_code: selectedYoutubeSubtitle.value,
      subtitle_hash: computeTranscriptHash(tedSubtitleLines.value),
    };
    tedSelectedTagFilter.value = null;
    tedPagination.value.current = 1;
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = `解析失败: ${errorMsg}`;
  } finally {
    tedLoading.value = false;
  }
}

function clearAbSelection() {
  playerAbStartIndex.value = -1;
  playerAbEndIndex.value = -1;
  playerAbSelectionCandidates.value = [];
  playerAbSelectionMode.value = false;
}

function clearPinnedSubtitleIndex() {
  playerPinnedSubtitleIndex.value = -1;
}

function isIndexInAbRange(index) {
  if (!canPlayAbRange.value) {
    return false;
  }
  const start = Math.min(playerAbStartIndex.value, playerAbEndIndex.value);
  const end = Math.max(playerAbStartIndex.value, playerAbEndIndex.value);
  return index >= start && index <= end;
}

function handlePlaybackBoundary(currentTime) {
  const target = playerPlaybackTarget.value;
  if (!target) return;

  const stopBuffer =
    target.mode === "single" ? SINGLE_LINE_EARLY_PAUSE_SEC : SINGLE_LINE_STOP_BUFFER;

  if (currentTime < target.end - stopBuffer) {
    return;
  }

  if (target.mode === "ab") {
    if (
      englishPlayerInstance &&
      typeof englishPlayerInstance.seekTo === "function" &&
      typeof englishPlayerInstance.playVideo === "function"
    ) {
      englishPlayerInstance.seekTo(target.start, true);
      englishPlayerInstance.playVideo();
      playerCurrentTime.value = target.start;
    }
    return;
  }

  const snappedTime = Math.max(
    Number(target.start || 0),
    Number(target.end || 0) - stopBuffer
  );
  if (englishPlayerInstance && typeof englishPlayerInstance.pauseVideo === "function") {
    englishPlayerInstance.pauseVideo();
  }
  playerCurrentTime.value = snappedTime;
  playerPlaybackTarget.value = null;
}

function hasPlayablePlayerInstance() {
  return (
    !!englishPlayerInstance &&
    playerIframeReady.value &&
    typeof englishPlayerInstance.seekTo === "function" &&
    typeof englishPlayerInstance.playVideo === "function"
  );
}

function hasPlayerApiMethods() {
  return (
    !!englishPlayerInstance &&
    typeof englishPlayerInstance.seekTo === "function" &&
    typeof englishPlayerInstance.playVideo === "function"
  );
}

async function waitForPlayerReady(timeoutMs = 12000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (playerIframeReady.value || hasPlayerApiMethods()) {
      playerIframeReady.value = true;
      return true;
    }
    if (playerInitError.value.startsWith("YouTube 播放器错误码")) {
      return false;
    }
    await new Promise((resolve) => window.setTimeout(resolve, 100));
  }
  return false;
}

async function ensurePlayerReady() {
  playerInitError.value = "";
  if (hasPlayablePlayerInstance()) {
    return true;
  }

  if (!playerVideoId.value) {
    playerInitError.value = "缺少视频 ID";
    return false;
  }

  try {
    await mountEnglishPlayer(playerVideoId.value);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerInitError.value = errorMsg;
    playerError.value = `播放器初始化失败: ${errorMsg}`;
    return false;
  }

  if (!hasPlayablePlayerInstance()) {
    const ready = await waitForPlayerReady(5000);
    if (!ready) {
      playerInitError.value = playerInitError.value || "播放器实例未完成创建";
    }
  }
  return hasPlayablePlayerInstance();
}

async function seekAndPlay(seconds) {
  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance) {
    message.warning(
      playerInitError.value
        ? `播放器尚未准备好：${playerInitError.value}`
        : "播放器尚未准备好"
    );
    return false;
  }

  const start = Number(seconds || 0);
  englishPlayerInstance.seekTo(start, true);
  if (typeof englishPlayerInstance.playVideo === "function") {
    englishPlayerInstance.playVideo();
  }
  playerCurrentTime.value = start;
  return true;
}

function resolveSingleLinePlaybackEnd(line, index = -1) {
  const start = Number(line?.start || 0);
  const rawEnd = Number(line?.end || 0);

  let end = Number.isFinite(rawEnd) && rawEnd > start
    ? rawEnd
    : start + 2;

  const nextLine =
    index >= 0 && index + 1 < playerTranscriptLines.value.length
      ? playerTranscriptLines.value[index + 1]
      : null;
  const nextStart = Number(nextLine?.start || NaN);
  if (Number.isFinite(nextStart) && nextStart > start) {
    end = Math.min(
      end,
      Math.max(start + SINGLE_LINE_MIN_DURATION_SEC, nextStart - SINGLE_LINE_NEXT_GUARD_SEC)
    );
  }

  return Math.max(start + SINGLE_LINE_MIN_DURATION_SEC, end);
}

async function playSingleLine(line, index = -1) {
  if (!line) return;
  if (index >= 0) {
    playerPinnedSubtitleIndex.value = index;
  }
  if (!(await seekAndPlay(line.start))) return;

  const end = resolveSingleLinePlaybackEnd(line, index);
  playerPlaybackTarget.value = {
    mode: "single",
    start: Number(line.start || 0),
    end,
  };
}

async function playSequentialFromCurrentPosition() {
  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance || typeof englishPlayerInstance.playVideo !== "function") {
    message.warning(
      playerInitError.value
        ? `播放器尚未准备好：${playerInitError.value}`
        : "播放器尚未准备好"
    );
    return;
  }

  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  englishPlayerInstance.playVideo();
}

async function playAbRange() {
  if (!canPlayAbRange.value) {
    message.info("请先在字幕中设置 A 和 B");
    return;
  }

  const startIndex = Math.min(playerAbStartIndex.value, playerAbEndIndex.value);
  const endIndex = Math.max(playerAbStartIndex.value, playerAbEndIndex.value);
  const startLine = playerTranscriptLines.value[startIndex];
  const endLine = playerTranscriptLines.value[endIndex];
  if (!startLine || !endLine) return;

  clearPinnedSubtitleIndex();
  if (!(await seekAndPlay(startLine.start))) return;

  playerPlaybackTarget.value = {
    mode: "ab",
    start: Number(startLine.start || 0),
    end: Math.max(Number(endLine.end || 0), Number(startLine.start || 0) + 0.3),
  };
}

function buildAbRangeSubtitleText() {
  if (!canPlayAbRange.value) {
    return "";
  }

  const startIndex = Math.min(playerAbStartIndex.value, playerAbEndIndex.value);
  const endIndex = Math.max(playerAbStartIndex.value, playerAbEndIndex.value);
  const lines = playerTranscriptLines.value.slice(startIndex, endIndex + 1);

  return lines
    .map((line) => String(line?.text || "").replace(/\s+/g, " ").trim())
    .filter((text) => !!text)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}

async function writeClipboardText(text) {
  if (!text) return false;

  if (
    typeof navigator !== "undefined" &&
    navigator.clipboard &&
    typeof navigator.clipboard.writeText === "function"
  ) {
    await navigator.clipboard.writeText(text);
    return true;
  }

  if (typeof document === "undefined") {
    return false;
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  textarea.style.pointerEvents = "none";
  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();
  const copied = document.execCommand("copy");
  document.body.removeChild(textarea);
  return copied;
}

async function copyAbSubtitleRange() {
  if (!canPlayAbRange.value) {
    message.info("请先选择两句字幕作为 A 和 B");
    return;
  }

  const mergedText = buildAbRangeSubtitleText();
  if (!mergedText) {
    message.warning("选中片段没有可复制的字幕文本");
    return;
  }

  try {
    const copied = await writeClipboardText(mergedText);
    if (!copied) {
      throw new Error("copy_failed");
    }
    message.success("已复制 AB 区间字幕（单行文本）");
  } catch {
    message.error("复制失败，请检查浏览器剪贴板权限");
  }
}

function isAbCandidate(index) {
  return playerAbSelectionCandidates.value.includes(index);
}

function toggleAbSelectionMode() {
  if (!playerTranscriptLines.value.length) return;

  if (playerAbSelectionMode.value) {
    clearAbSelection();
    playerPlaybackTarget.value = null;
    message.info("已退出 AB 模式");
    return;
  }

  clearAbSelection();
  playerAbSelectionMode.value = true;
  message.info("请选择两句字幕作为 A / B");
}

function toggleAbCandidate(index) {
  if (index < 0 || index >= playerTranscriptLines.value.length) return;

  const current = playerAbSelectionCandidates.value.slice();
  const existing = current.indexOf(index);
  if (existing >= 0) {
    current.splice(existing, 1);
    playerAbSelectionCandidates.value = current;
    return;
  }

  if (current.length >= 2) {
    current.shift();
  }
  current.push(index);
  playerAbSelectionCandidates.value = current;

  if (current.length === 2) {
    const [first, second] = current;
    playerAbStartIndex.value = Math.min(first, second);
    playerAbEndIndex.value = Math.max(first, second);
    void playAbRange();
  }
}

async function playPrevSubtitle() {
  if (!playerTranscriptLines.value.length) return;

  const base = activePlayerSubtitleIndex.value >= 0 ? activePlayerSubtitleIndex.value : 0;
  const targetIndex = Math.max(0, base - 1);
  const line = playerTranscriptLines.value[targetIndex];
  if (line) await playSingleLine(line, targetIndex);
}

async function playNextSubtitle() {
  if (!playerTranscriptLines.value.length) return;

  const base = activePlayerSubtitleIndex.value >= 0 ? activePlayerSubtitleIndex.value : -1;
  const targetIndex = Math.min(playerTranscriptLines.value.length - 1, base + 1);
  const line = playerTranscriptLines.value[targetIndex];
  if (line) await playSingleLine(line, targetIndex);
}

async function togglePlayerPlayPause() {
  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance) {
    message.warning(
      playerInitError.value
        ? `播放器尚未准备好：${playerInitError.value}`
        : "播放器尚未准备好"
    );
    return;
  }

  if (playerIsPlaying.value) {
    if (typeof englishPlayerInstance.pauseVideo === "function") {
      englishPlayerInstance.pauseVideo();
    }
    playerPlaybackTarget.value = null;
    return;
  }

  await playSequentialFromCurrentPosition();
}

function handlePlayerKeyboardShortcuts(event) {
  if (currentPage.value !== "player" || setupDataModalOpen.value) {
    return;
  }

  const target = event.target;
  if (target instanceof HTMLElement) {
    const tagName = target.tagName;
    if (
      target.isContentEditable ||
      tagName === "INPUT" ||
      tagName === "TEXTAREA" ||
      tagName === "SELECT"
    ) {
      return;
    }
  }

  if (event.code === "Space" || event.key === " ") {
    event.preventDefault();
    void togglePlayerPlayPause();
    return;
  }

  if (event.key === "ArrowLeft") {
    event.preventDefault();
    void playPrevSubtitle();
    return;
  }

  if (event.key === "ArrowRight") {
    event.preventDefault();
    void playNextSubtitle();
  }
}

async function handleSubtitleTimeClick(line, index) {
  if (playerAbSelectionMode.value) {
    toggleAbCandidate(index);
    return;
  }

  await playSingleLine(line, index);
}

async function loadYoutubeIframeApi() {
  if (window.YT && window.YT.Player) {
    return window.YT;
  }

  if (youtubeIframeApiPromise) {
    return youtubeIframeApiPromise;
  }

  youtubeIframeApiPromise = new Promise((resolve, reject) => {
    const scriptId = "youtube-iframe-api-script";
    const scriptSrc = "https://www.youtube.com/iframe_api";
    let resolved = false;
    let pollTimer = null;
    let timeoutId = null;
    const previousReady = window.onYouTubeIframeAPIReady;

    const cleanup = () => {
      if (pollTimer) {
        clearInterval(pollTimer);
        pollTimer = null;
      }
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
      if (window.onYouTubeIframeAPIReady === readyHandler) {
        window.onYouTubeIframeAPIReady = previousReady || null;
      }
    };

    const resolveIfReady = () => {
      if (resolved) return true;
      if (window.YT && window.YT.Player) {
        resolved = true;
        cleanup();
        resolve(window.YT);
        return true;
      }
      return false;
    };

    const readyHandler = () => {
      if (typeof previousReady === "function") {
        try {
          previousReady();
        } catch (err) {
          console.warn("onYouTubeIframeAPIReady 回调异常:", err);
        }
      }
      resolveIfReady();
    };

    window.onYouTubeIframeAPIReady = readyHandler;

    const existingScript = document.getElementById(scriptId);
    if (!existingScript) {
      const script = document.createElement("script");
      script.id = scriptId;
      script.src = scriptSrc;
      script.async = true;
      script.onerror = () => {
        cleanup();
        reject(new Error("无法加载 YouTube 播放器脚本"));
      };
      document.body.appendChild(script);
    }

    if (resolveIfReady()) {
      return;
    }

    pollTimer = setInterval(() => {
      resolveIfReady();
    }, 200);

    timeoutId = setTimeout(() => {
      cleanup();
      const staleScript = document.getElementById(scriptId);
      if (staleScript) {
        staleScript.remove();
      }
      reject(new Error("加载 YouTube 播放器超时，请稍后重试"));
    }, 15000);
  }).catch((err) => {
    youtubeIframeApiPromise = null;
    throw err;
  });

  return youtubeIframeApiPromise;
}

function startEnglishPlayerTimer() {
  stopEnglishPlayerTimer();
  englishPlayerTimer = window.setInterval(() => {
    if (englishPlayerInstance && typeof englishPlayerInstance.getCurrentTime === "function") {
      const currentTime = Number(englishPlayerInstance.getCurrentTime());
      if (!Number.isNaN(currentTime)) {
        playerCurrentTime.value = currentTime;
        handlePlaybackBoundary(currentTime);
      }
    }
  }, PLAYER_TIMER_INTERVAL_MS);
}

function stopEnglishPlayerTimer() {
  if (englishPlayerTimer) {
    clearInterval(englishPlayerTimer);
    englishPlayerTimer = null;
  }
}

async function waitForPlayerRoot(maxAttempts = 20, intervalMs = 100) {
  for (let i = 0; i < maxAttempts; i++) {
    const playerRoot = document.getElementById("english-learning-player");
    if (playerRoot) {
      return playerRoot;
    }
    await new Promise((resolve) => window.setTimeout(resolve, intervalMs));
  }
  return null;
}

function destroyEnglishPlayer() {
  stopEnglishPlayerTimer();
  playerMountPromise = null;
  playerIframeReady.value = false;
  clearPinnedSubtitleIndex();
  if (englishPlayerInstance && typeof englishPlayerInstance.destroy === "function") {
    englishPlayerInstance.destroy();
  }
  englishPlayerInstance = null;
  playerIsPlaying.value = false;
}

async function mountEnglishPlayer(videoId) {
  if (!videoId) return;
  if (playerMountPromise) {
    await playerMountPromise;
    return;
  }

  playerMountPromise = (async () => {
    await nextTick();
    await loadYoutubeIframeApi();

    const playerRoot = await waitForPlayerRoot();
    if (!playerRoot) {
      throw new Error("播放器容器未就绪");
    }

    if (englishPlayerInstance && typeof englishPlayerInstance.loadVideoById === "function") {
      englishPlayerInstance.loadVideoById({ videoId, startSeconds: 0 });
      playerCurrentTime.value = 0;
      playerIsPlaying.value = false;
      const ready = await waitForPlayerReady();
      if (!ready) {
        throw new Error(playerInitError.value || "等待播放器就绪超时");
      }
      startEnglishPlayerTimer();
      return;
    }

    playerIframeReady.value = false;
    englishPlayerInstance = new window.YT.Player("english-learning-player", {
      videoId,
      width: "100%",
      height: "100%",
      playerVars: {
        rel: 0,
        modestbranding: 1,
        playsinline: 1,
      },
      events: {
        onReady: () => {
          playerIframeReady.value = true;
          playerCurrentTime.value = 0;
          playerIsPlaying.value = false;
        },
        onStateChange: (event) => {
          if (!window.YT || typeof window.YT.PlayerState === "undefined") {
            return;
          }
          playerIsPlaying.value = event.data === window.YT.PlayerState.PLAYING;
        },
        onError: (event) => {
          const code = event?.data;
          playerInitError.value = `YouTube 播放器错误码 ${code}`;
          console.warn("YouTube Player onError:", code);
        },
      },
    });

    const ready = await waitForPlayerReady();
    if (!ready) {
      throw new Error(playerInitError.value || "等待播放器就绪超时");
    }
    startEnglishPlayerTimer();
  })();

  try {
    await playerMountPromise;
  } finally {
    playerMountPromise = null;
  }
}

async function parseAndLoadPlayerVideo(url, options = {}) {
  const normalizedUrl = normalizeYoutubeUrl(url);
  if (!normalizedUrl) {
    playerError.value = "请输入YouTube链接";
    return;
  }

  playerMetaLoading.value = true;
  playerError.value = "";
  playerTranscriptLines.value = [];
  playerCurrentTime.value = 0;
  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  clearAbSelection();
  destroyEnglishPlayer();

  try {
    const videoId = extractYoutubeVideoId(normalizedUrl);
    const fallbackTitle = String(options.title || "").trim() || `YouTube 视频 (${videoId})`;
    let resolvedTitle = fallbackTitle;
    if (isGenericYoutubeTitle(resolvedTitle)) {
      try {
        const fetchedTitle = await fetchYoutubeVideoTitle(normalizedUrl);
        if (fetchedTitle) {
          resolvedTitle = fetchedTitle;
        }
      } catch (titleErr) {
        console.warn("读取YouTube标题失败，使用默认标题:", titleErr);
      }
    }

    playerParsedYoutubeUrl.value = normalizedUrl;
    playerYoutubeUrl.value = normalizedUrl;
    playerVideoId.value = videoId;
    playerVideoTitle.value = resolvedTitle;
    playerSubtitleOptions.value = [
      {
        language_code: "local",
        language: `本地字幕 · ${options.subtitleFileName || "未命名"}`,
      },
    ];
    playerSelectedSubtitle.value = "local";
    playerSubtitleFileName.value = options.subtitleFileName || "";
    playerLocalSubtitleLines.value = Array.isArray(options.subtitleLines)
      ? options.subtitleLines.slice()
      : [];

    currentPage.value = "player";
    await loadPlayerTranscript();

    if (playerLocalSubtitleLines.value.length > 0) {
      upsertPlayerHistory({
        url: normalizedUrl,
        videoId,
        title: playerVideoTitle.value,
        subtitleCode: playerSelectedSubtitle.value,
        subtitleFileName: playerSubtitleFileName.value,
        subtitleLines: playerLocalSubtitleLines.value,
      });
    }
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerError.value = `解析播放器视频失败: ${errorMsg}`;
  } finally {
    playerMetaLoading.value = false;
  }
}

async function loadPlayerTranscript() {
  if (!playerCanLoadTranscript.value) {
    return;
  }

  playerTranscriptLoading.value = true;
  playerError.value = "";
  playerTranscriptLines.value = [];
  playerCurrentTime.value = 0;
  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  clearAbSelection();

  try {
    const lines = normalizeSubtitleLines(playerLocalSubtitleLines.value || []);
    playerTranscriptLines.value = lines;

    await mountEnglishPlayer(playerVideoId.value);

    if (!lines.length) {
      playerError.value = "当前视频未加载字幕，请先从首页选择字幕文件";
      return;
    }

    upsertPlayerHistory({
      url: playerYoutubeUrl.value.trim(),
      videoId: playerVideoId.value,
      title: playerVideoTitle.value,
      subtitleCode: playerSelectedSubtitle.value,
      subtitleFileName: playerSubtitleFileName.value,
      subtitleLines: lines,
    });
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerError.value = `加载字幕失败: ${errorMsg}`;
  } finally {
    playerTranscriptLoading.value = false;
  }
}

async function analyzeCurrentSubtitleVocabulary() {
  if (!canAnalyzeCurrentPlayerSubtitle.value) {
    message.info("请先完成视频和字幕加载");
    return;
  }

  youtubeUrl.value = playerParsedYoutubeUrl.value;
  parsedYoutubeUrl.value = playerParsedYoutubeUrl.value;
  youtubeVideoTitle.value = playerVideoTitle.value;
  youtubeSubtitles.value = [
    {
      language_code: "local",
      language: `本地字幕 · ${playerSubtitleFileName.value || "未命名"}`,
    },
  ];
  selectedYoutubeSubtitle.value = "local";
  tedSubtitleLines.value = playerTranscriptLines.value.slice();
  tedSubtitleFileName.value = playerSubtitleFileName.value;

  openTedPage();
  await nextTick();
  await analyzeTedFile();
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function shouldHighlightUnknownToken(rawToken, unknownWords, contextWordSet) {
  const token = String(rawToken || "").toLowerCase();
  if (!token) return false;

  const parts = token
    .split("-")
    .map((part) => part.trim())
    .filter(Boolean);
  const hasHyphen = parts.length > 1;

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const normalizedPart = part.replace(/['’]/g, "");
    if (
      hasHyphen &&
      i < parts.length - 1 &&
      HYPHEN_PREFIX_PARTS.has(normalizedPart)
    ) {
      continue;
    }

    const expandedWords = expandContractionToken(part)
      .map((item) => item.trim().toLowerCase())
      .filter((item) => isValidWordToken(item));

    for (const currentWord of expandedWords) {
      if (unknownWords.has(currentWord)) {
        return true;
      }
      const lemma = simpleLemmatize(currentWord, contextWordSet);
      if (unknownWords.has(lemma)) {
        return true;
      }
    }
  }

  return false;
}

function renderSubtitleTextWithUnknownWords(text) {
  const sourceText = String(text || "");
  const escapedText = escapeHtml(sourceText);
  const unknownWords = playerUnknownWordsFromTedAnalysis.value;
  if (!unknownWords.size) {
    return escapedText;
  }

  const contextWordSet = playerTranscriptWordSet.value;
  const tokenPattern = new RegExp(WORD_PATTERN.source, "g");
  let html = "";
  let lastIndex = 0;
  let match = tokenPattern.exec(sourceText);

  while (match) {
    const token = match[0];
    const tokenStart = match.index;
    const tokenEnd = tokenStart + token.length;
    html += escapeHtml(sourceText.slice(lastIndex, tokenStart));

    const escapedToken = escapeHtml(token);
    if (shouldHighlightUnknownToken(token, unknownWords, contextWordSet)) {
      html += `<span class="player-unknown-word">${escapedToken}</span>`;
    } else {
      html += escapedToken;
    }

    lastIndex = tokenEnd;
    match = tokenPattern.exec(sourceText);
  }

  html += escapeHtml(sourceText.slice(lastIndex));
  return html;
}

function formatSubtitleTime(seconds) {
  const totalSeconds = Math.max(0, Math.floor(Number(seconds || 0)));
  const minutes = Math.floor(totalSeconds / 60);
  const restSeconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(restSeconds).padStart(2, "0")}`;
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
  background: linear-gradient(135deg, #2f8fff 0%, #4fa8ff 55%, #8fcbff 100%);
  padding: 0 18px;
  height: 68px;
  box-shadow: 0 2px 8px rgba(32, 121, 214, 0.24);
  display: flex;
  align-items: stretch;
  gap: 10px;
}

/* 覆盖 antd Layout Header 默认深色背景 */
.ant-layout-header.header {
  background: linear-gradient(135deg, #2f8fff 0%, #4fa8ff 55%, #8fcbff 100%) !important;
  line-height: normal;
}

.header-home-btn {
  border: none;
  background: rgba(255, 255, 255, 0.18);
  color: #fff;
  width: 40px;
  min-width: 40px;
  height: 40px;
  border-radius: 10px;
  align-self: center;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease;
}

.header-home-btn .anticon {
  font-size: 18px;
}

.header-home-btn:hover {
  background: rgba(255, 255, 255, 0.26);
  transform: translateY(-1px);
}

.header-main {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: stretch;
}

.header-title {
  color: #fff;
  margin: 0;
  font-size: 26px;
  font-weight: 700;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  letter-spacing: 0.8px;
  cursor: pointer;
  display: flex;
  align-items: center;
  height: 100%;
  padding: 0 16px 0 4px;
  white-space: nowrap;
}

.header-nav {
  display: flex;
  align-items: stretch;
  min-width: 0;
  overflow-x: auto;
}

.header-nav-item {
  border: none;
  background: transparent;
  color: rgba(255, 255, 255, 0.92);
  padding: 0 16px;
  height: 100%;
  font-size: 15px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
  border-bottom: 3px solid transparent;
  transition: all 0.2s ease;
}

.header-nav-item:hover {
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
}

.header-nav-item.active {
  background: rgba(255, 255, 255, 0.22);
  color: #fff;
  border-bottom-color: #fff;
}

.header-nav-item:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.header-nav-item:disabled:hover {
  background: transparent;
}

.main-content {
  background: #f0f2f5;
  padding: 20px;
  min-height: calc(100vh - 64px);
}

.settings-page {
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - 104px);
}

.settings-card {
  background: #fff;
  border-radius: 10px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.settings-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.settings-meta {
  color: #666;
  font-size: 13px;
}

.content-wrapper {
  display: flex;
  gap: 20px;
  max-width: 100%;
  height: calc(100vh - 104px);
}

.player-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
  height: calc(100vh - 104px);
}

.player-content {
  display: flex;
  gap: 20px;
  flex: 1;
  min-height: 0;
}

.player-video-panel,
.player-subtitle-panel {
  background: #fff;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  min-height: 0;
}

.player-video-panel {
  flex: 1 1 58%;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.player-video-wrapper {
  position: relative;
  width: 100%;
  padding-top: 56.25%;
  border-radius: 10px;
  overflow: hidden;
  background: #000;
}

#english-learning-player {
  position: absolute;
  inset: 0;
}

.player-subtitle-panel {
  flex: 1 1 42%;
  display: flex;
  flex-direction: column;
  min-width: 320px;
}

.player-video-controls {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-top: 4px;
  padding: 12px 14px 14px;
  border-radius: 14px;
  background: #f7fbff;
  border: 1px solid #dbe9ff;
}

.player-video-main-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 18px;
}

.player-video-secondary-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  flex-wrap: wrap;
}

.player-icon-btn {
  width: 74px;
  height: 56px;
  min-width: 74px;
  border-radius: 14px !important;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.player-icon-btn .anticon {
  font-size: 22px;
}

.player-icon-btn-play {
  width: 98px;
  height: 68px;
  min-width: 98px;
  border-radius: 16px !important;
}

.player-icon-btn-play .anticon {
  font-size: 30px;
}

.player-secondary-btn {
  height: 46px;
  min-width: 130px;
  padding: 0 24px !important;
  font-size: 15px;
  font-weight: 600;
  border-radius: 12px !important;
}

.player-ab-hint {
  color: #666;
  font-size: 13px;
  text-align: center;
}

.player-subtitle-list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-right: 4px;
}

.player-subtitle-item {
  display: grid;
  grid-template-columns: 60px 1fr;
  gap: 12px;
  align-items: start;
  padding: 10px 12px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  cursor: default;
  transition: all 0.2s ease;
  background: #fff;
}

.player-subtitle-item.ab-select-mode {
  grid-template-columns: 28px 60px 1fr;
}

.player-subtitle-item:hover {
  border-color: #91caff;
  background: #f5faff;
}

.player-subtitle-item.active {
  border-color: #1890ff;
  background: #e6f7ff;
}

.player-subtitle-item.in-ab-range {
  border-color: #95de64;
  background: #f6ffed;
}

.player-subtitle-time {
  color: #1890ff;
  font-size: 12px;
  font-weight: 700;
  padding-top: 2px;
  cursor: pointer;
  user-select: none;
}

.player-subtitle-time:focus-visible {
  outline: 2px solid #91caff;
  outline-offset: 2px;
  border-radius: 4px;
}

.player-subtitle-text {
  color: #262626;
  font-size: 15px;
  line-height: 1.5;
  user-select: text;
  cursor: text;
}

.player-unknown-word {
  background: #e6f4ff;
  color: #262626;
  border-radius: 4px;
  padding: 0 4px;
  margin: 0 1px;
  font-weight: 500;
}

.player-ab-select-cell {
  display: flex;
  justify-content: center;
  padding-top: 2px;
}

.player-subtitle-empty {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  color: #999;
  font-size: 14px;
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

.setup-modal-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.setup-modal-desc {
  color: #555;
  margin-bottom: 4px;
}

.setup-modal-item {
  padding: 12px;
  border-radius: 8px;
  border: 1px solid #e6e6e6;
  background: #fafafa;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.setup-modal-item-title {
  color: #222;
  font-weight: 600;
  font-size: 14px;
}

.setup-modal-meta {
  color: #666;
  font-size: 12px;
}

.setup-modal-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 8px;
}

/* 上方左右布局 */
.config-top-section {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
  align-items: flex-start;
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

/* 按钮风格统一（保留尺寸差异） */
.ant-btn:not(.ant-btn-link):not(.ant-btn-text) {
  border-radius: 8px;
  font-weight: 500;
  transition: all 0.2s ease;
}

.ant-btn-default:not(.ant-btn-dangerous),
.ant-btn-dashed:not(.ant-btn-dangerous) {
  background: #f5faff;
  border-color: #91caff;
  color: #0958d9;
}

.ant-btn-default:not(.ant-btn-dangerous):hover,
.ant-btn-dashed:not(.ant-btn-dangerous):hover {
  background: #e6f4ff;
  border-color: #69b1ff;
  color: #1677ff;
}

.ant-btn-primary {
  background: #1677ff !important;
  border-color: #1677ff !important;
  color: #fff !important;
  box-shadow: 0 2px 6px rgba(22, 119, 255, 0.2);
}

.ant-btn-primary:hover {
  background: #4096ff !important;
  border-color: #4096ff !important;
  color: #fff !important;
}

.ant-btn-dangerous.ant-btn-default,
.ant-btn-dangerous.ant-btn-dashed {
  background: #fff2f0;
  border-color: #ffccc7;
  color: #cf1322;
}

.ant-btn-dangerous.ant-btn-default:hover,
.ant-btn-dangerous.ant-btn-dashed:hover {
  background: #ffece8;
  border-color: #ffa39e;
  color: #cf1322;
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

  .player-page {
    height: auto;
  }

  .player-content {
    flex-direction: column;
    min-height: auto;
  }

  .player-video-panel,
  .player-subtitle-panel {
    width: 100%;
    min-width: 0;
  }

  .player-subtitle-panel {
    height: 460px;
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
    padding: 0 10px;
    height: 60px;
  }

  .header-home-btn {
    width: 34px;
    min-width: 34px;
    height: 34px;
    border-radius: 8px;
  }

  .header-title {
    font-size: 18px;
    padding-right: 8px;
  }

  .header-nav-item {
    padding: 0 10px;
    font-size: 13px;
  }

  .main-content {
    padding: 15px;
  }

  .settings-actions {
    align-items: stretch;
  }

  .content-wrapper {
    gap: 15px;
  }

  .table-section,
  .config-section {
    padding: 15px;
  }

  .player-video-controls {
    width: 100%;
    padding: 10px 10px 12px;
    gap: 10px;
  }

  .player-video-main-controls {
    gap: 12px;
  }

  .player-icon-btn {
    width: 62px;
    min-width: 62px;
    height: 50px;
    border-radius: 12px !important;
  }

  .player-icon-btn .anticon {
    font-size: 19px;
  }

  .player-icon-btn-play {
    width: 82px;
    min-width: 82px;
    height: 60px;
    border-radius: 14px !important;
  }

  .player-icon-btn-play .anticon {
    font-size: 24px;
  }

  .player-secondary-btn {
    min-width: 112px;
    height: 42px;
    padding: 0 18px !important;
    font-size: 14px;
  }

  .player-subtitle-item {
    grid-template-columns: 52px 1fr;
    gap: 8px;
    padding: 9px 10px;
  }

  .player-subtitle-item.ab-select-mode {
    grid-template-columns: 24px 52px 1fr;
  }

  .player-subtitle-text {
    font-size: 14px;
  }

  .home-entry-row {
    flex-direction: column;
    align-items: stretch;
  }

  .home-history-header {
    flex-direction: column;
    align-items: stretch;
  }

  .home-history-toolbar {
    width: 100%;
    justify-content: flex-end;
  }

  .home-history-grid {
    grid-template-columns: 1fr;
  }
}

/* 首页样式 */
.home-player-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
  min-height: calc(100vh - 104px);
}

.home-player-entry {
  background: #fff;
  border-radius: 10px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.home-player-entry.no-history {
  margin: auto;
  width: min(760px, 100%);
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 180px;
}

.home-player-entry.no-history .home-entry-row {
  margin-top: 0;
}

.home-entry-title h2 {
  margin: 0 0 6px 0;
  color: #262626;
  font-size: 28px;
  font-weight: 700;
}

.home-entry-title p {
  margin: 0;
  color: #666;
  font-size: 14px;
}

.home-entry-row {
  margin-top: 16px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.home-link-input {
  width: clamp(240px, 46vw, 460px);
}

.home-upload-status {
  max-width: min(320px, 100%);
  padding: 6px 10px;
  border-radius: 999px;
  border: 1px solid #d9e6f6;
  background: #f7fbff;
  color: #7a8699;
  font-size: 12px;
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.home-upload-status.ready {
  border-color: #91caff;
  background: #e6f4ff;
  color: #0958d9;
}

.home-entry-next {
  margin-top: 14px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.home-entry-video-title {
  margin-top: 12px;
  color: #666;
  font-size: 13px;
}

.home-history-card {
  background: #fff;
  border-radius: 10px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.home-history-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 14px;
}

.home-history-header .section-header {
  margin-bottom: 0;
}

.home-history-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.home-history-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 12px;
}

.home-history-card-item {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 8px;
  border: 1px solid #dfe6f0;
  border-radius: 10px;
  padding: 12px;
  background: #fff;
  cursor: pointer;
  transition: all 0.2s ease;
}

.home-history-card-item:hover {
  border-color: #69b1ff;
  background: #f5faff;
  box-shadow: 0 6px 14px rgba(22, 119, 255, 0.12);
  transform: translateY(-1px);
}

.home-history-card-item.selection-mode {
  border-style: dashed;
}

.home-history-card-item.selected {
  border-color: #1677ff;
  background: #e6f4ff;
  box-shadow: 0 0 0 2px rgba(22, 119, 255, 0.16);
}

.home-history-card-check {
  align-self: flex-start;
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid #91caff;
  background: #f0f7ff;
  color: #1677ff;
  font-size: 12px;
  font-weight: 600;
}

.home-history-card-item.selected .home-history-card-check {
  border-color: #1677ff;
  background: #1677ff;
  color: #fff;
}

.home-history-thumb {
  width: 100%;
  aspect-ratio: 16 / 9;
  border-radius: 8px;
  overflow: hidden;
  background: #dceafe;
  border: 1px solid #cfe0f6;
}

.home-history-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
  transition: transform 0.25s ease;
}

.home-history-card-item:hover .home-history-thumb img {
  transform: scale(1.03);
}

.home-history-thumb.placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #7a8699;
  font-size: 12px;
}

.home-history-title {
  font-size: 15px;
  font-weight: 600;
  color: #222;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}

.home-history-url {
  margin-top: 4px;
  color: #888;
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.home-history-meta {
  color: #7a8699;
  font-size: 12px;
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
  .header-title {
    font-size: 16px;
    padding-right: 6px;
    letter-spacing: 0.3px;
  }

  .header-nav-item {
    padding: 0 8px;
    font-size: 12px;
  }

  .section-header h2 {
    font-size: 16px;
  }
}
</style>
