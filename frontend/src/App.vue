<template>
  <a-config-provider :locale="locale">
    <div id="app">
      <a-layout class="layout">
        <a-layout-header class="header">
          <button class="header-home-btn" title="Home" @click="goHome">
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
                Player
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'ted' && !showStatsPage }"
                @click="goTedAnalysisPage"
              >
                Vocabulary
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'ted' && showStatsPage }"
                @click="goTedStatsPage"
              >
                Statistics
              </button>
              <button
                class="header-nav-item"
                :class="{ active: currentPage === 'settings' }"
                @click="goSettingsPage"
              >
                Settings
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
              <div class="home-entry-title">
                <h2>Import Local Material</h2>
                <p>
                  Upload a local video and English subtitles to cache them in this browser,
                  or upload subtitles only to judge difficulty before importing the video.
                </p>
                <div class="home-build-meta">
                  Current build: {{ appBuildTimeLabel }}
                </div>
              </div>
              <div class="home-entry-row">
                <a-input
                  class="home-link-input"
                  v-model:value="homeMaterialTitle"
                  placeholder="Optional material title"
                  :disabled="homeParseLoading"
                />
                <a-button
                  :disabled="homeParseLoading"
                  @click="triggerHomeVideoUpload"
                >
                  Upload Video
                </a-button>
                <span
                  class="home-upload-status"
                  :class="{ ready: !!homeVideoFileName }"
                >
                  {{ homeVideoFileName || "No video uploaded" }}
                </span>
                <a-button
                  :disabled="homeParseLoading || homeAnalyzeLoading"
                  @click="triggerHomeSubtitleUpload"
                >
                  Upload Subtitles
                </a-button>
                <span
                  class="home-upload-status"
                  :class="{ ready: !!homeSubtitleFileName }"
                >
                  {{ homeSubtitleFileName || "No subtitles uploaded" }}
                </span>
                <input
                  ref="homeVideoInputRef"
                  type="file"
                  accept="video/*"
                  style="display: none"
                  :disabled="homeParseLoading"
                  @change="handleHomeVideoFileChange"
                />
                <input
                  ref="homeSubtitleInputRef"
                  type="file"
                  :accept="homeSubtitleAccept"
                  style="display: none"
                  :disabled="homeParseLoading || homeAnalyzeLoading"
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
              <div class="home-entry-next">
                <a-button
                  type="primary"
                  :loading="homeParseLoading"
                  :disabled="!homeCanImportMaterial"
                  @click="importHomeMaterial"
                >
                  Import & Learn
                </a-button>
                <a-button
                  :loading="homeAnalyzeLoading"
                  :disabled="!homeCanAnalyzeSubtitleOnly"
                  @click="analyzeHomeSubtitleOnly"
                >
                  Analyze Subtitle Only
                </a-button>
              </div>
              <div v-if="homeResolvedTitle" class="home-entry-video-title">
                Ready title: {{ homeResolvedTitle }}
              </div>
            </div>

            <div v-if="playerHistoryVideos.length > 0" class="home-history-card">
              <div class="home-history-header">
                <div class="section-header">
                  <h2>Local Library</h2>
                  <p v-if="homeHistorySelectionMode">
                    {{ homeSelectedHistoryIds.length }} selected
                  </p>
                  <p v-else>Click a card to reopen a cached material</p>
                </div>
                <div class="home-history-toolbar">
                  <a-button size="small" @click="toggleHomeHistorySelectionMode">
                    {{ homeHistorySelectionMode ? "Cancel" : "Select" }}
                  </a-button>
                  <a-button
                    v-if="homeHistorySelectionMode"
                    size="small"
                    danger
                    :disabled="homeSelectedHistoryIds.length === 0"
                    @click="removeSelectedHistoryVideos"
                  >
                    Delete Selected
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
                    {{ isHomeHistorySelected(item.id) ? "Selected" : "Click to select" }}
                  </div>
                  <div
                    class="home-history-thumb"
                    :class="{ placeholder: true }"
                  >
                    <span>{{ item.hasVideo ? "Local video cached" : "Subtitle only" }}</span>
                  </div>
                  <div class="home-history-title">
                    {{ getHistoryDisplayTitle(item) }}
                  </div>
                  <div class="home-history-url">
                    {{ item.videoFileName || item.subtitleFileName || item.url }}
                  </div>
                  <div class="home-history-meta">
                    {{ (item.subtitleLines || []).length }} subtitle lines
                    ·
                    {{ item.videoFileName ? "video cached" : "subtitle only" }}
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- ========== 系统设置 ========== -->
          <div v-if="currentPage === 'settings'" class="settings-page">
            <div class="settings-card">
              <div class="section-header">
                <h2>Settings</h2>
                <p>Manage your word list and learning data.</p>
              </div>
              <div class="settings-actions">
                <a-button type="primary" @click="triggerImportLearningData">
                  Import Learning Data
                </a-button>
                <a-button @click="exportLearningData">
                  Export Learning Data
                </a-button>
                <a-button @click="triggerWordLabelsUpload">
                  Import Word List
                </a-button>
                <span class="settings-meta">
                  Word list size: {{ wordLabelsCount }}
                </span>
                <span class="settings-meta">
                  Word list version: {{ wordLabelsVersion || "Not uploaded" }}
                </span>
                <span class="settings-meta">
                  Learning data version: {{ learningDataVersion || "Not uploaded" }}
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
                <h2>Learning Statistics</h2>
                <a-radio-group
                  v-model:value="statsGranularity"
                  @change="loadStatsData"
                  button-style="solid"
                >
                  <a-radio-button value="day">Daily</a-radio-button>
                  <a-radio-button value="month">Monthly</a-radio-button>
                </a-radio-group>
              </div>
              <div class="stats-charts-container">
                <div class="stats-chart-item">
                  <h3>Cumulative Mastered Words</h3>
                  <div
                    ref="cumulativeChartContainer"
                    style="width: 100%; height: 400px;"
                  ></div>
                </div>
                <div class="stats-chart-item">
                  <h3>New Words per Day</h3>
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
                <h2>Word List</h2>
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
                        title="Mark all words on this page as mastered"
                        @click="markTedCurrentPageMastered"
                        style="padding: 0; height: auto; font-size: 16px"
                      >
                        <CheckCircleOutlined style="color: #52c41a; font-size: 18px;" />
                      </a-button>
                      <span>Word</span>
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
                        title="Mark as mastered"
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
                        title="Remove mastered mark"
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
                        tag === WORD_TAG_TOP_3000
                          ? 'green'
                          : tag === WORD_TAG_TOP_5000
                          ? 'blue'
                          : tag === WORD_TAG_TOP_10000
                          ? 'orange'
                          : tag === WORD_TAG_10000_PLUS
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
                <h2>Analysis & Stats</h2>
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
                      <h2>Global Learning Progress</h2>
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
                          <span class="progress-label">{{ formatWordLevelLabel(label) }}</span>
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
                    <h2>Overview</h2>
                  </div>
                  <div class="overview-content">
                    <div class="overview-item">
                      <div class="overview-label">Unique Words</div>
                      <div class="overview-value">{{ tedResults.length }}</div>
                    </div>
                    <div class="overview-item">
                      <div class="overview-label">Mastered</div>
                      <div class="overview-value mastered-count">
                        {{ tedResults.filter(item => item.mastered).length }}
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common3000.total > 0">
                      <div class="overview-label">Top 3000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common3000.unmastered }}</span>
                        <span class="value-detail"
                          >(total <span class="value-total">{{ tedTagCounts.common3000.total }}</span
                          >, mastered <span class="value-mastered">{{ tedTagCounts.common3000.mastered }}</span>)</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common5000.total > 0">
                      <div class="overview-label">Top 5000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common5000.unmastered }}</span>
                        <span class="value-detail"
                          >(total <span class="value-total">{{ tedTagCounts.common5000.total }}</span
                          >, mastered <span class="value-mastered">{{ tedTagCounts.common5000.mastered }}</span>)</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common10000.total > 0">
                      <div class="overview-label">Top 10000</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common10000.unmastered }}</span>
                        <span class="value-detail"
                          >(total <span class="value-total">{{ tedTagCounts.common10000.total }}</span
                          >, mastered <span class="value-mastered">{{ tedTagCounts.common10000.mastered }}</span>)</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.common10000Plus.total > 0">
                      <div class="overview-label">10000+</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.common10000Plus.unmastered }}</span>
                        <span class="value-detail"
                          >(total <span class="value-total">{{ tedTagCounts.common10000Plus.total }}</span
                          >, mastered <span class="value-mastered">{{ tedTagCounts.common10000Plus.mastered }}</span>)</span
                        >
                      </div>
                    </div>
                    <div class="overview-item" v-if="tedTagCounts.nonCommon.total > 0">
                      <div class="overview-label">Off-list</div>
                      <div class="overview-value">
                        <span class="value-unmastered">{{ tedTagCounts.nonCommon.unmastered }}</span>
                        <span class="value-detail"
                          >(total <span class="value-total">{{ tedTagCounts.nonCommon.total }}</span
                          >, mastered <span class="value-mastered">{{ tedTagCounts.nonCommon.mastered }}</span>)</span
                        >
                      </div>
                    </div>
                    <div
                      v-for="metric in tedDifficultyAssessment?.metrics || []"
                      :key="`overview-metric-${metric.label}`"
                      class="overview-item"
                    >
                      <div class="overview-label overview-label-with-help">
                        <span>{{ metric.label }}</span>
                        <a-popover trigger="click" placement="top">
                          <template #content>
                            <div class="difficulty-metric-help-popover">
                              {{ metric.hint }}
                            </div>
                          </template>
                          <button
                            type="button"
                            class="difficulty-metric-help-btn"
                            :aria-label="`Explain ${metric.label}`"
                          >
                            ?
                          </button>
                        </a-popover>
                      </div>
                      <div class="overview-value">
                        {{ metric.value }}{{ metric.suffix || "" }}
                      </div>
                    </div>
                  </div>
                </div>

                <div class="difficulty-section" v-if="tedDifficultyAssessment">
                  <div class="section-header">
                    <h2>Difficulty Assessment</h2>
                    <p>Based on {{ tedDifficultyAssessment.sampleLabel }}, combining material-level and personal difficulty.</p>
                  </div>

                  <div class="difficulty-summary-grid">
                    <div class="difficulty-summary-card">
                      <div class="difficulty-card-header">
                        <span class="difficulty-card-label">Objective Difficulty</span>
                        <span :class="getDifficultyBadgeClass(tedDifficultyAssessment.objective.levelKey)">
                          {{ tedDifficultyAssessment.objective.label }}
                        </span>
                      </div>
                      <div class="difficulty-card-score-row">
                        <div class="difficulty-card-score">
                          {{ tedDifficultyAssessment.objective.score }}%
                        </div>
                        <div class="difficulty-card-score-caption">
                          中间 = 中等难度
                        </div>
                      </div>
                      <div class="difficulty-bar-block">
                        <div class="difficulty-bar difficulty-bar-neutral">
                          <div class="difficulty-bar-center-line"></div>
                          <div
                            class="difficulty-bar-marker"
                            :style="getDifficultyBarMarkerStyle(tedDifficultyAssessment.objective.score)"
                          ></div>
                        </div>
                        <div class="difficulty-bar-scale">
                          <span>容易</span>
                          <span>中等</span>
                          <span>很难</span>
                        </div>
                      </div>
                      <div class="difficulty-card-desc">
                        {{ tedDifficultyAssessment.objective.description }}
                      </div>
                    </div>

                    <div class="difficulty-summary-card">
                      <div class="difficulty-card-header">
                        <span class="difficulty-card-label">Difficulty for Me</span>
                        <span :class="getDifficultyBadgeClass(tedDifficultyAssessment.personal.levelKey)">
                          {{ tedDifficultyAssessment.personal.label }}
                        </span>
                      </div>
                      <div class="difficulty-card-score-row">
                        <div class="difficulty-card-score">
                          {{ tedDifficultyAssessment.personal.score }}%
                        </div>
                        <div class="difficulty-card-score-caption">
                          中间 = 对你来说中等
                        </div>
                      </div>
                      <div class="difficulty-bar-block">
                        <div class="difficulty-bar difficulty-bar-neutral">
                          <div class="difficulty-bar-center-line"></div>
                          <div
                            class="difficulty-bar-marker"
                            :style="getDifficultyBarMarkerStyle(tedDifficultyAssessment.personal.score)"
                          ></div>
                        </div>
                        <div class="difficulty-bar-scale">
                          <span>不难</span>
                          <span>中等</span>
                          <span>很吃力</span>
                        </div>
                      </div>
                      <div class="difficulty-card-desc">
                        {{ tedDifficultyAssessment.personal.description }}
                      </div>
                    </div>

                    <div class="difficulty-summary-card difficulty-summary-card-fit">
                      <div class="difficulty-card-header">
                        <span class="difficulty-card-label">i+1 Fit</span>
                        <span :class="getDifficultyBadgeClass(tedDifficultyAssessment.fit.key)">
                          {{ tedDifficultyAssessment.fit.label }}
                        </span>
                      </div>
                      <div class="difficulty-card-score-row">
                        <div class="difficulty-fit-value">
                          {{ tedDifficultyAssessment.fit.levelText }}
                        </div>
                        <div class="difficulty-card-score-caption">
                          正中 = 刚好 i+1
                        </div>
                      </div>
                      <div class="difficulty-bar-block">
                        <div class="difficulty-bar difficulty-bar-fit">
                          <div class="difficulty-bar-center-line"></div>
                          <div
                            class="difficulty-bar-marker difficulty-bar-marker-fit"
                            :style="getDifficultyBarMarkerStyle(tedDifficultyAssessment.fit.position)"
                          ></div>
                        </div>
                        <div class="difficulty-bar-scale">
                          <span>i / i-1</span>
                          <span>i+1</span>
                          <span>i+2+</span>
                        </div>
                      </div>
                      <div class="difficulty-card-desc">
                        {{ tedDifficultyAssessment.fit.description }}
                      </div>
                      <div class="difficulty-fit-subvalue">
                        {{ tedDifficultyAssessment.fit.secondaryValue }} ·
                        {{ tedDifficultyAssessment.fit.recommendation }}
                      </div>
                    </div>
                  </div>

                  <div class="difficulty-insight">
                    {{ tedDifficultyAssessment.summary }}
                  </div>
                </div>
              </div>
            </div>
          </div>
          </div>

          <!-- ========== 英语播放器页面 ========== -->
          <div v-show="currentPage === 'player'" class="player-page">
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
              <div ref="playerVideoPanelRef" class="player-video-panel">
                <div class="player-video-wrapper">
                  <video
                    v-if="playerHasVideo"
                    ref="playerVideoRef"
                    class="player-local-video"
                    preload="metadata"
                    playsinline
                  ></video>
                  <div v-else class="player-video-empty">
                    No cached local video for this material.
                  </div>
                </div>
                <div class="player-video-controls">
                  <div class="player-progress-row">
                    <span class="player-progress-time">
                      {{ formatPlayerClock(playerDisplayedTime) }}
                    </span>
                    <input
                      class="player-progress-slider"
                      type="range"
                      min="0"
                      :max="playerDuration || 0"
                      step="0.1"
                      :value="canSeekPlayback ? playerDisplayedTime : 0"
                      :disabled="!canSeekPlayback"
                      :style="{ '--player-progress-percent': `${playerProgressPercent}%` }"
                      aria-label="Playback progress"
                      @input="handlePlayerProgressInput"
                      @change="handlePlayerProgressCommit"
                    />
                    <span class="player-progress-time">
                      {{ formatPlayerClock(playerDuration) }}
                    </span>
                  </div>
                  <div class="player-video-main-controls">
                    <a-button
                      class="player-icon-btn player-icon-btn-edge"
                      title="Jump to Start"
                      @click="jumpToTranscriptStart"
                      :disabled="!canJumpSubtitle"
                    >
                      <template #icon>
                        <FastBackwardOutlined />
                      </template>
                    </a-button>
                    <a-button
                      class="player-icon-btn"
                      title="Previous Line"
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
                      :title="playerIsPlaying ? 'Pause' : 'Play'"
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
                      title="Next Line"
                      @click="playNextSubtitle"
                      :disabled="!canJumpSubtitle"
                    >
                      <template #icon>
                        <StepForwardOutlined />
                      </template>
                    </a-button>
                    <a-button
                      class="player-icon-btn player-icon-btn-edge"
                      title="Jump to End"
                      @click="jumpToTranscriptEnd"
                      :disabled="!canJumpSubtitle"
                    >
                      <template #icon>
                        <FastForwardOutlined />
                      </template>
                    </a-button>
                  </div>
                  <div class="player-video-rate-controls">
                    <a-button
                      v-for="rate in PLAYER_PLAYBACK_RATES"
                      :key="rate"
                      class="player-rate-btn"
                      :type="playerPlaybackRate === rate ? 'primary' : 'default'"
                      :disabled="!canControlPlayback || !isPlaybackRateAvailable(rate)"
                      @click="setPlayerPlaybackRate(rate)"
                    >
                      {{ formatPlaybackRateLabel(rate) }}
                    </a-button>
                  </div>
                  <div class="player-video-secondary-controls">
                    <a-button
                      class="player-secondary-btn"
                      :disabled="!playerHasVideo"
                      @click="togglePlayerFullscreen"
                    >
                      {{ playerIsFullscreen ? "Exit Fullscreen" : "Fullscreen" }}
                    </a-button>
                    <a-button
                      class="player-secondary-btn"
                      :type="playerAbSelectionMode || canPlayAbRange ? 'primary' : 'default'"
                      @click="handleAbControlClick"
                    >
                      {{ playerAbSelectionMode ? "Cancel AB" : canPlayAbRange ? "Clear AB" : "Set AB" }}
                    </a-button>
                    <a-button
                      class="player-secondary-btn"
                      :disabled="!canCopyAbRangeText"
                      @click="copyAbSubtitleRange"
                    >
                      Copy AB
                    </a-button>
                    <a-button
                      class="player-secondary-btn"
                      type="dashed"
                      :loading="tedLoading"
                      :disabled="!canAnalyzeCurrentPlayerSubtitle"
                      @click="analyzeCurrentSubtitleVocabulary"
                    >
                      Vocabulary
                    </a-button>
                  </div>
                  <span v-if="playerAbSelectionMode" class="player-ab-hint">
                    Select two subtitle lines as A / B. Then press Play to loop, or Copy AB to copy.
                  </span>
                  <span
                    v-else-if="canPlayAbRange"
                    class="player-ab-hint"
                  >
                    A {{ formatSubtitleTime(playerTranscriptLines[playerAbStartIndex]?.start) }}
                    · B {{ formatSubtitleTime(playerTranscriptLines[playerAbEndIndex]?.start) }}
                    · Press Play to loop, or Copy AB to copy
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
                  No subtitles loaded
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
                    :data-ab-marker="getAbMarkerLabel(idx)"
                    class="player-subtitle-item"
                    :class="{
                      active: idx === activePlayerSubtitleIndex,
                      'in-ab-range': isIndexInAbRange(idx),
                      'ab-select-mode': playerAbSelectionMode,
                      'ab-candidate': isAbCandidate(idx),
                      'ab-point-start': idx === playerAbStartIndex,
                      'ab-point-end': idx === playerAbEndIndex,
                    }"
                    :title="playerAbSelectionMode ? 'Select this subtitle line for AB playback' : undefined"
                    :tabindex="playerAbSelectionMode ? 0 : undefined"
                    @click="handleSubtitleItemClick(idx)"
                    @keydown.enter.prevent="handleSubtitleItemClick(idx)"
                    @keydown.space.prevent="handleSubtitleItemClick(idx)"
                  >
                    <div
                      class="player-subtitle-time"
                      role="button"
                      tabindex="0"
                      :title="playerAbSelectionMode ? 'Use this line for AB selection' : 'Play this subtitle line'"
                      @click.stop="handleSubtitleTimeClick(line, idx)"
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
      title="Set Up Word List and Learning Data"
      :closable="false"
      :keyboard="false"
      :mask-closable="false"
      :footer="null"
      width="640px"
    >
      <div class="setup-modal-body">
        <p class="setup-modal-desc">
          On first launch or when version info is missing, the app will try to load
          <code>word_labels.csv</code> from the current directory first. If that fails,
          import the word list and learning data manually.
        </p>

        <div class="setup-modal-item">
          <div class="setup-modal-item-title">1. Import word list (word_labels.csv)</div>
          <input
            type="file"
            accept=".csv"
            @change="handleSetupWordLabelsFileChange"
          />
          <div class="setup-modal-meta">
            Current word list version: {{ wordLabelsVersion || "Not uploaded" }}
          </div>
          <div class="setup-modal-meta">
            Selected this time: {{ setupWordLabelsFileName || "No file selected" }}
          </div>
        </div>

        <div class="setup-modal-item">
          <div class="setup-modal-item-title">
            2. Import learning data (mastered_words.csv)
          </div>
          <input
            type="file"
            accept=".csv"
            @change="handleSetupLearningDataFileChange"
          />
          <div class="setup-modal-meta">
            Current learning data version: {{ learningDataVersion || "Not uploaded" }}
          </div>
          <div class="setup-modal-meta">
            Selected this time: {{ setupLearningDataFileName || "No file selected" }}
          </div>
        </div>

        <div class="setup-modal-actions">
          <a-button
            type="primary"
            :disabled="!isDataSetupReady"
            @click="closeSetupModal"
          >
            Start
          </a-button>
        </div>
      </div>
    </a-modal>

    <!-- 未学习单词弹框 -->
    <a-modal
      v-model:open="unmasteredWordsModal.visible"
      :title="`${formatWordLevelLabel(unmasteredWordsModal.label)} - Unmastered Words`"
      width="900px"
      :footer="null"
      :loading="unmasteredWordsModal.loading"
    >
      <div v-if="unmasteredWordsModal.loading" style="text-align: center; padding: 40px">
        <a-spin size="large" />
      </div>
      <div v-else-if="unmasteredWordsModal.words.length === 0" style="text-align: center; padding: 40px; color: #999">
        No unmastered words
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
                  title="Already marked as mastered"
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
import enUS from "ant-design-vue/es/locale/en_US";
import {
  CheckCircleOutlined,
  CheckCircleFilled,
  CloseOutlined,
  HomeOutlined,
  FastBackwardOutlined,
  StepBackwardOutlined,
  StepForwardOutlined,
  FastForwardOutlined,
  CaretRightOutlined,
  PauseOutlined,
} from "@ant-design/icons-vue";
import { message, Modal } from "ant-design-vue";

