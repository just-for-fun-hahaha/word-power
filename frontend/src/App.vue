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
              type="default"
              @click="currentPage = 'player'"
              v-if="currentPage !== 'player' && !!playerVideoId"
            >
              播放器
            </a-button>
            <a-button
              type="default"
              @click="openTedPage"
              v-if="currentPage !== 'ted'"
            >
              词汇分析
            </a-button>
            <a-button
              type="primary"
              @click="showStatsPage = true"
              v-if="currentPage === 'ted' && !showStatsPage"
            >
              <template #icon>
                <BarChartOutlined />
              </template>
              统计图表
            </a-button>
            <a-button
              type="default"
              @click="showStatsPage = false"
              v-if="currentPage === 'ted' && showStatsPage"
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
          <div v-if="currentPage === 'home'" class="home-player-page">
            <div
              class="home-player-entry"
              :class="{ 'no-history': playerHistoryVideos.length === 0 }"
            >
              <div
                v-if="playerHistoryVideos.length > 0"
                class="home-entry-title"
              >
                <h2>YouTube 英语学习</h2>
                <p>
                  {{
                    playerHistoryVideos.length === 0
                      ? "粘贴视频链接后开始解析字幕"
                      : "添加新视频，或从历史列表继续学习"
                  }}
                </p>
              </div>
              <div class="home-entry-row">
                <a-input
                  v-model:value="homeYoutubeUrl"
                  placeholder="粘贴 YouTube 视频链接"
                  :disabled="homeParseLoading"
                  allow-clear
                  @pressEnter="parseHomeVideo"
                />
                <a-button
                  type="primary"
                  :loading="homeParseLoading"
                  :disabled="!homeYoutubeUrl.trim()"
                  @click="parseHomeVideo"
                >
                  开始解析
                </a-button>
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
              <div class="section-header">
                <h2>已添加视频</h2>
                <p>点击开始学习可直接进入播放器</p>
              </div>
              <div class="home-history-list">
                <div
                  v-for="item in playerHistoryVideos"
                  :key="item.id"
                  class="home-history-item"
                >
                  <div class="home-history-main">
                    <div class="home-history-title">
                      {{ item.title || item.url }}
                    </div>
                    <div class="home-history-url">{{ item.url }}</div>
                  </div>
                  <div class="home-history-actions">
                    <a-button
                      type="primary"
                      size="small"
                      @click="startLearningFromHistory(item)"
                    >
                      开始学习
                    </a-button>
                    <a-button
                      danger
                      size="small"
                      @click="removeHistoryVideo(item.id)"
                    >
                      删除
                    </a-button>
                  </div>
                </div>
              </div>
            </div>

            <div
              v-if="playerHistoryVideos.length > 0 || homeSubtitleOptions.length > 0"
              class="home-extension-actions"
            >
              <a-button @click="openTedPage">词汇分析</a-button>
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
                      <h2>YouTube 字幕</h2>
                    </div>

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
          </div>

          <!-- ========== 英语播放器页面 ========== -->
          <div v-if="currentPage === 'player'" class="player-page">
            <div class="player-toolbar" v-if="playerVideoTitle">
              <div v-if="playerVideoTitle" class="player-toolbar-title">
                {{ playerVideoTitle }}
              </div>
            </div>

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
                <div class="section-header">
                  <h2>视频播放</h2>
                  <p>
                    点击右侧字幕句子即可跳转播放，当前时间：
                    {{ formatSubtitleTime(playerCurrentTime) }}
                  </p>
                </div>
                <div class="player-video-wrapper">
                  <div id="english-learning-player"></div>
                </div>
              </div>

              <div class="player-subtitle-panel">
                <div class="section-header">
                  <h2>英文字幕</h2>
                  <p v-if="playerTranscriptLines.length > 0">
                    共 {{ playerTranscriptLines.length }} 句
                  </p>
                  <p v-else>先解析字幕并加载播放器</p>
                </div>

                <div
                  v-if="playerTranscriptLines.length > 0"
                  class="player-subtitle-controls"
                >
                  <a-button @click="playPrevSubtitle" :disabled="!canJumpSubtitle">
                    上一句
                  </a-button>
                  <a-button
                    type="primary"
                    @click="togglePlayerPlayPause"
                    :disabled="!canControlPlayback"
                  >
                    {{ playerIsPlaying ? "暂停" : "播放" }}
                  </a-button>
                  <a-button @click="playNextSubtitle" :disabled="!canJumpSubtitle">
                    下一句
                  </a-button>
                  <a-button
                    :type="playerAbSelectionMode ? 'primary' : 'default'"
                    @click="toggleAbSelectionMode"
                  >
                    AB播放
                  </a-button>
                  <a-button
                    type="dashed"
                    :loading="tedLoading"
                    :disabled="!canAnalyzeCurrentPlayerSubtitle"
                    @click="analyzeCurrentSubtitleVocabulary"
                  >
                    词汇分析
                  </a-button>
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
                      'unknown-line': hasUnknownWordsInLine(idx),
                      'ab-select-mode': playerAbSelectionMode,
                    }"
                    @click="handleSubtitleLineClick(line, idx)"
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
                    <div class="player-subtitle-time">
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
const currentPage = ref("home"); // 'home' | 'ted' | 'player'
let youtubeIframeApiPromise = null;
let englishPlayerInstance = null;
let englishPlayerTimer = null;
const PLAYER_HISTORY_STORAGE_KEY = "word_power_player_history_v1";
const homeYoutubeUrl = ref("");
const homeParseLoading = ref(false);
const homeError = ref("");
const homeParsedUrl = ref("");
const homeParsedTitle = ref("");
const homeParsedVideoId = ref("");
const homeSubtitleOptions = ref([]);
const homeSelectedSubtitle = ref("");

