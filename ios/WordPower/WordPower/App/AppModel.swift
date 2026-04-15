import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let fileStore: AppFileStore
    let playerController = PlayerController()
    let wordCatalog: WordLabelCatalog

    @Published var selectedSection: AppSection = .home
    @Published var learningRecords: [String: LearningRecord] = [:] {
        didSet {
            refreshLearningDerivedState()
        }
    }
    @Published var materials: [MaterialRecord] = []
    @Published var readerProgress: [String: ReaderProgress] = [:]
    @Published var settings = AppSettings()
    @Published var currentVocabularySession: VocabularySession? {
        didSet {
            refreshVocabularyAnalysis()
        }
    }
    @Published var currentArticleID: String?
    @Published var currentArticleTitle = ""
    @Published var currentArticleText = ""
    @Published var currentReaderLayoutMode: ReaderLayoutMode = .single
    @Published var currentReaderFontScale: Double = 1.25
    @Published var currentReaderLineSpacingMultiplier: Double = 1.0
    @Published var currentReaderPage = 1
    @Published var currentReaderBlockIndex = 0
    @Published var statsGranularity: StatsGranularity = .day {
        didSet {
            refreshStatsPoints()
        }
    }
    @Published var selectedVocabularyTag: WordTag? {
        didSet {
            refreshVocabularyFilters()
        }
    }
    @Published var selectedFamiliarityFilter: Int? {
        didSet {
            refreshFamiliarityRows()
        }
    }
    @Published var wordActionContext: WordActionContext?
    @Published var lastErrorMessage = ""
    @Published var isLoading = true

    private var vocabularyBaseRows: [AnalysisWordRow] = []
    private var currentAnalysisRowsCache: [AnalysisWordRow] = []
    private var currentVocabularyOverviewCache = VocabularyOverview(uniqueWords: 0, masteredWords: 0, tagCounts: [:])
    private var currentDifficultyAssessmentCache: DifficultyAssessment?
    private var learningProgressItemsCache: [LearningProgressItem] = []
    private var familiarityRowsCache: [FamiliarityReviewRow] = []
    private var statsPointsCache: [LearningStatPoint] = []

    init(fileStore: AppFileStore = AppFileStore()) {
        self.fileStore = fileStore
        do {
            wordCatalog = try WordLabelCatalog.load()
        } catch {
            wordCatalog = WordLabelCatalog(labels: [:])
            lastErrorMessage = error.localizedDescription
        }

        refreshLearningDerivedState()

        Task {
            await loadPersistedState()
        }
    }

    var builtInWordListVersion: String {
        WordLabelCatalog.builtInVersion
    }

    var builtInWordListCount: Int {
        wordCatalog.count
    }

    var sortedMaterials: [MaterialRecord] {
        materials
    }

    var currentAnalysisRows: [AnalysisWordRow] {
        currentAnalysisRowsCache
    }

    var currentVocabularyOverview: VocabularyOverview {
        currentVocabularyOverviewCache
    }

    var currentDifficultyAssessment: DifficultyAssessment? {
        currentDifficultyAssessmentCache
    }

    var learningProgressItems: [LearningProgressItem] {
        learningProgressItemsCache
    }

    var familiarityRows: [FamiliarityReviewRow] {
        familiarityRowsCache
    }

    var statsPoints: [LearningStatPoint] {
        statsPointsCache
    }

    var articleParagraphs: [String] {
        WordPowerText.splitArticleIntoParagraphs(currentArticleText)
    }

    var articleAnalysisLines: [SubtitleLine] {
        WordPowerText.buildArticleAnalysisLines(paragraphs: articleParagraphs)
    }

    var articleSummary: String {
        guard !articleAnalysisLines.isEmpty else { return "" }
        return TextAnalysis.buildSummary(lines: articleAnalysisLines, catalog: wordCatalog, learningRecords: learningRecords)
    }

    var articleCoverage: (top3000: Double, top5000: Double, mastered: Double) {
        TextAnalysis.buildCoverageStats(lines: articleAnalysisLines, catalog: wordCatalog, learningRecords: learningRecords)
    }

    func loadPersistedState() async {
        defer { isLoading = false }
        do {
            let state = try await fileStore.loadState()
            learningRecords = LearningDataCodec.normalizeRecords(state.learningRecords)
            materials = state.materials.sorted { $0.lastUsedAt > $1.lastUsedAt }
            readerProgress = state.readerProgress
            settings = state.settings
            currentReaderLayoutMode = settings.readerLayoutMode
            currentReaderFontScale = settings.readerFontScale
            currentReaderLineSpacingMultiplier = settings.readerLineSpacingMultiplier
            playerController.setPlaybackRate(settings.playbackRate)
            playerController.setSubtitleFontScale(settings.subtitleFontScale)
            if let session = state.readerSession, !session.articleText.isEmpty {
                currentArticleID = session.materialID
                currentArticleTitle = session.title
                currentArticleText = session.articleText
                currentReaderPage = session.page
                currentReaderBlockIndex = session.blockIndex
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func importLearningData(from url: URL) async throws {
        let text = try SecurityScopedFileAccess.withAccess(to: url) {
            try String(contentsOf: url, encoding: .utf8)
        }
        learningRecords = LearningDataCodec.normalizeRecords(try LearningDataCodec.parseCSV(text))
        try await fileStore.saveLearningRecords(learningRecords)
    }

    func exportLearningDataDocument() -> CSVDocument {
        CSVDocument(text: LearningDataCodec.exportCSV(learningRecords))
    }

    func updateFamiliarity(for word: String, familiarity: Int) {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedWord.isEmpty else { return }
        let normalizedFamiliarity = LearningDataCodec.normalizeFamiliarity(familiarity)
        if normalizedFamiliarity == 0 {
            learningRecords.removeValue(forKey: normalizedWord)
        } else {
            learningRecords[normalizedWord] = LearningRecord(
                familiarity: normalizedFamiliarity,
                updatedAt: LearningDataCodec.normalizedDate(nil)
            )
        }
        persistLearningRecords()
    }

    func analyzeSubtitleFile(title: String, subtitleURL: URL, subtitleFileName: String) async throws {
        let lines = try SubtitleParser.parse(url: subtitleURL)
        currentVocabularySession = VocabularySession(
            sourceKind: .subtitle,
            sourceTitle: title,
            lines: lines,
            subtitleFileName: subtitleFileName
        )
        selectedSection = .vocabulary
    }

    func analyzeArticle(title: String, text: String) {
        let normalizedText = WordPowerText.normalizeArticleText(text)
        let lines = WordPowerText.buildArticleAnalysisLines(paragraphs: WordPowerText.splitArticleIntoParagraphs(normalizedText))
        currentVocabularySession = VocabularySession(
            sourceKind: .article,
            sourceTitle: title.isEmpty ? deriveArticleTitle(from: normalizedText) : title,
            lines: lines,
            subtitleFileName: ""
        )
        selectedSection = .vocabulary
    }

    func saveVideoMaterial(title: String, videoURL: URL?, subtitleURL: URL) async throws -> String {
        let subtitleLines = try SubtitleParser.parse(url: subtitleURL)
        let materialID = UUID().uuidString
        let importedFiles = try await fileStore.importFiles(materialID: materialID, videoURL: videoURL, subtitleURL: subtitleURL)
        let material = MaterialRecord(
            id: materialID,
            kind: .video,
            title: title.isEmpty ? deriveVideoTitle(videoURL: videoURL, subtitleURL: subtitleURL) : title,
            subtitleFileName: subtitleURL.lastPathComponent,
            videoFileName: videoURL?.lastPathComponent ?? "",
            hasVideo: videoURL != nil,
            articleText: "",
            subtitleLines: subtitleLines,
            videoRelativePath: importedFiles.videoRelativePath,
            subtitleRelativePath: importedFiles.subtitleRelativePath,
            lastUsedAt: Date().timeIntervalSince1970
        )
        upsertMaterial(material)
        return material.id
    }

    func importVideoMaterial(title: String, videoURL: URL, subtitleURL: URL) async throws {
        let materialID = try await saveVideoMaterial(title: title, videoURL: videoURL, subtitleURL: subtitleURL)
        try await openPlayerMaterial(materialID)
    }

    @discardableResult
    func saveArticleMaterial(title: String, text: String) -> String? {
        let normalizedText = WordPowerText.normalizeArticleText(text)
        let paragraphs = WordPowerText.splitArticleIntoParagraphs(normalizedText)
        guard !paragraphs.isEmpty else { return nil }

        let materialID = "article-\(UUID().uuidString)"
        let material = MaterialRecord(
            id: materialID,
            kind: .article,
            title: title.isEmpty ? deriveArticleTitle(from: normalizedText) : title,
            subtitleFileName: "",
            videoFileName: "",
            hasVideo: false,
            articleText: normalizedText,
            subtitleLines: WordPowerText.buildArticleAnalysisLines(paragraphs: paragraphs),
            videoRelativePath: nil,
            subtitleRelativePath: nil,
            lastUsedAt: Date().timeIntervalSince1970
        )
        upsertMaterial(material)
        return material.id
    }

    func startReadingArticle(title: String, text: String) {
        guard let materialID = saveArticleMaterial(title: title, text: text) else { return }
        openArticleMaterial(materialID)
    }

    func openArticleMaterial(_ materialID: String) {
        guard let material = materials.first(where: { $0.id == materialID }), material.kind == .article else { return }
        currentArticleID = material.id
        currentArticleTitle = material.title
        currentArticleText = material.articleText
        currentReaderLayoutMode = settings.readerLayoutMode
        if let saved = readerProgress[material.id] {
            currentReaderPage = saved.page
            currentReaderBlockIndex = saved.blockIndex
        } else {
            currentReaderPage = 1
            currentReaderBlockIndex = 0
        }
        touchMaterial(material.id)
        saveReaderSession()
        selectedSection = .reader
    }

    func openPlayerMaterial(_ materialID: String) async throws {
        guard let material = materials.first(where: { $0.id == materialID }), material.kind == .video else { return }
        let videoURL = await fileStore.materialFileURL(relativePath: material.videoRelativePath)
        if material.hasVideo, videoURL == nil {
            throw NSError(domain: "WordPower.Player", code: 1, userInfo: [NSLocalizedDescriptionKey: "The cached local video is missing."])
        }
        playerController.open(material: material, videoURL: videoURL, settings: settings)
        touchMaterial(material.id)
        selectedSection = .player
    }

    func reopenMaterial(_ material: MaterialRecord) async throws {
        switch material.kind {
        case .article:
            openArticleMaterial(material.id)
        case .video:
            try await openPlayerMaterial(material.id)
        }
    }

    func deleteMaterials(ids: Set<String>) async {
        guard !ids.isEmpty else { return }
        for id in ids {
            do {
                try await fileStore.removeFiles(for: id)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
        materials.removeAll { ids.contains($0.id) }
        try? await fileStore.saveMaterials(materials)
        if ids.contains(currentArticleID ?? "") {
            currentArticleID = nil
            currentArticleTitle = ""
            currentArticleText = ""
            try? await fileStore.saveReaderSession(nil)
            if selectedSection == .reader {
                selectedSection = .library
            }
        }
        if ids.contains(playerController.material?.id ?? "") {
            playerController.close()
            if selectedSection == .player {
                selectedSection = .library
            }
        }
    }

    func analyzeCurrentPlayerMaterial() {
        guard let material = playerController.material else { return }
        currentVocabularySession = VocabularySession(
            sourceKind: .subtitle,
            sourceTitle: material.title,
            lines: playerController.subtitleLines,
            subtitleFileName: material.subtitleFileName
        )
        selectedSection = .vocabulary
    }

    func analyzeCurrentArticle() {
        guard !currentArticleText.isEmpty else { return }
        analyzeArticle(title: currentArticleTitle, text: currentArticleText)
    }

    func updateReaderLayoutMode(_ mode: ReaderLayoutMode) {
        currentReaderLayoutMode = mode
        settings.readerLayoutMode = mode
        if let currentArticleID, let savedProgress = readerProgress[currentArticleID] {
            readerProgress[currentArticleID] = ReaderProgress(
                page: savedProgress.page,
                blockIndex: savedProgress.blockIndex,
                layoutMode: mode,
                updatedAt: Date().timeIntervalSince1970
            )
            persistReaderProgress()
        }
        persistSettings()
        saveReaderSession()
    }

    func updatePlaybackRate(_ value: Double) {
        playerController.setPlaybackRate(value)
        persistSettings()
    }

    func updateSubtitleScale(_ value: Double) {
        playerController.setSubtitleFontScale(value)
        persistSettings()
    }

    func updateReaderFontScale(_ value: Double) {
        currentReaderFontScale = value
        persistSettings()
    }

    func updateReaderLineSpacingMultiplier(_ value: Double) {
        currentReaderLineSpacingMultiplier = value
        persistSettings()
    }

    func updateReaderPosition(page: Int, blockIndex: Int) {
        currentReaderPage = page
        currentReaderBlockIndex = blockIndex
        guard let currentArticleID else {
            saveReaderSession()
            return
        }
        readerProgress[currentArticleID] = ReaderProgress(
            page: page,
            blockIndex: blockIndex,
            layoutMode: currentReaderLayoutMode,
            updatedAt: Date().timeIntervalSince1970
        )
        trimReaderProgress()
        persistReaderProgress()
        saveReaderSession()
    }

    func presentWordAction(displayToken: String, targetWord: String) {
        wordActionContext = WordActionContext(displayToken: displayToken, targetWord: targetWord)
    }

    func dismissWordAction() {
        wordActionContext = nil
    }

    func tagFilteredTitle() -> String {
        if let selectedVocabularyTag {
            return selectedVocabularyTag.rawValue
        }
        return currentVocabularySession?.sourceTitle ?? "Word List"
    }

    private func upsertMaterial(_ material: MaterialRecord) {
        if let existingIndex = materials.firstIndex(where: { $0.id == material.id }) {
            materials[existingIndex] = material
        } else {
            materials.append(material)
        }
        materials.sort { $0.lastUsedAt > $1.lastUsedAt }
        persistMaterials()
    }

    private func touchMaterial(_ id: String) {
        guard let index = materials.firstIndex(where: { $0.id == id }) else { return }
        materials[index].lastUsedAt = Date().timeIntervalSince1970
        materials.sort { $0.lastUsedAt > $1.lastUsedAt }
        persistMaterials()
    }

    private func deriveVideoTitle(videoURL: URL?, subtitleURL: URL) -> String {
        let videoName = videoURL?.deletingPathExtension().lastPathComponent ?? ""
        if !videoName.isEmpty {
            return videoName
        }
        let subtitleName = subtitleURL.deletingPathExtension().lastPathComponent
        return subtitleName.isEmpty ? "Local Material" : subtitleName
    }

    private func deriveArticleTitle(from text: String) -> String {
        let firstParagraph = WordPowerText.splitArticleIntoParagraphs(text).first ?? ""
        if firstParagraph.isEmpty {
            return "Untitled Article"
        }
        return String(firstParagraph.prefix(72))
    }

    private func refreshLearningDerivedState() {
        refreshVocabularyAnalysis()
        learningProgressItemsCache = TextAnalysis.buildLearningProgress(
            catalog: wordCatalog,
            learningRecords: learningRecords
        )
        refreshFamiliarityRows()
        refreshStatsPoints()
    }

    private func refreshVocabularyAnalysis() {
        guard let currentVocabularySession else {
            vocabularyBaseRows = []
            currentDifficultyAssessmentCache = nil
            refreshVocabularyFilters()
            return
        }

        vocabularyBaseRows = TextAnalysis.analyzeWords(
            lines: currentVocabularySession.lines,
            catalog: wordCatalog,
            learningRecords: learningRecords
        )
        currentDifficultyAssessmentCache = TextAnalysis.buildDifficultyAssessment(
            sourceKind: currentVocabularySession.sourceKind,
            lines: currentVocabularySession.lines,
            catalog: wordCatalog,
            learningRecords: learningRecords
        )
        refreshVocabularyFilters()
    }

    private func refreshVocabularyFilters() {
        let visibleRows = vocabularyBaseRows.filter { !$0.mastered }

        currentAnalysisRowsCache = visibleRows
            .filter { row in
                guard let selectedVocabularyTag else { return true }
                return row.tags.contains(selectedVocabularyTag)
            }
        currentVocabularyOverviewCache = TextAnalysis.buildVocabularyOverview(rows: visibleRows)
    }

    private func refreshFamiliarityRows() {
        let rows = TextAnalysis.buildFamiliarityRows(catalog: wordCatalog, learningRecords: learningRecords)
        guard let selectedFamiliarityFilter else {
            familiarityRowsCache = rows
            return
        }
        familiarityRowsCache = rows.filter { $0.familiarity == selectedFamiliarityFilter }
    }

    private func refreshStatsPoints() {
        statsPointsCache = TextAnalysis.buildStatistics(
            learningRecords: learningRecords,
            granularity: statsGranularity
        )
    }

    private func persistLearningRecords() {
        let normalized = LearningDataCodec.normalizeRecords(learningRecords)
        learningRecords = normalized
        Task {
            try? await fileStore.saveLearningRecords(normalized)
        }
    }

    private func persistReaderProgress() {
        let progress = readerProgress
        Task {
            try? await fileStore.saveReaderProgress(progress)
        }
    }

    private func persistSettings() {
        settings.playbackRate = playerController.playbackRate
        settings.subtitleFontScale = playerController.subtitleFontScale
        settings.readerFontScale = currentReaderFontScale
        settings.readerLineSpacingMultiplier = currentReaderLineSpacingMultiplier
        settings.readerLayoutMode = currentReaderLayoutMode
        let settings = settings
        Task {
            try? await fileStore.saveSettings(settings)
        }
    }

    private func persistMaterials() {
        let materials = self.materials
        Task {
            try? await fileStore.saveMaterials(materials)
        }
    }

    private func saveReaderSession() {
        let session: ReaderSessionData? = currentArticleText.isEmpty ? nil : ReaderSessionData(
            materialID: currentArticleID,
            title: currentArticleTitle,
            articleText: currentArticleText,
            page: currentReaderPage,
            blockIndex: currentReaderBlockIndex,
            layoutMode: currentReaderLayoutMode,
            savedAt: Date().timeIntervalSince1970
        )
        Task {
            try? await fileStore.saveReaderSession(session)
        }
    }

    private func trimReaderProgress() {
        let recentEntries = readerProgress
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .prefix(50)
            .map { ($0.key, $0.value) }
        readerProgress = Dictionary(recentEntries, uniquingKeysWith: { first, _ in first })
    }
}