const locale = enUS;
const APP_BUILD_TIME_ISO = __APP_BUILD_TIME__;

const PLAYER_HISTORY_STORAGE_KEY = "word_power_player_history_v2";
const MASTERED_WORDS_STORAGE_KEY = "word_power_mastered_words_v1";
const WORD_LABELS_STORAGE_KEY = "word_power_word_labels_map_v1";
const WORD_LABELS_VERSION_STORAGE_KEY = "word_power_word_labels_version_v1";
const LEARNING_DATA_VERSION_STORAGE_KEY = "word_power_learning_data_version_v1";
const LOCAL_VIDEO_DB_NAME = "word_power_local_media_v1";
const LOCAL_VIDEO_DB_VERSION = 1;
const LOCAL_VIDEO_STORE_NAME = "videos";
const LOCAL_MATERIAL_URL_PREFIX = "local-material:";
const FIXED_WORD_LABELS_FILE_NAME = "word_labels.csv";
const FIXED_MASTERED_WORDS_FILE_NAME = "mastered_words.csv";
const BASE_WORD_LABELS = ["3000", "5000", "10000"];
const FALLBACK_WORD_LABEL = "10000+";
const FALLBACK_WORD_TOTAL = 20000;
const WORD_TAG_TOP_3000 = "Top 3000";
const WORD_TAG_TOP_5000 = "Top 5000";
const WORD_TAG_TOP_10000 = "Top 10000";
const WORD_TAG_10000_PLUS = "10000+";
const WORD_TAG_OFF_LIST = "Off-list";
const PLAYER_TIMER_INTERVAL_MS = 80;
const SINGLE_LINE_STOP_BUFFER = 0.04;
const SINGLE_LINE_EARLY_PAUSE_SEC = 0.12;
const SINGLE_LINE_MIN_DURATION_SEC = 0.12;
const SINGLE_LINE_NEXT_GUARD_SEC = 0.01;
const DEFAULT_SUBTITLE_ACCEPT = ".srt,.vtt,.json";
const ENABLE_YOUTUBE_OEMBED_TITLE_FETCH = false;
const PLAYER_PLAYBACK_RATES = [0.5, 1, 1.25, 1.5, 2];

function isIOSLikeDevice() {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent || "";
  const platform = navigator.platform || "";
  const maxTouchPoints = Number(navigator.maxTouchPoints || 0);
  const isIOSUA = /iPad|iPhone|iPod/i.test(ua);
  const isIPadOSDesktopUA = platform === "MacIntel" && maxTouchPoints > 1;
  return isIOSUA || isIPadOSDesktopUA;
}

const homeSubtitleAccept = isIOSLikeDevice() ? "*/*" : DEFAULT_SUBTITLE_ACCEPT;

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
    message.info("Add and parse a video first.");
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

function reopenExistingPlayerPage() {
  playerError.value = "";
  showStatsPage.value = false;
  currentPage.value = "player";
}