function goHome() {
  currentPage.value = "home";
  showStatsPage.value = false;
}

function openTedPage() {
  showStatsPage.value = false;
  currentPage.value = "ted";
}

// 统计页面相关状态
const showStatsPage = ref(false);
const statsGranularity = ref("day");
const cumulativeChartContainer = ref(null);
const newWordsChartContainer = ref(null);
let cumulativeChartInstance = null;
let newWordsChartInstance = null;

const learningProgress = ref(null); // 学习进度数据

onMounted(async () => {
  await loadLearningProgress();
  loadPlayerHistory();
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
  destroyEnglishPlayer();
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

async function markWordMastered(word) {
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
      const item = tedResults.value.find((r) => r.word === word);
      if (item) {
        item.mastered = true;
        item.mastered_date = new Date().toISOString().split("T")[0];
        const unmastered = tedResults.value.filter((r) => !r.mastered);
        const mastered = tedResults.value.filter((r) => r.mastered);
        tedResults.value = [...unmastered, ...mastered];
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

async function unmarkWordMastered(word) {
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
      const item = tedResults.value.find((r) => r.word === word);
      if (item) {
        item.mastered = false;
        item.mastered_date = "";
        const unmastered = tedResults.value.filter((r) => !r.mastered);
        const mastered = tedResults.value.filter((r) => r.mastered);
        tedResults.value = [...unmastered, ...mastered];
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

const youtubeUrl = ref("");
const parsedYoutubeUrl = ref("");
const youtubeVideoTitle = ref("");
const youtubeSubtitles = ref([]);
const selectedYoutubeSubtitle = ref("");
const youtubeLoading = ref(false);
const tedResults = ref([]);
const tedLoading = ref(false);
const tedError = ref("");
const lastTedAnalysisMeta = ref({
  source: "",
  youtube_url: "",
  language_code: "",
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
    !!selectedYoutubeSubtitle.value
  );
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
    const response = await fetch("/api/analyze-youtube-subtitle", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        youtube_url: youtubeUrl.value.trim(),
        language_code: selectedYoutubeSubtitle.value,
      }),
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
      lastTedAnalysisMeta.value = {
        source: "youtube",
        youtube_url: youtubeUrl.value.trim(),
        language_code: selectedYoutubeSubtitle.value,
      };
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

// ========== 英语播放器页面相关 ==========

const playerYoutubeUrl = ref("");
const playerParsedYoutubeUrl = ref("");
const playerVideoId = ref("");
const playerVideoTitle = ref("");
const playerSubtitleOptions = ref([]);
const playerSelectedSubtitle = ref("");
const playerHistoryVideos = ref([]);
const playerMetaLoading = ref(false);
const playerTranscriptLoading = ref(false);
const playerError = ref("");
const playerTranscriptLines = ref([]);
const playerCurrentTime = ref(0);
const playerSubtitleListRef = ref(null);
const playerAbStartIndex = ref(-1);
const playerAbEndIndex = ref(-1);
const playerAbSelectionMode = ref(false);
const playerAbSelectionCandidates = ref([]);
const playerIsPlaying = ref(false);
const playerPlaybackTarget = ref(null);

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

const canControlPlayback = computed(() => {
  return playerTranscriptLines.value.length > 0;
});

const canJumpSubtitle = computed(() => {
  return playerTranscriptLines.value.length > 0;
});

const canAnalyzeCurrentPlayerSubtitle = computed(() => {
  return !!playerParsedYoutubeUrl.value && !!playerSelectedSubtitle.value;
});

const playerUnknownWordsFromTedAnalysis = computed(() => {
  if (
    lastTedAnalysisMeta.value.source !== "youtube" ||
    lastTedAnalysisMeta.value.youtube_url !== playerParsedYoutubeUrl.value ||
    lastTedAnalysisMeta.value.language_code !== playerSelectedSubtitle.value
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

const playerUnknownLineIndices = computed(() => {
  const unknownWords = playerUnknownWordsFromTedAnalysis.value;
  const indices = new Set();
  if (!unknownWords.size || !playerTranscriptLines.value.length) {
    return indices;
  }

  const wordPattern = /\b[a-zA-Z]+(?:-[a-zA-Z]+)*\b/g;
  playerTranscriptLines.value.forEach((line, index) => {
    const words = (line.text || "").match(wordPattern) || [];
    if (words.some((word) => unknownWords.has(word.toLowerCase()))) {
      indices.add(index);
    }
  });
  return indices;
});

const homeCanStartLearning = computed(() => {
  return (
    !!homeYoutubeUrl.value.trim() &&
    !!homeParsedVideoId.value &&
    homeYoutubeUrl.value.trim() === homeParsedUrl.value &&
    !!homeSelectedSubtitle.value
  );
});

const activePlayerSubtitleIndex = computed(() => {
  const lines = playerTranscriptLines.value;
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
  playerTranscriptLines.value = [];
  playerCurrentTime.value = 0;
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
});

watch(playerAbSelectionMode, (mode) => {
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
    await mountEnglishPlayer(playerVideoId.value);
  }
});

watch(activePlayerSubtitleIndex, (index, prev) => {
  if (
    index < 0 ||
    index === prev ||
    !playerSubtitleListRef.value
  ) {
    return;
  }

  const activeNode = playerSubtitleListRef.value.querySelector(
    `[data-sub-index="${index}"]`
  );
  if (activeNode) {
    activeNode.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }
});

async function loadYoutubeIframeApi() {
  if (window.YT && window.YT.Player) {
    return window.YT;
  }

  if (youtubeIframeApiPromise) {
    return youtubeIframeApiPromise;
  }

  youtubeIframeApiPromise = new Promise((resolve, reject) => {
    const timeoutId = setTimeout(() => {
      reject(new Error("加载 YouTube 播放器超时"));
    }, 15000);

    const previousReady = window.onYouTubeIframeAPIReady;
    window.onYouTubeIframeAPIReady = () => {
      if (typeof previousReady === "function") {
        previousReady();
      }
      clearTimeout(timeoutId);
      resolve(window.YT);
    };

    const existingScript = document.getElementById("youtube-iframe-api-script");
    if (!existingScript) {
      const script = document.createElement("script");
      script.id = "youtube-iframe-api-script";
      script.src = "https://www.youtube.com/iframe_api";
      script.async = true;
      script.onerror = () => {
        clearTimeout(timeoutId);
        reject(new Error("无法加载 YouTube 播放器脚本"));
      };
      document.body.appendChild(script);
    }
  }).catch((err) => {
    youtubeIframeApiPromise = null;
    throw err;
  });

  return youtubeIframeApiPromise;
}

function startEnglishPlayerTimer() {
  stopEnglishPlayerTimer();
  englishPlayerTimer = window.setInterval(() => {
    if (
      englishPlayerInstance &&
      typeof englishPlayerInstance.getCurrentTime === "function"
    ) {
      const currentTime = Number(englishPlayerInstance.getCurrentTime());
      if (!Number.isNaN(currentTime)) {
        playerCurrentTime.value = currentTime;
        handlePlaybackBoundary(currentTime);
      }
    }
  }, 300);
}

function stopEnglishPlayerTimer() {
  if (englishPlayerTimer) {
    clearInterval(englishPlayerTimer);
    englishPlayerTimer = null;
  }
}

function destroyEnglishPlayer() {
  stopEnglishPlayerTimer();
  if (
    englishPlayerInstance &&
    typeof englishPlayerInstance.destroy === "function"
  ) {
    englishPlayerInstance.destroy();
  }
  englishPlayerInstance = null;
  playerIsPlaying.value = false;
}

async function parseHomeVideo() {
  const url = homeYoutubeUrl.value.trim();
  if (!url) {
    return;
  }

  homeParseLoading.value = true;
  homeError.value = "";
  homeParsedUrl.value = "";
  homeParsedTitle.value = "";
  homeParsedVideoId.value = "";
  homeSubtitleOptions.value = [];
  homeSelectedSubtitle.value = "";

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
    if (data.status !== "success") {
      homeError.value = "解析失败: " + (data.message || "未知错误");
      return;
    }

    homeParsedUrl.value = url;
    homeParsedTitle.value = data.video_title || "";
    homeParsedVideoId.value = data.video_id || "";
    homeSubtitleOptions.value = data.subtitles || [];

    if (!homeSubtitleOptions.value.length) {
      homeError.value = "未找到英文人工字幕";
      return;
    }

    homeSelectedSubtitle.value = homeSubtitleOptions.value[0].language_code;
    upsertPlayerHistory({
      url,
      videoId: homeParsedVideoId.value,
      title: homeParsedTitle.value,
      subtitleCode: homeSelectedSubtitle.value,
    });
    message.success("解析成功，可开始学习");
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    homeError.value = "请求失败: " + errorMsg;
    console.error("首页解析视频失败:", err);
  } finally {
    homeParseLoading.value = false;
  }
}

async function startLearningFromHome() {
  if (!homeCanStartLearning.value) {
    return;
  }

  playerYoutubeUrl.value = homeParsedUrl.value;
  playerParsedYoutubeUrl.value = homeParsedUrl.value;
  playerVideoId.value = homeParsedVideoId.value;
  playerVideoTitle.value = homeParsedTitle.value;
  playerSubtitleOptions.value = homeSubtitleOptions.value.slice();
  playerSelectedSubtitle.value = homeSelectedSubtitle.value;
  currentPage.value = "player";
  await loadPlayerTranscript();
}

async function startLearningFromHistory(item) {
  if (!item || !item.url) {
    return;
  }
  homeYoutubeUrl.value = item.url;
  await parseAndLoadPlayerVideo(item.url, {
    preferredSubtitle: item.subtitleCode || "",
  });
  currentPage.value = "player";
}

function removeHistoryVideo(historyId) {
  if (!historyId) {
    return;
  }
  playerHistoryVideos.value = playerHistoryVideos.value.filter(
    (item) => item.id !== historyId
  );
  savePlayerHistory();
}

function goToSubtitleAnalysisFromHome() {
  if (!homeCanStartLearning.value) {
    return;
  }

  youtubeUrl.value = homeParsedUrl.value;
  parsedYoutubeUrl.value = homeParsedUrl.value;
  youtubeVideoTitle.value = homeParsedTitle.value;
  youtubeSubtitles.value = homeSubtitleOptions.value.slice();
  selectedYoutubeSubtitle.value = homeSelectedSubtitle.value;
  openTedPage();
}

function loadPlayerHistory() {
  try {
    const raw = localStorage.getItem(PLAYER_HISTORY_STORAGE_KEY);
    if (!raw) {
      playerHistoryVideos.value = [];
      return;
    }

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      playerHistoryVideos.value = [];
      return;
    }

    playerHistoryVideos.value = parsed
      .filter((item) => item && item.id && item.url)
      .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0));
  } catch (err) {
    console.warn("读取播放器历史失败:", err);
    playerHistoryVideos.value = [];
  }
}

function savePlayerHistory() {
  localStorage.setItem(
    PLAYER_HISTORY_STORAGE_KEY,
    JSON.stringify(playerHistoryVideos.value)
  );
}

function upsertPlayerHistory({ url, videoId, title, subtitleCode }) {
  const normalizedUrl = (url || "").trim();
  if (!normalizedUrl) {
    return null;
  }

  const now = Date.now();
  const existingIndex = playerHistoryVideos.value.findIndex(
    (item) => item.url === normalizedUrl
  );
  const existing =
    existingIndex >= 0 ? playerHistoryVideos.value[existingIndex] : null;

  const entry = {
    id: existing?.id || `${now}-${Math.random().toString(36).slice(2, 8)}`,
    url: normalizedUrl,
    videoId: videoId || existing?.videoId || "",
    title: title || existing?.title || normalizedUrl,
    subtitleCode: subtitleCode || existing?.subtitleCode || "",
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
    .slice(0, 80);
  savePlayerHistory();
  return entry;
}

function clearAbSelection() {
  playerAbStartIndex.value = -1;
  playerAbEndIndex.value = -1;
  playerAbSelectionCandidates.value = [];
  playerAbSelectionMode.value = false;
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
  if (!target) {
    return;
  }

  if (currentTime + 0.05 < target.end) {
    return;
  }

  if (
    englishPlayerInstance &&
    typeof englishPlayerInstance.pauseVideo === "function"
  ) {
    englishPlayerInstance.pauseVideo();
  }
  playerPlaybackTarget.value = null;
}

function seekAndPlay(seconds) {
  if (
    !englishPlayerInstance ||
    typeof englishPlayerInstance.seekTo !== "function"
  ) {
    message.warning("播放器尚未准备好");
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

function playSingleLine(line) {
  if (!seekAndPlay(line.start)) {
    return;
  }
  const end = Math.max(Number(line.end || 0), Number(line.start || 0) + 0.3);
  playerPlaybackTarget.value = {
    mode: "single",
    start: Number(line.start || 0),
    end,
  };
}

function playSequentialFromCurrentPosition() {
  if (
    !englishPlayerInstance ||
    typeof englishPlayerInstance.playVideo !== "function"
  ) {
    message.warning("播放器尚未准备好");
    return;
  }
  playerPlaybackTarget.value = null;
  englishPlayerInstance.playVideo();
}

function playAbRange() {
  if (!canPlayAbRange.value) {
    message.info("请先在字幕中设置 A 和 B");
    return;
  }

  const startIndex = Math.min(playerAbStartIndex.value, playerAbEndIndex.value);
  const endIndex = Math.max(playerAbStartIndex.value, playerAbEndIndex.value);
  const startLine = playerTranscriptLines.value[startIndex];
  const endLine = playerTranscriptLines.value[endIndex];
  if (!startLine || !endLine) {
    return;
  }

  if (!seekAndPlay(startLine.start)) {
    return;
  }

  playerPlaybackTarget.value = {
    mode: "ab",
    start: Number(startLine.start || 0),
    end: Math.max(Number(endLine.end || 0), Number(startLine.start || 0) + 0.3),
  };
}

function isAbCandidate(index) {
  return playerAbSelectionCandidates.value.includes(index);
}

function toggleAbSelectionMode() {
  if (!playerTranscriptLines.value.length) {
    return;
  }

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
  if (index < 0 || index >= playerTranscriptLines.value.length) {
    return;
  }

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
    playAbRange();
  }
}

function playPrevSubtitle() {
  if (!playerTranscriptLines.value.length) {
    return;
  }
  const base =
    activePlayerSubtitleIndex.value >= 0 ? activePlayerSubtitleIndex.value : 0;
  const targetIndex = Math.max(0, base - 1);
  const line = playerTranscriptLines.value[targetIndex];
  if (line) {
    playSingleLine(line);
  }
}

function playNextSubtitle() {
  if (!playerTranscriptLines.value.length) {
    return;
  }
  const base =
    activePlayerSubtitleIndex.value >= 0 ? activePlayerSubtitleIndex.value : -1;
  const targetIndex = Math.min(
    playerTranscriptLines.value.length - 1,
    base + 1
  );
  const line = playerTranscriptLines.value[targetIndex];
  if (line) {
    playSingleLine(line);
  }
}

function togglePlayerPlayPause() {
  if (!englishPlayerInstance) {
    message.warning("播放器尚未准备好");
    return;
  }

  if (playerIsPlaying.value) {
    if (typeof englishPlayerInstance.pauseVideo === "function") {
      englishPlayerInstance.pauseVideo();
    }
    playerPlaybackTarget.value = null;
    return;
  }

  playSequentialFromCurrentPosition();
}

function handleSubtitleLineClick(line, index) {
  if (playerAbSelectionMode.value) {
    toggleAbCandidate(index);
    return;
  }

  playSingleLine(line);
}

async function mountEnglishPlayer(videoId) {
  if (!videoId) {
    return;
  }

  await nextTick();
  await loadYoutubeIframeApi();

  const playerRoot = document.getElementById("english-learning-player");
  if (!playerRoot) {
    return;
  }

  if (
    englishPlayerInstance &&
    typeof englishPlayerInstance.loadVideoById === "function"
  ) {
    englishPlayerInstance.loadVideoById({ videoId, startSeconds: 0 });
    playerCurrentTime.value = 0;
    playerIsPlaying.value = false;
    startEnglishPlayerTimer();
    return;
  }

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
        playerCurrentTime.value = 0;
        playerIsPlaying.value = false;
        startEnglishPlayerTimer();
      },
      onStateChange: (event) => {
        if (event.data === window.YT.PlayerState.PLAYING) {
          playerIsPlaying.value = true;
          startEnglishPlayerTimer();
          return;
        }

        if (
          event.data === window.YT.PlayerState.PAUSED ||
          event.data === window.YT.PlayerState.ENDED
        ) {
          playerIsPlaying.value = false;
        }
      },
    },
  });
}

async function parseAndLoadPlayerVideo(
  url,
  { preferredSubtitle = "" } = {}
) {
  const normalizedUrl = (url || "").trim();
  if (!normalizedUrl) {
    return;
  }

  playerMetaLoading.value = true;
  playerError.value = "";
  playerParsedYoutubeUrl.value = "";
  playerVideoId.value = "";
  playerVideoTitle.value = "";
  playerSubtitleOptions.value = [];
  playerSelectedSubtitle.value = "";
  playerTranscriptLines.value = [];
  playerCurrentTime.value = 0;
  playerPlaybackTarget.value = null;
  clearAbSelection();
  destroyEnglishPlayer();

  try {
    const response = await fetch("/api/youtube-subtitles", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        youtube_url: normalizedUrl,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    if (data.status !== "success") {
      playerError.value = "解析字幕失败: " + (data.message || "未知错误");
      return;
    }

    playerParsedYoutubeUrl.value = normalizedUrl;
    playerYoutubeUrl.value = normalizedUrl;
    playerVideoId.value = data.video_id || "";
    playerVideoTitle.value = data.video_title || "";
    playerSubtitleOptions.value = data.subtitles || [];

    if (!playerSubtitleOptions.value.length) {
      playerError.value = "未找到英文人工字幕";
      return;
    }

    const matchedSubtitle = playerSubtitleOptions.value.find(
      (item) => item.language_code === preferredSubtitle
    );
    playerSelectedSubtitle.value = matchedSubtitle
      ? matchedSubtitle.language_code
      : playerSubtitleOptions.value[0].language_code;
    await loadPlayerTranscript();

    upsertPlayerHistory({
      url: normalizedUrl,
      videoId: playerVideoId.value,
      title: playerVideoTitle.value,
      subtitleCode: playerSelectedSubtitle.value,
    });
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerError.value = "请求失败: " + errorMsg;
    console.error("解析播放器字幕失败:", err);
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
  playerPlaybackTarget.value = null;
  clearAbSelection();

  try {
    const response = await fetch("/api/youtube-transcript-lines", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        youtube_url: playerYoutubeUrl.value.trim(),
        language_code: playerSelectedSubtitle.value,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    if (data.status !== "success") {
      playerError.value = "加载字幕失败: " + (data.message || "未知错误");
      return;
    }

    playerVideoId.value = data.video_id || playerVideoId.value;
    playerVideoTitle.value = data.video_title || playerVideoTitle.value;
    playerTranscriptLines.value = data.lines || [];

    await mountEnglishPlayer(playerVideoId.value);

    upsertPlayerHistory({
      url: playerYoutubeUrl.value.trim(),
      videoId: playerVideoId.value,
      title: playerVideoTitle.value,
      subtitleCode: playerSelectedSubtitle.value,
    });
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerError.value = "请求失败: " + errorMsg;
    console.error("加载字幕时间轴失败:", err);
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
  youtubeSubtitles.value = playerSubtitleOptions.value.slice();
  selectedYoutubeSubtitle.value = playerSelectedSubtitle.value;
  openTedPage();
  await nextTick();
  await analyzeTedFile();
}

function hasUnknownWordsInLine(index) {
  return playerUnknownLineIndices.value.has(index);
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderSubtitleTextWithUnknownWords(text) {
  const escapedText = escapeHtml(text);
  const unknownWords = playerUnknownWordsFromTedAnalysis.value;
  if (!unknownWords.size) {
    return escapedText;
  }

  return escapedText.replace(
    /\b([a-zA-Z]+(?:-[a-zA-Z]+)*)\b/g,
    (fullMatch, word) => {
      if (unknownWords.has(word.toLowerCase())) {
        return `<span class="player-unknown-word">${fullMatch}</span>`;
      }
      return fullMatch;
    }
  );
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

.player-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
  height: calc(100vh - 104px);
}

.player-toolbar {
  background: #fff;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.player-toolbar-title {
  font-size: 14px;
  color: #555;
  font-weight: 500;
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

.player-subtitle-controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}

.player-ab-hint {
  color: #666;
  font-size: 13px;
}

.player-subtitle-list {
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
  cursor: pointer;
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

.player-subtitle-item.unknown-line {
  border-color: #91caff;
  background: #f0f7ff;
}

.player-subtitle-time {
  color: #1890ff;
  font-size: 12px;
  font-weight: 700;
  padding-top: 2px;
}

.player-subtitle-text {
  color: #262626;
  font-size: 15px;
  line-height: 1.5;
}

:deep(.player-unknown-word) {
  background: #cfe3ff;
  color: #0f4c9c;
  border-radius: 4px;
  padding: 0 4px;
  margin: 0 1px;
  font-weight: 600;
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

  .player-subtitle-controls {
    width: 100%;
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
    grid-template-columns: 1fr;
  }

  .home-history-item {
    flex-direction: column;
    align-items: flex-start;
  }

  .home-history-actions {
    width: 100%;
    justify-content: flex-end;
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
  display: grid;
  grid-template-columns: 1fr 140px;
  gap: 10px;
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

.home-history-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.home-history-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  padding: 12px;
}

.home-history-main {
  min-width: 0;
}

.home-history-title {
  font-size: 15px;
  font-weight: 600;
  color: #222;
}

.home-history-url {
  margin-top: 4px;
  color: #888;
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: min(680px, 100%);
}

.home-history-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.home-extension-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  justify-content: flex-end;
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