function formatWordLevelLabel(label) {
  if (label === FALLBACK_WORD_LABEL) {
    return WORD_TAG_10000_PLUS;
  }
  return `Top ${label}`;
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
const homeMaterialTitle = ref("");
const homeParseLoading = ref(false);
const homeAnalyzeLoading = ref(false);
const homeError = ref("");
const homeVideoFile = ref(null);
const homeVideoFileName = ref("");
const homeVideoInputRef = ref(null);
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

const homeResolvedTitle = computed(() => {
  const manualTitle = normalizeSubtitleText(homeMaterialTitle.value || "");
  if (manualTitle) return manualTitle;
  const videoName = stripFileExtension(homeVideoFileName.value);
  if (videoName) return videoName;
  const subtitleName = stripFileExtension(homeSubtitleFileName.value);
  if (subtitleName) return subtitleName;
  return "";
});

const homeCanImportMaterial = computed(() => {
  return !!homeVideoFile.value && !!homeSubtitleFile.value;
});

const homeCanAnalyzeSubtitleOnly = computed(() => {
  return !!homeSubtitleFile.value;
});

const canOpenPlayerPage = computed(() => !!playerVideoId.value);
const appBuildTimeLabel = computed(() => formatBuildTimeUtc(APP_BUILD_TIME_ISO));

// ===== TED页面状态 =====
const tedColumns = [
  {
    title: "#",
    key: "index",
    width: 80,
    align: "left",
  },
  {
    title: "Word",
    dataIndex: "word",
    key: "word",
    width: 200,
    fixed: "left",
    align: "left",
  },
  {
    title: "Tag",
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
  showLessItems: true,
  responsive: true,
  size: "small",
  pageSizeOptions: ["10", "20", "50", "100"],
  showTotal: (total) => `${total} items`,
});

const tedCanAnalyze = computed(() => {
  return tedSubtitleLines.value.length > 0;
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
  const unmasteredResults = tedResults.value.filter((item) => !item.mastered);

  if (!tedSelectedTagFilter.value) {
    return unmasteredResults;
  }

  if (tedSelectedTagFilter.value === WORD_TAG_OFF_LIST) {
    return unmasteredResults.filter((item) => {
      return (
        !item.tags.includes(WORD_TAG_TOP_3000) &&
        !item.tags.includes(WORD_TAG_TOP_5000) &&
        !item.tags.includes(WORD_TAG_TOP_10000) &&
        !item.tags.includes(WORD_TAG_10000_PLUS)
      );
    });
  }

  return unmasteredResults.filter((item) =>
    item.tags.includes(tedSelectedTagFilter.value)
  );
});

function clampTedPaginationPage() {
  const pageSize = Math.max(1, Number(tedPagination.value.pageSize) || 20);
  const maxPage = Math.max(1, Math.ceil(tedFilteredResults.value.length / pageSize));
  const currentPage = Math.max(1, Number(tedPagination.value.current) || 1);

  if (currentPage > maxPage) {
    tedPagination.value.current = maxPage;
  }
}

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
      item.tags.includes(WORD_TAG_TOP_3000) ||
      item.tags.includes(WORD_TAG_TOP_5000) ||
      item.tags.includes(WORD_TAG_TOP_10000) ||
      item.tags.includes(WORD_TAG_10000_PLUS);

    if (item.tags.includes(WORD_TAG_TOP_3000)) {
      counts.common3000.total++;
      if (item.mastered) counts.common3000.mastered++;
      else counts.common3000.unmastered++;
    }
    if (item.tags.includes(WORD_TAG_TOP_5000)) {
      counts.common5000.total++;
      if (item.mastered) counts.common5000.mastered++;
      else counts.common5000.unmastered++;
    }
    if (item.tags.includes(WORD_TAG_TOP_10000)) {
      counts.common10000.total++;
      if (item.mastered) counts.common10000.mastered++;
      else counts.common10000.unmastered++;
    }
    if (item.tags.includes(WORD_TAG_10000_PLUS)) {
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

const tedDifficultyAssessment = computed(() => {
  if (!tedResults.value.length || !tedSubtitleLines.value.length) {
    return null;
  }

  return buildTranscriptDifficultyAssessment(tedSubtitleLines.value);
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
    showTotal: (value) => `${value} unmastered words`,
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
let playerVideoObjectUrl = "";
let playerVideoEventCleanup = null;
let playerCurrentVideoBlob = null;

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
const playerHasVideo = ref(false);
const playerTranscriptLines = ref([]);
const playerCurrentTime = ref(0);
const playerDuration = ref(0);
const playerSeekPreviewTime = ref(null);
const playerSubtitleListRef = ref(null);
const playerVideoPanelRef = ref(null);
const playerVideoRef = ref(null);
const playerAbStartIndex = ref(-1);
const playerAbEndIndex = ref(-1);
const playerAbSelectionMode = ref(false);
const playerAbSelectionCandidates = ref([]);
const playerIsPlaying = ref(false);
const playerPlaybackRate = ref(1);
const playerAvailablePlaybackRates = ref(PLAYER_PLAYBACK_RATES.slice());
const playerPlaybackTarget = ref(null);
const playerPinnedSubtitleIndex = ref(-1);
const playerIsFullscreen = ref(false);

const playerCanLoadTranscript = computed(() => {
  return (
    !!playerVideoId.value &&
    playerHasVideo.value &&
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
  return playerHasVideo.value && playerTranscriptLines.value.length > 0 && !playerTranscriptLoading.value;
});

const canJumpSubtitle = computed(() => {
  return playerHasVideo.value && playerTranscriptLines.value.length > 0 && !playerTranscriptLoading.value;
});

const canAnalyzeCurrentPlayerSubtitle = computed(() => {
  return !!playerParsedYoutubeUrl.value && playerTranscriptLines.value.length > 0;
});

const canSeekPlayback = computed(() => {
  return playerHasVideo.value && playerDuration.value > 0 && !playerTranscriptLoading.value;
});

const playerDisplayedTime = computed(() => {
  const sourceTime =
    playerSeekPreviewTime.value == null ? playerCurrentTime.value : playerSeekPreviewTime.value;
  return clampPlayerTime(sourceTime);
});

const playerProgressPercent = computed(() => {
  if (playerDuration.value <= 0) {
    return 0;
  }

  return Math.max(
    0,
    Math.min(100, (playerDisplayedTime.value / playerDuration.value) * 100)
  );
});

const PLAYER_SUBTITLE_SCROLL_TARGET_RATIO = 0.38;
const PLAYER_SUBTITLE_SCROLL_MIN_RATIO = 0.2;
const PLAYER_SUBTITLE_SCROLL_MAX_RATIO = 0.62;

const playerTranscriptHash = computed(() => {
  return computeTranscriptHash(playerTranscriptLines.value);
});

const playerUnknownWordsFromTedAnalysis = computed(() => {
  if (
    lastTedAnalysisMeta.value.source !== "local" ||
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
  playerHasVideo.value = false;
  playerCurrentVideoBlob = null;
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

watch(currentPage, async (newPage, oldPage) => {
  if (oldPage === "player" && newPage !== "player") {
    await exitPlayerFullscreen();
    playerPlaybackTarget.value = null;
    if (englishPlayerInstance && typeof englishPlayerInstance.pauseVideo === "function") {
      englishPlayerInstance.pauseVideo();
    }
    stopEnglishPlayerTimer();
  }

  if (
    newPage === "player" &&
    playerVideoId.value &&
    playerTranscriptLines.value.length > 0
  ) {
    try {
      if (hasPlayerApiMethods()) {
        startEnglishPlayerTimer();
      } else {
        await mountEnglishPlayer(playerVideoId.value);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      playerError.value = `Player initialization failed: ${errorMsg}`;
    }
  }
});

function keepActiveSubtitleInComfortZone(index) {
  const list = playerSubtitleListRef.value;
  if (!(list instanceof HTMLElement) || index < 0) {
    return;
  }

  const activeNode = list.querySelector(`[data-sub-index="${index}"]`);
  if (!(activeNode instanceof HTMLElement)) {
    return;
  }

  const listRect = list.getBoundingClientRect();
  const nodeRect = activeNode.getBoundingClientRect();
  const containerHeight = list.clientHeight;
  if (!containerHeight) {
    return;
  }

  const visibleTop = list.scrollTop;
  const relativeTop = nodeRect.top - listRect.top + visibleTop;
  const relativeBottom = nodeRect.bottom - listRect.top + visibleTop;
  const comfortTop = visibleTop + containerHeight * PLAYER_SUBTITLE_SCROLL_MIN_RATIO;
  const comfortBottom = visibleTop + containerHeight * PLAYER_SUBTITLE_SCROLL_MAX_RATIO;

  if (relativeTop >= comfortTop && relativeBottom <= comfortBottom) {
    return;
  }

  const maxScrollTop = Math.max(0, list.scrollHeight - containerHeight);
  const targetTop = Math.min(
    maxScrollTop,
    Math.max(0, relativeTop - containerHeight * PLAYER_SUBTITLE_SCROLL_TARGET_RATIO)
  );

  list.scrollTo({
    top: targetTop,
    behavior: "smooth",
  });
}

watch(activePlayerSubtitleIndex, (index, prev) => {
  if (index < 0 || index === prev || !playerSubtitleListRef.value) {
    return;
  }

  keepActiveSubtitleInComfortZone(index);
});

watch(
  [() => tedFilteredResults.value.length, () => tedPagination.value.pageSize],
  () => {
    clampTedPaginationPage();
  }
);

onMounted(async () => {
  loadMasteredWordsFromStorage();
  loadPlayerHistory();
  loadWordLabelsFromStorage();
  loadDataVersionsFromStorage();
  await tryLoadWordLabelsFromLocalIfNeeded();
  ensureSetupModalState();
  await loadLearningProgress();
  document.addEventListener("fullscreenchange", syncPlayerFullscreenState);
  document.addEventListener("webkitfullscreenchange", syncPlayerFullscreenState);
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
  document.removeEventListener("fullscreenchange", syncPlayerFullscreenState);
  document.removeEventListener("webkitfullscreenchange", syncPlayerFullscreenState);
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
    throw new Error("Missing YouTube URL.");
  }

  const idPattern = /^[A-Za-z0-9_-]{11}$/;
  if (idPattern.test(value)) {
    return value;
  }

  let parsed;
  try {
    parsed = new URL(value.startsWith("http") ? value : `https://${value}`);
  } catch {
    throw new Error("Invalid YouTube URL.");
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
    throw new Error("Invalid YouTube video URL.");
  }

  return videoId;
}

const GENERIC_YOUTUBE_TITLE_PATTERN = /^YouTube Video \([A-Za-z0-9_-]{11}\)$/;

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
    throw new Error("Failed to fetch video title.");
  }

  const data = await response.json();
  return normalizeSubtitleText(String(data?.title || ""));
}

function getHistoryVideoId(item) {
  return parseLocalMaterialId(item?.url || "") || String(item?.videoId || "").trim();
}

function getHistoryThumbnailUrl(item) {
  return "";
}

function getHistoryDisplayTitle(item) {
  const rawTitle = String(item?.title || "").trim();
  if (rawTitle) {
    return rawTitle;
  }

  return (
    stripFileExtension(item?.videoFileName || "") ||
    stripFileExtension(item?.subtitleFileName || "") ||
    "Local Material"
  );
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
    throw new Error("Invalid JSON subtitle format.");
  }

  const rawLines = Array.isArray(parsed) ? parsed : parsed?.lines;
  if (!Array.isArray(rawLines)) {
    throw new Error("JSON subtitle file is missing the lines array.");
  }

  return normalizeSubtitleLines(rawLines);
}

async function readFileAsText(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("Failed to read file."));
    reader.readAsText(file, "utf-8");
  });
}

async function parseSubtitleFile(file) {
  if (!file) {
    throw new Error("Choose a subtitle file first.");
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
    throw new Error("No valid subtitles were parsed. Check whether the file is SRT, VTT, or JSON.");
  }

  return lines;
}

function stripFileExtension(fileName) {
  return String(fileName || "").replace(/\.[^.]+$/, "").trim();
}

function buildLocalMaterialUrl(materialId) {
  const normalizedId = String(materialId || "").trim();
  return normalizedId ? `${LOCAL_MATERIAL_URL_PREFIX}${normalizedId}` : "";
}

function parseLocalMaterialId(materialUrl) {
  const value = String(materialUrl || "").trim();
  if (!value.startsWith(LOCAL_MATERIAL_URL_PREFIX)) {
    return "";
  }
  return value.slice(LOCAL_MATERIAL_URL_PREFIX.length).trim();
}

function deriveLocalMaterialTitle({ title, videoFileName, subtitleFileName }) {
  const manualTitle = normalizeSubtitleText(title || "");
  if (manualTitle) return manualTitle;

  const videoTitle = stripFileExtension(videoFileName);
  if (videoTitle) return videoTitle;

  const subtitleTitle = stripFileExtension(subtitleFileName);
  if (subtitleTitle) return subtitleTitle;

  return "Local Material";
}

function openLocalVideoDb() {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === "undefined") {
      reject(new Error("IndexedDB is not available in this browser."));
      return;
    }

    const request = indexedDB.open(LOCAL_VIDEO_DB_NAME, LOCAL_VIDEO_DB_VERSION);
    request.onerror = () => {
      reject(request.error || new Error("Failed to open the local media cache."));
    };
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(LOCAL_VIDEO_STORE_NAME)) {
        db.createObjectStore(LOCAL_VIDEO_STORE_NAME, { keyPath: "id" });
      }
    };
    request.onsuccess = () => {
      resolve(request.result);
    };
  });
}

async function saveLocalVideoBlob(materialId, blob) {
  if (!materialId || !(blob instanceof Blob)) {
    throw new Error("Missing local video data.");
  }

  const db = await openLocalVideoDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(LOCAL_VIDEO_STORE_NAME, "readwrite");
    const store = tx.objectStore(LOCAL_VIDEO_STORE_NAME);
    const request = store.put({
      id: materialId,
      blob,
      updatedAt: Date.now(),
    });
    request.onerror = () => {
      reject(request.error || new Error("Failed to cache the local video."));
    };
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => {
      reject(tx.error || new Error("Failed to cache the local video."));
    };
  });
}

async function loadLocalVideoBlob(materialId) {
  if (!materialId) return null;

  const db = await openLocalVideoDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(LOCAL_VIDEO_STORE_NAME, "readonly");
    const store = tx.objectStore(LOCAL_VIDEO_STORE_NAME);
    const request = store.get(materialId);
    request.onerror = () => {
      reject(request.error || new Error("Failed to load the cached video."));
    };
    request.onsuccess = () => {
      db.close();
      const result = request.result;
      resolve(result?.blob instanceof Blob ? result.blob : null);
    };
  });
}

async function deleteLocalVideoBlob(materialId) {
  if (!materialId) return;

  const db = await openLocalVideoDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(LOCAL_VIDEO_STORE_NAME, "readwrite");
    const store = tx.objectStore(LOCAL_VIDEO_STORE_NAME);
    const request = store.delete(materialId);
    request.onerror = () => {
      reject(request.error || new Error("Failed to delete the cached video."));
    };
    tx.oncomplete = () => {
      db.close();
      resolve();
    };
    tx.onerror = () => {
      reject(tx.error || new Error("Failed to delete the cached video."));
    };
  });
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
        console.warn("Failed to parse one history entry. Skipped.", err);
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
    console.warn("Failed to load word list:", err);
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
    console.warn("Failed to load local word list:", err);
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
    console.warn("Failed to load mastered words:", err);
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
  if (label === "3000") return [WORD_TAG_TOP_3000];
  if (label === "5000") return [WORD_TAG_TOP_5000];
  if (label === "10000") return [WORD_TAG_TOP_10000];
  return [WORD_TAG_10000_PLUS];
}

function buildNormalizedTranscriptLemmaLines(lines) {
  const transcriptWordSet = new Set();
  const extractedLines = lines.map((line) => {
    const words = extractWordsFromText(line.text || "");
    words.forEach((word) => transcriptWordSet.add(word));
    return words;
  });

  return extractedLines.map((words) =>
    words
      .map((rawWord) => simpleLemmatize(rawWord, transcriptWordSet))
      .filter(Boolean)
  );
}

function clampNumber(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function roundMetric(value, digits = 1) {
  const normalized = Number(value || 0);
  if (!Number.isFinite(normalized)) {
    return 0;
  }
  return Number(normalized.toFixed(digits));
}

function formatMetricPercent(value, digits = 1) {
  return `${roundMetric(value, digits)}%`;
}

function normalizeScore(value, min, max) {
  if (max <= min) {
    return 0;
  }
  return clampNumber(((value - min) / (max - min)) * 100, 0, 100);
}

function describeDifficultyLevel(score) {
  if (score < 25) return { key: "easy", label: "Easy" };
  if (score < 50) return { key: "medium", label: "Moderate" };
  if (score < 75) return { key: "hard", label: "Hard" };
  return { key: "very-hard", label: "Very Hard" };
}

function getDifficultyBadgeClass(levelKey) {
  return `difficulty-badge difficulty-badge-${levelKey}`;
}

function getDifficultyBarMarkerStyle(score) {
  return {
    left: `${clampNumber(Number(score) || 0, 0, 100)}%`,
  };
}

function buildObjectiveDifficultyDescription({
  uniquePerThousand,
  offListUniqueRatioPct,
  avgLineLength,
  longLineRatioPct,
}) {
  const reasons = [];

  if (uniquePerThousand >= 320) reasons.push("fast-changing vocabulary");
  if (offListUniqueRatioPct >= 15) reasons.push("many off-list words");
  if (avgLineLength >= 9) reasons.push("longer sentences");
  if (longLineRatioPct >= 35) reasons.push("many longer subtitle lines");

  if (!reasons.length) {
    return "Vocabulary density and sentence length are both fairly steady.";
  }

  return `${reasons.join(", ")}.`;
}

function buildPersonalDifficultyDescription({
  unknownWordsPerMinute,
  cleanLineRatioPct,
  linesWithUnknownRatioPct,
  longLinesWithUnknownRatioPct,
}) {
  if (unknownWordsPerMinute <= 2 && cleanLineRatioPct >= 70) {
    return "Most lines are clean for shadowing, so this behaves more like review than growth input.";
  }
  if (
    unknownWordsPerMinute <= 5 &&
    linesWithUnknownRatioPct <= 40 &&
    longLinesWithUnknownRatioPct <= 18
  ) {
    return "The pressure is present but controlled, which matches chunk-based shadowing fairly well.";
  }
  if (
    unknownWordsPerMinute <= 7 &&
    linesWithUnknownRatioPct <= 60 &&
    longLinesWithUnknownRatioPct <= 30
  ) {
    return "You can still work with it, but many lines will require pausing, splitting, or replaying.";
  }
  if (linesWithUnknownRatioPct >= 70) {
    return "Most lines contain at least one unknown word, so it is not clean enough for comfortable shadowing.";
  }
  return "The line-by-line pressure is high for chunk accumulation, so previewing or pre-learning words will help.";
}

function buildIPlusOneAssessment({
  unknownWordsPerMinute,
  cleanLineRatioPct,
  linesWithUnknownRatioPct,
  longLinesWithUnknownRatioPct,
}) {
  const idealUnknownWordsPerMinute = 4;
  const fitPosition = clampNumber(
    50 +
      (unknownWordsPerMinute - idealUnknownWordsPerMinute) * 10 +
      (linesWithUnknownRatioPct - 35) * 0.55 +
      (longLinesWithUnknownRatioPct - 12) * 0.45 -
      Math.max(0, cleanLineRatioPct - 55) * 0.35,
    0,
    100
  );

  const levelOffset = roundMetric((fitPosition - 50) / 25, 1);
  const estimatedLevel = roundMetric(1 + levelOffset, 1);
  const levelText =
    estimatedLevel <= -0.5
      ? "i-1"
      : estimatedLevel <= 0.4
      ? "i"
      : estimatedLevel < 1.6
      ? "i+1"
      : estimatedLevel < 2.6
      ? "i+2"
      : "i+3+";

  if (
    unknownWordsPerMinute < 2 &&
    cleanLineRatioPct >= 70 &&
    longLinesWithUnknownRatioPct <= 10
  ) {
    return {
      key: "easy",
      label: "Too Easy",
      position: fitPosition,
      levelText,
      description: "There are too few new words per minute, and too many clean lines for this to act as strong growth input.",
      recommendation: "Use it for smooth shadowing or switch to slightly less familiar material.",
    };
  }

  if (
    unknownWordsPerMinute >= 3 &&
    unknownWordsPerMinute <= 5 &&
    linesWithUnknownRatioPct <= 40 &&
    longLinesWithUnknownRatioPct <= 18
  ) {
    return {
      key: "ideal",
      label: "Near i+1",
      position: fitPosition,
      levelText,
      description: "This sits close to your preferred shadowing zone: a few new words per minute without overwhelming most lines.",
      recommendation: "Good for semantic chunking, shadowing, and repeated exposure.",
    };
  }

  if (
    unknownWordsPerMinute <= 7 &&
    linesWithUnknownRatioPct <= 60 &&
    longLinesWithUnknownRatioPct <= 30
  ) {
    return {
      key: "stretch",
      label: "Stretch",
      position: fitPosition,
      levelText,
      description: "It is still workable, but enough lines contain unknown words that shadowing flow will break often.",
      recommendation: "Use shorter chunks or pre-learn the key unknown words first.",
    };
  }

  return {
    key: "very-hard",
    label: "Too Hard",
    position: fitPosition,
    levelText,
    description: "Too many lines are contaminated by unknown words, so it is inefficient for chunk-based shadowing right now.",
    recommendation: "Preview the unknown vocabulary first, or switch to cleaner material.",
  };
}

function buildDifficultyNarrative({ objective, personal, fit }) {
  const objectiveHard = objective.score >= 60;
  const objectiveEasy = objective.score <= 35;
  const personalHard = personal.score >= 60;
  const personalEasy = personal.score <= 35;

  if (objectiveHard && personalEasy) {
    return "The material is objectively difficult, but your coverage is already high, so it behaves like familiar content for you.";
  }
  if (objectiveEasy && personalHard) {
    return "The material is not objectively very hard, but it is still hard for you, which suggests an unfamiliar domain.";
  }
  if (objectiveHard && personalHard) {
    return "The material itself is lexically and structurally heavy, and it is also demanding for you. Break it into smaller chunks.";
  }
  if (objectiveEasy && personalEasy) {
    return "This is easy both objectively and personally, so it is better for review, extensive listening, or fluency work.";
  }
  return fit.description;
}

function buildTranscriptDifficultyAssessment(lines) {
  const normalizedLineWords = buildNormalizedTranscriptLemmaLines(lines);
  const masteredSet = new Set(Object.keys(masteredWords.value));
  const labelUniqueSets = {
    "3000": new Set(),
    "5000": new Set(),
    "10000": new Set(),
    "10000+": new Set(),
  };

  const uniqueWords = new Set();
  let totalTokens = 0;
  let knownTokens = 0;
  let unknownTokens = 0;
  let sentenceCount = 0;
  let linesWithUnknown = 0;
  let cleanLines = 0;
  let longLines = 0;
  let longLinesWithUnknown = 0;

  normalizedLineWords.forEach((words) => {
    if (!words.length) {
      return;
    }

    sentenceCount++;
    let lineUnknownCount = 0;
    const isLongLine = words.length >= 9;
    if (isLongLine) {
      longLines++;
    }

    words.forEach((word) => {
      totalTokens++;
      uniqueWords.add(word);
      labelUniqueSets[getWordLabel(word)].add(word);

      if (masteredSet.has(word)) {
        knownTokens++;
      } else {
        unknownTokens++;
        lineUnknownCount++;
      }
    });

    if (lineUnknownCount > 0) {
      linesWithUnknown++;
      if (isLongLine) {
        longLinesWithUnknown++;
      }
    } else {
      cleanLines++;
    }
  });

  const uniqueCount = uniqueWords.size;
  if (!totalTokens || !uniqueCount || !sentenceCount) {
    return null;
  }

  const unknownUniqueCount = Array.from(uniqueWords).filter((word) => !masteredSet.has(word)).length;
  const uniquePerThousand = (uniqueCount / totalTokens) * 1000;
  const avgLineLength = totalTokens / sentenceCount;
  const offListUniqueRatio = labelUniqueSets["10000+"].size / uniqueCount;
  const knownCoverage = knownTokens / totalTokens;
  const unknownTokenRatio = unknownTokens / totalTokens;
  const unknownUniqueRatio = unknownUniqueCount / uniqueCount;
  const linesWithUnknownRatio = linesWithUnknown / sentenceCount;
  const cleanLineRatio = cleanLines / sentenceCount;
  const longLineRatio = longLines / sentenceCount;
  const longLinesWithUnknownRatio = longLinesWithUnknown / sentenceCount;
  const durationSeconds = Math.max(
    1,
    Number(lines[lines.length - 1]?.end || 0) - Number(lines[0]?.start || 0)
  );
  const durationMinutes = durationSeconds / 60;
  const unknownWordsPerMinute = unknownTokens / durationMinutes;

  const uniquePerThousandScore = normalizeScore(uniquePerThousand, 180, 360);
  const offListRatioScore = normalizeScore(offListUniqueRatio * 100, 2, 22);
  const sentenceLengthScore = normalizeScore(avgLineLength, 4.5, 12);
  const longLineRatioScore = normalizeScore(longLineRatio * 100, 15, 55);
  const objectiveScore = roundMetric(
    uniquePerThousandScore * 0.35 +
      offListRatioScore * 0.25 +
      sentenceLengthScore * 0.2 +
      longLineRatioScore * 0.2,
    0
  );

  const unknownUniqueScore = normalizeScore(unknownUniqueRatio * 100, 5, 45);
  const linesWithUnknownScore = normalizeScore(linesWithUnknownRatio * 100, 15, 70);
  const longLinesWithUnknownScore = normalizeScore(longLinesWithUnknownRatio * 100, 5, 35);
  const unknownWordsPerMinuteScore = normalizeScore(unknownWordsPerMinute, 2, 8);
  const personalScore = roundMetric(
    linesWithUnknownScore * 0.4 +
      unknownWordsPerMinuteScore * 0.35 +
      longLinesWithUnknownScore * 0.15 +
      unknownUniqueScore * 0.1,
    0
  );

  const objectiveLevel = describeDifficultyLevel(objectiveScore);
  const personalLevel = describeDifficultyLevel(personalScore);

  const knownCoveragePct = roundMetric(knownCoverage * 100, 1);
  const unknownTokenRatioPct = roundMetric(unknownTokenRatio * 100, 1);
  const unknownUniqueRatioPct = roundMetric(unknownUniqueRatio * 100, 1);
  const linesWithUnknownRatioPct = roundMetric(linesWithUnknownRatio * 100, 1);
  const cleanLineRatioPct = roundMetric(cleanLineRatio * 100, 1);
  const longLineRatioPct = roundMetric(longLineRatio * 100, 1);
  const longLinesWithUnknownRatioPct = roundMetric(longLinesWithUnknownRatio * 100, 1);
  const offListUniqueRatioPct = roundMetric(offListUniqueRatio * 100, 1);
  const unknownWordsPerMinuteRounded = roundMetric(unknownWordsPerMinute, 1);
  const durationMinutesRounded = roundMetric(durationMinutes, 1);

  const objective = {
    score: objectiveScore,
    label: objectiveLevel.label,
    levelKey: objectiveLevel.key,
    description: buildObjectiveDifficultyDescription({
      uniquePerThousand: roundMetric(uniquePerThousand, 1),
      offListUniqueRatioPct,
      avgLineLength: roundMetric(avgLineLength, 1),
      longLineRatioPct,
    }),
    metrics: [],
  };

  const personal = {
    score: personalScore,
    label: personalLevel.label,
    levelKey: personalLevel.key,
    description: buildPersonalDifficultyDescription({
      unknownWordsPerMinute: unknownWordsPerMinuteRounded,
      cleanLineRatioPct,
      linesWithUnknownRatioPct,
      longLinesWithUnknownRatioPct,
    }),
    metrics: [],
  };

  const fit = buildIPlusOneAssessment({
    unknownWordsPerMinute: unknownWordsPerMinuteRounded,
    cleanLineRatioPct,
    linesWithUnknownRatioPct,
    longLinesWithUnknownRatioPct,
  });

  return {
    sampleLabel: `${sentenceCount} lines · ${totalTokens} tokens · ${durationMinutesRounded} min`,
    summary: buildDifficultyNarrative({ objective, personal, fit }),
    objective,
    personal,
    metrics: [
      {
        label: "Unknown Words / Minute",
        value: unknownWordsPerMinuteRounded,
        suffix: "",
        hint: "For your current goal, about 3 to 5 unknown words per minute is the target zone.",
      },
      {
        label: "Clean Lines",
        value: formatMetricPercent(cleanLineRatioPct),
        hint: "Lines with zero unknown words. Current line detection is based on subtitle entries, not full grammar sentences.",
      },
      {
        label: "Unmastered Unique Word Share",
        value: formatMetricPercent(unknownUniqueRatioPct),
        hint: "Among non-repeated vocabulary types, this is the percentage that you have not mastered yet.",
      },
    ],
    fit: {
      ...fit,
      supportingValue: `${unknownWordsPerMinuteRounded} unknown/min`,
      secondaryValue: `${formatMetricPercent(cleanLineRatioPct)} clean lines`,
    },
  };
}

function analyzeSubtitleLines(lines) {
  const wordCounter = new Map();
  const normalizedLineWords = buildNormalizedTranscriptLemmaLines(lines);

  for (const words of normalizedLineWords) {
    for (const word of words) {
      wordCounter.set(word, (wordCounter.get(word) || 0) + 1);
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
        return `${data.name}<br/>Cumulative mastered: ${data.value} words`;
      },
    },
    xAxis: {
      type: "category",
      data: dates,
      boundaryGap: false,
    },
    yAxis: {
      type: "value",
      name: "Cumulative Words",
      min: yAxisMin,
      axisLabel: {
        formatter: "{value}",
      },
    },
    series: [
      {
        name: "Cumulative Mastered Words",
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
        return `${data.name}<br/>New today: ${data.value} words`;
      },
    },
    xAxis: {
      type: "category",
      data: dates,
      boundaryGap: false,
    },
    yAxis: {
      type: "value",
      name: "New Words",
      min: 0,
      axisLabel: {
        formatter: "{value}",
      },
    },
    series: [
      {
        name: "New Words per Day",
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
    throw new Error("Only CSV files are supported.");
  }

  const parsedLearningData = parseLearningDataCsv(text);
  if (parsedLearningData) {
    masteredWords.value = parsedLearningData.mastered_words || {};
    saveMasteredWordsToStorage();

    if (Array.isArray(parsedLearningData.player_history)) {
      playerHistoryVideos.value = parsedLearningData.player_history
        .filter(
          (item) =>
            item &&
            item.id &&
            typeof item.url === "string" &&
            item.url.startsWith(LOCAL_MATERIAL_URL_PREFIX)
        )
        .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0))
        .slice(0, 30);
      savePlayerHistory();
    }

    saveLearningDataVersion(FIXED_MASTERED_WORDS_FILE_NAME);
    refreshTedMasteredFlags();
    await loadLearningProgress();
    ensureSetupModalState();
    return "Learning data CSV imported successfully.";
  }

  masteredWords.value = parseMasteredWordsCsv(text);
  saveMasteredWordsToStorage();
  saveLearningDataVersion(FIXED_MASTERED_WORDS_FILE_NAME);
  refreshTedMasteredFlags();
  await loadLearningProgress();
  ensureSetupModalState();
  return "Learning data CSV imported successfully.";
}

async function importWordLabelsFromFile(file) {
  const text = await readFileAsText(file);
  const parsed = parseWordLabelsCsv(text);
  if (!parsed.size) {
    throw new Error("The word list is empty or malformed.");
  }

  applyWordLabels(parsed, FIXED_WORD_LABELS_FILE_NAME);
  await loadLearningProgress();
  ensureSetupModalState();
  return `Word list imported successfully with ${parsed.size} words.`;
}

async function handleImportLearningData(event) {
  const file = event?.target?.files?.[0];
  if (!file) return;

  try {
    const successText = await importLearningDataFromFile(file);
    message.success(successText);
  } catch (err) {
    message.error(`Import failed: ${err.message || err}`);
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
    message.error(`Word list import failed: ${err.message || err}`);
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
    message.error(`Word list import failed: ${err.message || err}`);
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
    message.error(`Learning data import failed: ${err.message || err}`);
  } finally {
    if (event?.target) {
      event.target.value = "";
    }
  }
}

function closeSetupModal() {
  if (!isDataSetupReady.value) {
    message.warning("Import the word list and learning data first.");
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
    message.info("10000+ is a fallback label, so a full unmastered-word list is not available for it yet.");
    return;
  }

  if (progress.mastered >= progress.total) {
    message.info("All words are already mastered.");
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
  message.success("Marked as mastered.");
}

async function unmarkWordMastered(word) {
  applyWordMasteredStatus(word, false);
  refreshTedMasteredFlags();
  await loadLearningProgress();
  message.success("Mastered mark removed.");
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
    message.info("There are no unmarked words on this page.");
    return;
  }

  const wordsToMark = ref([...initialWords]);
  let modalInstance = null;

  const createContent = () => {
    return h("div", [
      h("p", { style: "margin-bottom: 12px" }, [
        "You are about to mark ",
        h("strong", { style: "color: #1890ff" }, wordsToMark.value.length),
        " words:",
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
                "All words removed"
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
                                  title: "Confirm Mark as Mastered",
                                  width: 500,
                                  content: createContent(),
                                  okText: "Confirm",
                                  cancelText: "Cancel",
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
      message.info("There are no words to mark.");
      return;
    }

    wordsToMark.value.forEach((item) => {
      applyWordMasteredStatus(item.word, true);
    });

    refreshTedMasteredFlags();
    await loadLearningProgress();
    message.success(`Marked ${wordsToMark.value.length} words as mastered.`);
  };

  modalInstance = Modal.confirm({
    title: "Confirm Mark as Mastered",
    width: 500,
    content: createContent(),
    okText: "Confirm",
    cancelText: "Cancel",
    onOk: handleOk,
  });
}

function handleHomeVideoFileChange(event) {
  const file = event?.target?.files?.[0] || null;
  homeVideoFile.value = file;
  homeVideoFileName.value = file?.name || "";
}

function triggerHomeVideoUpload() {
  if (!homeVideoInputRef.value) return;
  homeVideoInputRef.value.value = "";
  homeVideoInputRef.value.click();
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

async function analyzeHomeSubtitleOnly() {
  if (!homeCanAnalyzeSubtitleOnly.value) {
    homeError.value = "Choose a local subtitle file first.";
    return;
  }

  homeAnalyzeLoading.value = true;
  homeError.value = "";

  try {
    const lines = await parseSubtitleFile(homeSubtitleFile.value);
    const title = deriveLocalMaterialTitle({
      title: homeMaterialTitle.value,
      videoFileName: homeVideoFileName.value,
      subtitleFileName: homeSubtitleFileName.value,
    });
    const analysisKey = `local-analysis:${title}:${computeTranscriptHash(lines)}`;

    youtubeUrl.value = analysisKey;
    parsedYoutubeUrl.value = analysisKey;
    youtubeVideoTitle.value = title;
    youtubeSubtitles.value = [
      {
        language_code: "local",
        language: `Local subtitles · ${homeSubtitleFileName.value || "Untitled"}`,
      },
    ];
    selectedYoutubeSubtitle.value = "local";
    tedSubtitleLines.value = lines;
    tedSubtitleFileName.value = homeSubtitleFileName.value;

    openTedPage();
    await nextTick();
    await analyzeTedFile();
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    homeError.value = `Subtitle analysis failed: ${errorMsg}`;
  } finally {
    homeAnalyzeLoading.value = false;
  }
}

async function openLocalMaterialInPlayer(item, options = {}) {
  if (!item?.url) return;

  const materialId = parseLocalMaterialId(item.url) || String(item.videoId || "").trim();
  if (!materialId) {
    throw new Error("Invalid local material ID.");
  }

  const videoBlob =
    options.videoBlob instanceof Blob ? options.videoBlob : await loadLocalVideoBlob(materialId);
  if (!(videoBlob instanceof Blob)) {
    throw new Error("The cached local video is missing. Re-import the material.");
  }

  playerParsedYoutubeUrl.value = item.url;
  playerYoutubeUrl.value = item.url;
  playerVideoId.value = materialId;
  playerVideoTitle.value = getHistoryDisplayTitle(item);
  playerSubtitleOptions.value = [
    {
      language_code: "local",
      language: `Local subtitles · ${item.subtitleFileName || "Untitled"}`,
    },
  ];
  playerSelectedSubtitle.value = "local";
  playerSubtitleFileName.value = item.subtitleFileName || "";
  playerLocalSubtitleLines.value = Array.isArray(item.subtitleLines)
    ? item.subtitleLines.slice()
    : [];
  playerHasVideo.value = true;
  playerCurrentVideoBlob = videoBlob;
  currentPage.value = "player";
  await loadPlayerTranscript();
}

async function importHomeMaterial() {
  if (!homeCanImportMaterial.value) {
    homeError.value = "Upload both a local video file and a subtitle file first.";
    return;
  }

  homeParseLoading.value = true;
  homeError.value = "";

  try {
    const lines = await parseSubtitleFile(homeSubtitleFile.value);
    const materialId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const materialUrl = buildLocalMaterialUrl(materialId);
    const title = deriveLocalMaterialTitle({
      title: homeMaterialTitle.value,
      videoFileName: homeVideoFileName.value,
      subtitleFileName: homeSubtitleFileName.value,
    });

    await saveLocalVideoBlob(materialId, homeVideoFile.value);

    const entry = upsertPlayerHistory({
      url: materialUrl,
      videoId: materialId,
      title,
      subtitleCode: "local",
      subtitleFileName: homeSubtitleFileName.value,
      subtitleLines: lines,
      videoFileName: homeVideoFileName.value,
      hasVideo: true,
    });

    homeParsedUrl.value = materialUrl;
    homeParsedVideoId.value = materialId;
    homeParsedTitle.value = title;
    homeParsedLines.value = lines;

    await openLocalMaterialInPlayer(entry, { videoBlob: homeVideoFile.value });
    message.success(`Imported and cached: ${title}`);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    homeError.value = `Import failed: ${errorMsg}`;
  } finally {
    homeParseLoading.value = false;
  }
}

async function startLearningFromHistory(item) {
  if (!item || !item.url) return;
  if (!item.hasVideo) {
    message.info("This entry only has subtitles. Import a video file to study it in Player.");
    return;
  }

  try {
    await openLocalMaterialInPlayer(item);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    message.error(errorMsg);
  }
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
  const removedItem = playerHistoryVideos.value.find((item) => item.id === historyId);
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
  void deleteLocalVideoBlob(parseLocalMaterialId(removedItem?.url || ""));
}

async function removeSelectedHistoryVideos() {
  if (!homeSelectedHistoryIds.value.length) return;

  const selectedSet = new Set(homeSelectedHistoryIds.value);
  const removedItems = playerHistoryVideos.value.filter((item) => selectedSet.has(item.id));
  playerHistoryVideos.value = playerHistoryVideos.value.filter(
    (item) => !selectedSet.has(item.id)
  );
  await Promise.all(
    removedItems.map((item) => deleteLocalVideoBlob(parseLocalMaterialId(item.url || "")))
  );
  savePlayerHistory();
  message.success(`Deleted ${selectedSet.size} materials.`);
  homeSelectedHistoryIds.value = [];
  if (!playerHistoryVideos.value.length) {
    homeHistorySelectionMode.value = false;
  }
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
      .filter(
        (item) =>
          item &&
          item.id &&
          typeof item.url === "string" &&
          item.url.startsWith(LOCAL_MATERIAL_URL_PREFIX)
      )
      .sort((a, b) => (b.lastUsedAt || 0) - (a.lastUsedAt || 0));
    homeSelectedHistoryIds.value = [];
    homeHistorySelectionMode.value = false;
  } catch (err) {
    console.warn("Failed to load player history:", err);
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
    console.warn("Failed to save player history:", err);
    message.warning("History is too large. Saving only recent items instead.");

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
      console.warn("Failed to save history even after fallback:", innerErr);
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
  videoFileName,
  hasVideo,
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
    videoFileName: videoFileName || existing?.videoFileName || "",
    hasVideo: typeof hasVideo === "boolean" ? hasVideo : existing?.hasVideo ?? false,
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
    tedError.value = "Enter a YouTube URL.";
    return;
  }
  if (!tedSubtitleFile.value) {
    tedError.value = "Choose a local subtitle file first.";
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
    youtubeVideoTitle.value = `YouTube Video (${videoId})`;
    tedSubtitleLines.value = lines;
    youtubeSubtitles.value = [
      {
        language_code: "local",
        language: `Local subtitles · ${tedSubtitleFileName.value || "Untitled"}`,
      },
    ];
    selectedYoutubeSubtitle.value = "local";

    message.success(`Subtitles parsed successfully: ${lines.length} lines.`);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = `Subtitle parsing failed: ${errorMsg}`;
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
      source: "local",
      youtube_url: youtubeUrl.value.trim(),
      language_code: selectedYoutubeSubtitle.value,
      subtitle_hash: computeTranscriptHash(tedSubtitleLines.value),
    };
    tedSelectedTagFilter.value = null;
    tedPagination.value.current = 1;
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    tedError.value = `Analysis failed: ${errorMsg}`;
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

function clampPlayerTime(seconds, maxSeconds = playerDuration.value) {
  const normalizedSeconds = Number(seconds);
  const safeSeconds = Number.isFinite(normalizedSeconds) ? normalizedSeconds : 0;
  const normalizedMax = Number(maxSeconds);
  const safeMax =
    Number.isFinite(normalizedMax) && normalizedMax > 0 ? normalizedMax : Number.POSITIVE_INFINITY;

  return Math.max(0, Math.min(safeSeconds, safeMax));
}

function syncPlayerTimelineInfo() {
  let duration = NaN;

  if (
    englishPlayerInstance &&
    typeof englishPlayerInstance.getDuration === "function"
  ) {
    duration = Number(englishPlayerInstance.getDuration());
  }

  if ((!Number.isFinite(duration) || duration <= 0) && playerVideoRef.value instanceof HTMLVideoElement) {
    duration = Number(playerVideoRef.value.duration);
  }

  playerDuration.value = Number.isFinite(duration) && duration > 0 ? duration : 0;
  playerCurrentTime.value = clampPlayerTime(playerCurrentTime.value);

  if (playerSeekPreviewTime.value != null) {
    playerSeekPreviewTime.value = clampPlayerTime(playerSeekPreviewTime.value);
  }
}

function getProgressEventValue(event) {
  const rawValue = event?.target?.value;
  return clampPlayerTime(rawValue);
}

function formatPlaybackRateLabel(rate) {
  const normalized = Number(rate || 1);
  return `${Number.isInteger(normalized) ? normalized.toFixed(0) : normalized}x`;
}

function normalizePlaybackRates(rates) {
  if (!Array.isArray(rates)) {
    return PLAYER_PLAYBACK_RATES.slice();
  }

  const normalized = rates
    .map((rate) => Number(rate))
    .filter((rate) => Number.isFinite(rate) && rate > 0);

  return normalized.length ? normalized : PLAYER_PLAYBACK_RATES.slice();
}

function syncPlayerPlaybackRateInfo() {
  if (!englishPlayerInstance) {
    return;
  }

  if (typeof englishPlayerInstance.getAvailablePlaybackRates === "function") {
    playerAvailablePlaybackRates.value = normalizePlaybackRates(
      englishPlayerInstance.getAvailablePlaybackRates()
    );
  }

  if (typeof englishPlayerInstance.getPlaybackRate === "function") {
    const currentRate = Number(englishPlayerInstance.getPlaybackRate());
    if (Number.isFinite(currentRate) && currentRate > 0) {
      playerPlaybackRate.value = currentRate;
    }
  }
}

function isPlaybackRateAvailable(rate) {
  return playerAvailablePlaybackRates.value.includes(Number(rate));
}

function applyPreferredPlaybackRate() {
  if (
    !englishPlayerInstance ||
    typeof englishPlayerInstance.setPlaybackRate !== "function"
  ) {
    return;
  }

  const preferredRate = Number(playerPlaybackRate.value || 1);
  const availableRates = playerAvailablePlaybackRates.value;
  const nextRate = availableRates.includes(preferredRate)
    ? preferredRate
    : availableRates.includes(1)
      ? 1
      : availableRates[0];

  if (!Number.isFinite(nextRate) || nextRate <= 0) {
    return;
  }

  englishPlayerInstance.setPlaybackRate(nextRate);
  playerPlaybackRate.value = nextRate;
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
    const videoEl = playerVideoRef.value;
    if (
      playerIframeReady.value ||
      (videoEl instanceof HTMLVideoElement && videoEl.readyState >= 1 && !!videoEl.duration)
    ) {
      playerIframeReady.value = true;
      return true;
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
    playerInitError.value = "Missing local material ID.";
    return false;
  }

  if (!playerHasVideo.value) {
    playerInitError.value = "No cached local video is available for this material.";
    return false;
  }

  try {
    await mountEnglishPlayer(playerVideoId.value);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerInitError.value = errorMsg;
    playerError.value = `Player initialization failed: ${errorMsg}`;
    return false;
  }

  if (!hasPlayablePlayerInstance()) {
    const ready = await waitForPlayerReady(5000);
    if (!ready) {
      playerInitError.value =
        playerInitError.value || "The player instance was not created successfully.";
    }
  }
  return hasPlayablePlayerInstance();
}

async function seekAndPlay(seconds) {
  const start = Number(seconds || 0);
  if (hasPlayerApiMethods() && englishPlayerInstance) {
    englishPlayerInstance.seekTo(start, true);
    englishPlayerInstance.playVideo();
    playerCurrentTime.value = start;
    return true;
  }

  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance) {
    message.warning(
      playerInitError.value
        ? `Player not ready: ${playerInitError.value}`
        : "Player not ready"
    );
    return false;
  }

  englishPlayerInstance.seekTo(start, true);
  englishPlayerInstance.playVideo();
  playerCurrentTime.value = start;
  return true;
}

async function seekPlayerToTime(seconds) {
  const targetTime = clampPlayerTime(seconds);

  if (hasPlayerApiMethods() && englishPlayerInstance) {
    englishPlayerInstance.seekTo(targetTime, true);
    playerCurrentTime.value = targetTime;
    clearPinnedSubtitleIndex();
    playerPlaybackTarget.value = null;
    return true;
  }

  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance) {
    message.warning(
      playerInitError.value
        ? `Player not ready: ${playerInitError.value}`
        : "Player not ready"
    );
    return false;
  }

  englishPlayerInstance.seekTo(targetTime, true);
  playerCurrentTime.value = targetTime;
  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  return true;
}

function handlePlayerProgressInput(event) {
  if (!canSeekPlayback.value) {
    return;
  }

  playerSeekPreviewTime.value = getProgressEventValue(event);
}

async function handlePlayerProgressCommit(event) {
  const targetTime = getProgressEventValue(event);
  playerSeekPreviewTime.value = targetTime;

  try {
    if (!canSeekPlayback.value) {
      return;
    }

    await seekPlayerToTime(targetTime);
  } finally {
    playerSeekPreviewTime.value = null;
  }
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
  if (hasPlayerApiMethods() && englishPlayerInstance) {
    clearPinnedSubtitleIndex();
    playerPlaybackTarget.value = null;
    englishPlayerInstance.playVideo();
    return;
  }

  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance || typeof englishPlayerInstance.playVideo !== "function") {
    message.warning(
      playerInitError.value
        ? `Player not ready: ${playerInitError.value}`
        : "Player not ready"
    );
    return;
  }

  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  englishPlayerInstance.playVideo();
}

async function playAbRange() {
  if (!canPlayAbRange.value) {
    message.info("Set A and B in the subtitles first.");
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

function hasPausedAbPlaybackTarget() {
  return playerPlaybackTarget.value?.mode === "ab";
}

function resumeAbRangePlayback() {
  const target = playerPlaybackTarget.value;
  if (
    target?.mode !== "ab" ||
    !englishPlayerInstance ||
    typeof englishPlayerInstance.playVideo !== "function"
  ) {
    return false;
  }

  const resumeThreshold = Number(target.end || 0) - SINGLE_LINE_STOP_BUFFER;
  if (
    typeof englishPlayerInstance.getCurrentTime === "function" &&
    typeof englishPlayerInstance.seekTo === "function"
  ) {
    const currentTime = Number(englishPlayerInstance.getCurrentTime());
    if (!Number.isNaN(currentTime) && currentTime >= resumeThreshold) {
      englishPlayerInstance.seekTo(Number(target.start || 0), true);
      playerCurrentTime.value = Number(target.start || 0);
    } else if (
      !Number.isNaN(currentTime) &&
      (currentTime < Number(target.start || 0) || currentTime > Number(target.end || 0))
    ) {
      englishPlayerInstance.seekTo(Number(target.start || 0), true);
      playerCurrentTime.value = Number(target.start || 0);
    }
  }

  englishPlayerInstance.playVideo();
  return true;
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
    message.info("Select two subtitle lines as A and B first.");
    return;
  }

  const mergedText = buildAbRangeSubtitleText();
  if (!mergedText) {
    message.warning("The selected AB range has no text to copy.");
    return;
  }

  try {
    const copied = await writeClipboardText(mergedText);
    if (!copied) {
      throw new Error("copy_failed");
    }
    message.success("Copied the AB subtitle range as one line.");
  } catch {
    message.error("Copy failed. Check browser clipboard permissions.");
  }
}

function isAbCandidate(index) {
  return playerAbSelectionMode.value && playerAbSelectionCandidates.value.includes(index);
}

function getAbMarkerLabel(index) {
  if (index === playerAbStartIndex.value) {
    return "A";
  }

  if (index === playerAbEndIndex.value) {
    return "B";
  }

  return "";
}

function handleAbControlClick() {
  if (!playerTranscriptLines.value.length) return;

  if (playerAbSelectionMode.value) {
    clearAbSelection();
    playerPlaybackTarget.value = null;
    message.info("Cancelled AB selection.");
    return;
  }

  if (canPlayAbRange.value) {
    clearAbSelection();
    playerPlaybackTarget.value = null;
    message.info("Cleared the AB range.");
    return;
  }

  clearAbSelection();
  playerAbSelectionMode.value = true;
  message.info("Select two subtitle lines for A / B.");
}

function toggleAbCandidate(index) {
  if (index < 0 || index >= playerTranscriptLines.value.length) return;

  const current = playerAbSelectionCandidates.value.slice();
  const existing = current.indexOf(index);
  if (existing >= 0) {
    current.splice(existing, 1);
    playerAbSelectionCandidates.value = current;
    playerAbStartIndex.value = -1;
    playerAbEndIndex.value = -1;
    playerPlaybackTarget.value = null;
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
    playerAbSelectionCandidates.value = [];
    playerAbSelectionMode.value = false;
    playerPlaybackTarget.value = null;
    message.info("AB range ready. Press Play to loop or Copy AB to copy.");
  }
}

function handleSubtitleItemClick(index) {
  if (!playerAbSelectionMode.value) {
    return;
  }

  toggleAbCandidate(index);
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

async function jumpToTranscriptStart() {
  if (!playerTranscriptLines.value.length) return;

  const firstLine = playerTranscriptLines.value[0];
  if (!firstLine) return;

  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  await seekAndPlay(firstLine.start);
}

async function jumpToTranscriptEnd() {
  if (!playerTranscriptLines.value.length) return;

  const lastLine = playerTranscriptLines.value[playerTranscriptLines.value.length - 1];
  if (!lastLine) return;

  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  await seekAndPlay(lastLine.start);
}

function setPlayerPlaybackRate(rate) {
  const nextRate = Number(rate);
  if (!Number.isFinite(nextRate) || nextRate <= 0) {
    return;
  }

  if (!isPlaybackRateAvailable(nextRate)) {
    message.info(`This video does not support ${formatPlaybackRateLabel(nextRate)}.`);
    return;
  }

  playerPlaybackRate.value = nextRate;
  if (
    !englishPlayerInstance ||
    typeof englishPlayerInstance.setPlaybackRate !== "function"
  ) {
    return;
  }

  englishPlayerInstance.setPlaybackRate(nextRate);
  syncPlayerPlaybackRateInfo();
}

async function togglePlayerPlayPause() {
  if (hasPlayerApiMethods() && englishPlayerInstance) {
    if (playerIsPlaying.value) {
      if (typeof englishPlayerInstance.pauseVideo === "function") {
        englishPlayerInstance.pauseVideo();
      }
      if (!hasPausedAbPlaybackTarget()) {
        playerPlaybackTarget.value = null;
      }
      return;
    }

  if (resumeAbRangePlayback()) {
    return;
  }

  if (canPlayAbRange.value && !playerAbSelectionMode.value) {
    await playAbRange();
    return;
  }

  clearPinnedSubtitleIndex();
  playerPlaybackTarget.value = null;
  englishPlayerInstance.playVideo();
    return;
  }

  const ready = await ensurePlayerReady();
  if (!ready || !englishPlayerInstance) {
    message.warning(
      playerInitError.value
        ? `Player not ready: ${playerInitError.value}`
        : "Player not ready"
    );
    return;
  }

  if (playerIsPlaying.value) {
    if (typeof englishPlayerInstance.pauseVideo === "function") {
      englishPlayerInstance.pauseVideo();
    }
    if (!hasPausedAbPlaybackTarget()) {
      playerPlaybackTarget.value = null;
    }
    return;
  }

  if (resumeAbRangePlayback()) {
    return;
  }

  if (canPlayAbRange.value && !playerAbSelectionMode.value) {
    await playAbRange();
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

function getFullscreenElement() {
  if (typeof document === "undefined") {
    return null;
  }

  return document.fullscreenElement || document.webkitFullscreenElement || null;
}

function syncPlayerFullscreenState() {
  const fullscreenElement = getFullscreenElement();
  const panelEl = playerVideoPanelRef.value;
  const videoEl = playerVideoRef.value;
  const isVideoNativeFullscreen = Boolean(
    videoEl &&
    typeof videoEl.webkitDisplayingFullscreen === "boolean" &&
    videoEl.webkitDisplayingFullscreen
  );

  playerIsFullscreen.value = Boolean(
    fullscreenElement &&
      (fullscreenElement === panelEl || fullscreenElement === videoEl)
  ) || isVideoNativeFullscreen;
}

async function exitPlayerFullscreen() {
  if (typeof document === "undefined") {
    return false;
  }

  const videoEl = playerVideoRef.value;
  const fullscreenElement = getFullscreenElement();

  if (fullscreenElement && typeof document.exitFullscreen === "function") {
    await document.exitFullscreen();
    return true;
  }

  if (fullscreenElement && typeof document.webkitExitFullscreen === "function") {
    document.webkitExitFullscreen();
    return true;
  }

  if (
    videoEl &&
    typeof videoEl.webkitExitFullscreen === "function" &&
    typeof videoEl.webkitDisplayingFullscreen === "boolean" &&
    videoEl.webkitDisplayingFullscreen
  ) {
    videoEl.webkitExitFullscreen();
    return true;
  }

  return false;
}

async function togglePlayerFullscreen() {
  if (!playerHasVideo.value) {
    return;
  }

  const panelEl = playerVideoPanelRef.value;
  const videoEl = playerVideoRef.value;

  try {
    if (playerIsFullscreen.value) {
      await exitPlayerFullscreen();
      syncPlayerFullscreenState();
      return;
    }

    if (panelEl && typeof panelEl.requestFullscreen === "function") {
      await panelEl.requestFullscreen();
      syncPlayerFullscreenState();
      return;
    }

    if (panelEl && typeof panelEl.webkitRequestFullscreen === "function") {
      panelEl.webkitRequestFullscreen();
      syncPlayerFullscreenState();
      return;
    }

    if (videoEl && typeof videoEl.requestFullscreen === "function") {
      await videoEl.requestFullscreen();
      syncPlayerFullscreenState();
      return;
    }

    if (videoEl && typeof videoEl.webkitEnterFullscreen === "function") {
      videoEl.webkitEnterFullscreen();
      syncPlayerFullscreenState();
      return;
    }

    message.info("Fullscreen is not supported in this browser.");
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    message.error(`Failed to toggle fullscreen: ${errorMsg}`);
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
  return true;
}

function startEnglishPlayerTimer() {
  stopEnglishPlayerTimer();
  englishPlayerTimer = window.setInterval(() => {
    if (englishPlayerInstance && typeof englishPlayerInstance.getCurrentTime === "function") {
      const currentTime = Number(englishPlayerInstance.getCurrentTime());
      if (!Number.isNaN(currentTime)) {
        playerCurrentTime.value = currentTime;
        syncPlayerTimelineInfo();
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
    const playerRoot = playerVideoRef.value;
    if (playerRoot instanceof HTMLVideoElement) {
      return playerRoot;
    }
    await new Promise((resolve) => window.setTimeout(resolve, intervalMs));
  }
  return null;
}

function revokePlayerVideoUrl() {
  if (!playerVideoObjectUrl) {
    return;
  }
  URL.revokeObjectURL(playerVideoObjectUrl);
  playerVideoObjectUrl = "";
}

function detachPlayerVideoEvents() {
  if (typeof playerVideoEventCleanup === "function") {
    playerVideoEventCleanup();
  }
  playerVideoEventCleanup = null;
}

function attachPlayerVideoEvents(videoEl) {
  detachPlayerVideoEvents();

  const handleLoadedMetadata = () => {
    playerIframeReady.value = true;
    playerCurrentTime.value = Number(videoEl.currentTime || 0);
    playerIsPlaying.value = !videoEl.paused;
    syncPlayerTimelineInfo();
    syncPlayerPlaybackRateInfo();
  };
  const handlePlay = () => {
    playerIsPlaying.value = true;
  };
  const handlePause = () => {
    playerIsPlaying.value = false;
  };
  const handleRateChange = () => {
    playerPlaybackRate.value = Number(videoEl.playbackRate || 1);
    syncPlayerPlaybackRateInfo();
  };
  const handleEnded = () => {
    playerIsPlaying.value = false;
    playerPlaybackTarget.value = null;
  };
  const handleDurationChange = () => {
    syncPlayerTimelineInfo();
  };
  const handleWebkitBeginFullscreen = () => {
    playerIsFullscreen.value = true;
  };
  const handleWebkitEndFullscreen = () => {
    playerIsFullscreen.value = false;
  };

  videoEl.addEventListener("loadedmetadata", handleLoadedMetadata);
  videoEl.addEventListener("play", handlePlay);
  videoEl.addEventListener("pause", handlePause);
  videoEl.addEventListener("ratechange", handleRateChange);
  videoEl.addEventListener("ended", handleEnded);
  videoEl.addEventListener("durationchange", handleDurationChange);
  videoEl.addEventListener("webkitbeginfullscreen", handleWebkitBeginFullscreen);
  videoEl.addEventListener("webkitendfullscreen", handleWebkitEndFullscreen);

  playerVideoEventCleanup = () => {
    videoEl.removeEventListener("loadedmetadata", handleLoadedMetadata);
    videoEl.removeEventListener("play", handlePlay);
    videoEl.removeEventListener("pause", handlePause);
    videoEl.removeEventListener("ratechange", handleRateChange);
    videoEl.removeEventListener("ended", handleEnded);
    videoEl.removeEventListener("durationchange", handleDurationChange);
    videoEl.removeEventListener("webkitbeginfullscreen", handleWebkitBeginFullscreen);
    videoEl.removeEventListener("webkitendfullscreen", handleWebkitEndFullscreen);
  };
}

function createLocalVideoPlayer(videoEl) {
  return {
    playVideo() {
      return videoEl.play();
    },
    pauseVideo() {
      videoEl.pause();
    },
    seekTo(seconds) {
      videoEl.currentTime = Math.max(0, Number(seconds || 0));
    },
    getCurrentTime() {
      return Number(videoEl.currentTime || 0);
    },
    getDuration() {
      return Number(videoEl.duration || 0);
    },
    getAvailablePlaybackRates() {
      return PLAYER_PLAYBACK_RATES.slice();
    },
    getPlaybackRate() {
      return Number(videoEl.playbackRate || 1);
    },
    setPlaybackRate(rate) {
      videoEl.playbackRate = Number(rate || 1);
    },
    destroy() {
      videoEl.pause();
      videoEl.removeAttribute("src");
      videoEl.load();
    },
  };
}

function destroyEnglishPlayer() {
  stopEnglishPlayerTimer();
  playerMountPromise = null;
  playerIframeReady.value = false;
  playerDuration.value = 0;
  playerSeekPreviewTime.value = null;
  playerCurrentTime.value = 0;
  clearPinnedSubtitleIndex();
  detachPlayerVideoEvents();
  if (englishPlayerInstance && typeof englishPlayerInstance.destroy === "function") {
    englishPlayerInstance.destroy();
  }
  englishPlayerInstance = null;
  playerIsPlaying.value = false;
  playerAvailablePlaybackRates.value = PLAYER_PLAYBACK_RATES.slice();
  revokePlayerVideoUrl();
}

function canReuseExistingPlayerSession(options = {}) {
  if (playerTranscriptLoading.value || !playerVideoId.value || !playerTranscriptLines.value.length) {
    return false;
  }

  const requestedVideoId =
    String(options.videoId || "").trim() || parseLocalMaterialId(options.youtubeUrl || "");
  if (!requestedVideoId || requestedVideoId !== playerVideoId.value) {
    return false;
  }

  const normalizedLines = normalizeSubtitleLines(
    Array.isArray(options.subtitleLines) ? options.subtitleLines : []
  );
  if (!normalizedLines.length) {
    return false;
  }

  return computeTranscriptHash(normalizedLines) === playerTranscriptHash.value;
}

async function mountEnglishPlayer(videoId) {
  if (!videoId) return;
  if (playerMountPromise) {
    await playerMountPromise;
    return;
  }

  playerMountPromise = (async () => {
    await nextTick();
    const playerRoot = await waitForPlayerRoot();
    if (!(playerRoot instanceof HTMLVideoElement)) {
      throw new Error("The player container is not ready.");
    }

    const videoBlob =
      playerCurrentVideoBlob instanceof Blob
        ? playerCurrentVideoBlob
        : await loadLocalVideoBlob(videoId);
    if (!(videoBlob instanceof Blob)) {
      throw new Error("No cached local video was found for this material.");
    }

    playerCurrentVideoBlob = videoBlob;
    playerIframeReady.value = false;
    playerCurrentTime.value = 0;
    playerIsPlaying.value = false;
    attachPlayerVideoEvents(playerRoot);
    revokePlayerVideoUrl();
    playerVideoObjectUrl = URL.createObjectURL(videoBlob);
    playerRoot.src = playerVideoObjectUrl;
    playerRoot.currentTime = 0;
    playerRoot.preload = "auto";
    playerRoot.playsInline = true;
    englishPlayerInstance = createLocalVideoPlayer(playerRoot);
    applyPreferredPlaybackRate();
    playerRoot.load();

    const ready = await waitForPlayerReady();
    if (!ready) {
      throw new Error(
        playerInitError.value || "Timed out while waiting for the player to become ready."
      );
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
    playerError.value = "Enter a YouTube URL.";
    return;
  }

  if (
    canReuseExistingPlayerSession({
      youtubeUrl: normalizedUrl,
      videoId: options.videoId || "",
      subtitleLines: Array.isArray(options.subtitleLines) ? options.subtitleLines : [],
    })
  ) {
    playerParsedYoutubeUrl.value = normalizedUrl;
    playerYoutubeUrl.value = normalizedUrl;
    if (options.title) {
      playerVideoTitle.value = String(options.title || "").trim() || playerVideoTitle.value;
    }
    if (options.subtitleFileName) {
      playerSubtitleFileName.value = options.subtitleFileName;
    }
    reopenExistingPlayerPage();
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
    const fallbackTitle = String(options.title || "").trim() || `YouTube Video (${videoId})`;
    let resolvedTitle = fallbackTitle;
    if (ENABLE_YOUTUBE_OEMBED_TITLE_FETCH && isGenericYoutubeTitle(resolvedTitle)) {
      try {
        const fetchedTitle = await fetchYoutubeVideoTitle(normalizedUrl);
        if (fetchedTitle) {
          resolvedTitle = fetchedTitle;
        }
      } catch (titleErr) {
        console.warn("Failed to fetch YouTube title. Using fallback title.", titleErr);
      }
    }

    playerParsedYoutubeUrl.value = normalizedUrl;
    playerYoutubeUrl.value = normalizedUrl;
    playerVideoId.value = videoId;
    playerVideoTitle.value = resolvedTitle;
    playerSubtitleOptions.value = [
      {
        language_code: "local",
        language: `Local subtitles · ${options.subtitleFileName || "Untitled"}`,
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
    playerError.value = `Failed to parse player video: ${errorMsg}`;
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
      playerError.value =
        "No subtitles are loaded for this video yet. Choose a subtitle file from Home first.";
      return;
    }

    upsertPlayerHistory({
      url: playerYoutubeUrl.value.trim(),
      videoId: playerVideoId.value,
      title: playerVideoTitle.value,
      subtitleCode: playerSelectedSubtitle.value,
      subtitleFileName: playerSubtitleFileName.value,
      subtitleLines: lines,
      hasVideo: playerHasVideo.value,
    });
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    playerError.value = `Failed to load subtitles: ${errorMsg}`;
  } finally {
    playerTranscriptLoading.value = false;
  }
}

async function analyzeCurrentSubtitleVocabulary() {
  if (!canAnalyzeCurrentPlayerSubtitle.value) {
    message.info("Load the video and subtitles first.");
    return;
  }

  youtubeUrl.value = playerParsedYoutubeUrl.value;
  parsedYoutubeUrl.value = playerParsedYoutubeUrl.value;
  youtubeVideoTitle.value = playerVideoTitle.value;
  youtubeSubtitles.value = [
    {
      language_code: "local",
      language: `Local subtitles · ${playerSubtitleFileName.value || "Untitled"}`,
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

function formatPlayerClock(seconds) {
  const totalSeconds = Math.max(0, Math.floor(Number(seconds || 0)));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const restSeconds = totalSeconds % 60;

  if (hours > 0) {
    return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(restSeconds).padStart(2, "0")}`;
  }

  return `${String(minutes).padStart(2, "0")}:${String(restSeconds).padStart(2, "0")}`;
}

function formatBuildTimeUtc(value) {
  const parsed = new Date(String(value || ""));
  if (Number.isNaN(parsed.getTime())) {
    return "Unknown";
  }

  const year = parsed.getUTCFullYear();
  const month = String(parsed.getUTCMonth() + 1).padStart(2, "0");
  const day = String(parsed.getUTCDate()).padStart(2, "0");
  const hours = String(parsed.getUTCHours()).padStart(2, "0");
  const minutes = String(parsed.getUTCMinutes()).padStart(2, "0");
  const seconds = String(parsed.getUTCSeconds()).padStart(2, "0");
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds} UTC`;
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

.player-local-video,
.player-video-empty {
  position: absolute;
  inset: 0;
}

.player-local-video {
  width: 100%;
  height: 100%;
  object-fit: contain;
  background: #000;
}

.player-video-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  color: rgba(255, 255, 255, 0.72);
  font-size: 14px;
  text-align: center;
  background:
    radial-gradient(circle at top, rgba(255, 255, 255, 0.08), transparent 42%),
    linear-gradient(135deg, #111827, #1f2937);
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

.player-progress-row {
  width: 100%;
  display: grid;
  grid-template-columns: 56px minmax(0, 1fr) 56px;
  align-items: center;
  gap: 10px;
}

.player-progress-time {
  font-size: 12px;
  font-weight: 700;
  color: #1f3f6b;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.player-progress-slider {
  --player-progress-percent: 0%;
  width: 100%;
  height: 6px;
  border-radius: 999px;
  outline: none;
  appearance: none;
  background: linear-gradient(
    90deg,
    #1677ff 0%,
    #1677ff var(--player-progress-percent),
    rgba(22, 119, 255, 0.16) var(--player-progress-percent),
    rgba(22, 119, 255, 0.16) 100%
  );
  cursor: pointer;
}

.player-progress-slider:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.player-progress-slider::-webkit-slider-runnable-track {
  height: 6px;
  border-radius: 999px;
  background: transparent;
}

.player-progress-slider::-webkit-slider-thumb {
  width: 16px;
  height: 16px;
  margin-top: -5px;
  border: 2px solid #fff;
  border-radius: 50%;
  appearance: none;
  background: #1677ff;
  box-shadow: 0 2px 6px rgba(22, 119, 255, 0.28);
}

.player-progress-slider::-moz-range-track {
  height: 6px;
  border-radius: 999px;
  background: transparent;
}

.player-progress-slider::-moz-range-thumb {
  width: 16px;
  height: 16px;
  border: 2px solid #fff;
  border-radius: 50%;
  background: #1677ff;
  box-shadow: 0 2px 6px rgba(22, 119, 255, 0.28);
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

.player-video-rate-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
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

.player-icon-btn-edge {
  width: 64px;
  min-width: 64px;
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

.player-rate-btn {
  min-width: 64px;
  height: 38px;
  padding: 0 14px !important;
  border-radius: 10px !important;
  font-weight: 600;
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
  position: relative;
  padding: 10px 12px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  cursor: default;
  transition: all 0.2s ease;
  background: #fff;
}

.player-subtitle-item.ab-select-mode {
  cursor: pointer;
}

.player-subtitle-item:hover {
  border-color: #91caff;
  background: #f5faff;
}

.player-subtitle-item.ab-candidate {
  border-color: #69b1ff;
  background: #f0f7ff;
}

.player-subtitle-item.active {
  border-color: #1890ff;
  background: #e6f7ff;
  outline: 2px solid rgba(24, 144, 255, 0.24);
  outline-offset: 1px;
}

.player-subtitle-item.in-ab-range {
  border-color: #95de64;
  background: #f6ffed;
}

.player-subtitle-item.ab-point-start {
  border-color: #faad14;
  background: #fff7e6;
  box-shadow: inset 4px 0 0 #faad14;
}

.player-subtitle-item.ab-point-end {
  border-color: #722ed1;
  background: #f9f0ff;
  box-shadow: inset 4px 0 0 #722ed1;
}

.player-subtitle-item[data-ab-marker="A"]::after,
.player-subtitle-item[data-ab-marker="B"]::after {
  position: absolute;
  top: 8px;
  right: 10px;
  min-width: 22px;
  height: 22px;
  padding: 0 6px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
}

.player-subtitle-item[data-ab-marker="A"]::after {
  content: "A";
  background: #faad14;
}

.player-subtitle-item[data-ab-marker="B"]::after {
  content: "B";
  background: #722ed1;
}

.player-subtitle-item.ab-select-mode:focus-visible {
  outline: 2px solid #69b1ff;
  outline-offset: 2px;
}

.player-subtitle-time {
  color: #1890ff;
  font-size: 13px;
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
  font-size: 17px;
  line-height: 1.65;
  user-select: text;
  cursor: text;
}

.player-subtitle-item.ab-select-mode .player-subtitle-text {
  cursor: pointer;
}

.player-video-panel:fullscreen,
.player-video-panel:-webkit-full-screen {
  width: 100%;
  height: 100%;
  box-sizing: border-box;
  border-radius: 0;
}

.player-unknown-word {
  background: #e6f4ff;
  color: #262626;
  border-radius: 4px;
  padding: 0 4px;
  margin: 0 1px;
  font-weight: 500;
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
  flex: 2 1 0;
  width: auto;
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
  flex: 3 1 0;
  width: auto;
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

.overview-label-with-help {
  display: inline-flex;
  align-items: center;
  gap: 6px;
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

.difficulty-section {
  margin-bottom: 24px;
  padding-top: 4px;
}

.difficulty-summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.difficulty-summary-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-height: 220px;
  padding: 16px;
  border-radius: 14px;
  background: linear-gradient(180deg, #ffffff 0%, #f7fbff 100%);
  border: 1px solid #dbe9ff;
}

.difficulty-summary-card-fit {
  background: linear-gradient(180deg, #fffdf2 0%, #fff7e6 100%);
  border-color: #ffe0b3;
}

.difficulty-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.difficulty-card-label {
  color: #4f5f73;
  font-size: 14px;
  font-weight: 600;
}

.difficulty-card-score {
  font-size: 38px;
  line-height: 1;
  font-weight: 700;
  color: #163250;
}

.difficulty-card-score-row {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
}

.difficulty-card-score-caption {
  color: #7b8794;
  font-size: 12px;
  line-height: 1.4;
  text-align: right;
}

.difficulty-fit-value {
  font-size: 22px;
  line-height: 1.2;
  font-weight: 700;
  color: #8c5f00;
}

.difficulty-bar-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.difficulty-bar {
  position: relative;
  height: 16px;
  border-radius: 999px;
  overflow: visible;
}

.difficulty-bar-neutral {
  background: linear-gradient(90deg, #d9f7be 0%, #fff7e6 50%, #ffccc7 100%);
}

.difficulty-bar-fit {
  background: linear-gradient(90deg, #d9f7be 0%, #fff7e6 50%, #ffd6bf 75%, #ffccc7 100%);
}

.difficulty-bar-center-line {
  position: absolute;
  top: -3px;
  bottom: -3px;
  left: 50%;
  width: 2px;
  transform: translateX(-50%);
  background: rgba(22, 50, 80, 0.2);
  border-radius: 999px;
}

.difficulty-bar-marker {
  position: absolute;
  top: 50%;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #163250;
  border: 3px solid #ffffff;
  box-shadow: 0 4px 10px rgba(22, 50, 80, 0.18);
  transform: translate(-50%, -50%);
}

.difficulty-bar-marker-fit {
  background: #ad6800;
}

.difficulty-bar-scale {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: #6b7a90;
  font-size: 12px;
  line-height: 1.4;
}

.difficulty-fit-subvalue,
.difficulty-card-desc {
  color: #5b6b7f;
  font-size: 13px;
  line-height: 1.55;
}

.difficulty-insight {
  margin-top: 14px;
  padding: 14px 16px;
  border-radius: 12px;
  background: #f6ffed;
  border: 1px solid #b7eb8f;
  color: #2f5d1d;
  font-size: 14px;
  line-height: 1.7;
}

.difficulty-metrics-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 14px;
}

.difficulty-metrics-card {
  padding: 16px;
  border-radius: 14px;
  background: #fafcff;
  border: 1px solid #e6f0ff;
}

.difficulty-metrics-title {
  margin-bottom: 12px;
  color: #163250;
  font-size: 15px;
  font-weight: 700;
}

.difficulty-metric-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.difficulty-metric-item {
  padding: 12px 12px 10px;
  border-radius: 10px;
  background: #fff;
  border: 1px solid #eef3f8;
}

.difficulty-metric-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.difficulty-metric-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #526275;
  font-size: 13px;
}

.difficulty-metric-value {
  color: #163250;
  font-size: 18px;
  font-weight: 700;
  white-space: nowrap;
}

.difficulty-metric-help-btn {
  width: 18px;
  height: 18px;
  border: none;
  border-radius: 50%;
  padding: 0;
  background: #e6f4ff;
  color: #1677ff;
  font-size: 12px;
  font-weight: 700;
  line-height: 18px;
  text-align: center;
  cursor: pointer;
}

.difficulty-metric-help-btn:hover {
  background: #bae0ff;
}

.difficulty-metric-help-popover {
  max-width: 240px;
  color: #445468;
  font-size: 12px;
  line-height: 1.6;
}

.difficulty-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 64px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}

.difficulty-badge-easy {
  background: #f6ffed;
  color: #389e0d;
}

.difficulty-badge-medium,
.difficulty-badge-ideal {
  background: #e6f4ff;
  color: #1677ff;
}

.difficulty-badge-hard,
.difficulty-badge-stretch {
  background: #fff7e6;
  color: #d46b08;
}

.difficulty-badge-very-hard {
  background: #fff1f0;
  color: #cf1322;
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

.table-section :deep(.ant-table-pagination.ant-pagination) {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 12px;
}

.table-section :deep(.ant-table-pagination .ant-pagination-options) {
  margin-inline-start: auto;
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

  .difficulty-summary-grid,
  .difficulty-metrics-grid {
    grid-template-columns: 1fr;
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

  .player-progress-row {
    grid-template-columns: 52px minmax(0, 1fr) 52px;
    gap: 8px;
  }

  .player-progress-time {
    font-size: 11px;
  }

  .player-video-main-controls {
    gap: 12px;
  }

  .player-video-rate-controls {
    gap: 6px;
  }

  .player-icon-btn {
    width: 62px;
    min-width: 62px;
    height: 50px;
    border-radius: 12px !important;
  }

  .player-icon-btn-edge {
    width: 54px;
    min-width: 54px;
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

  .player-rate-btn {
    min-width: 58px;
    height: 34px;
    padding: 0 10px !important;
    font-size: 13px;
  }

  .player-secondary-btn {
    min-width: 112px;
    height: 42px;
    padding: 0 18px !important;
    font-size: 14px;
  }

  .overview-content {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .difficulty-summary-card,
  .difficulty-metrics-card {
    padding: 14px;
  }

  .difficulty-card-score {
    font-size: 32px;
  }

  .difficulty-card-score-row {
    align-items: flex-start;
    flex-direction: column;
  }

  .difficulty-card-score-caption {
    text-align: left;
  }

  .player-subtitle-item {
    grid-template-columns: 52px 1fr;
    gap: 8px;
    padding: 9px 10px;
  }

  .player-subtitle-text {
    font-size: 16px;
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

.home-build-meta {
  margin-top: 8px;
  color: #7a8699;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.02em;
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

  .overview-content {
    grid-template-columns: 1fr;
  }

  .difficulty-card-header,
  .difficulty-metric-row {
    flex-direction: column;
    align-items: flex-start;
  }

  .difficulty-fit-value {
    font-size: 20px;
  }
}
</style>
