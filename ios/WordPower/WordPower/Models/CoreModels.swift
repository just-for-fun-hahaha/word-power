import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case library
    case player
    case reader
    case vocabulary
    case familiarity
    case statistics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .player: return "Player"
        case .reader: return "Reader"
        case .vocabulary: return "Vocabulary"
        case .familiarity: return "Familiarity"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .library: return "books.vertical"
        case .player: return "play.rectangle"
        case .reader: return "book"
        case .vocabulary: return "textformat.abc"
        case .familiarity: return "star.leadinghalf.filled"
        case .statistics: return "chart.xyaxis.line"
        case .settings: return "gearshape"
        }
    }
}

enum MaterialKind: String, Codable, CaseIterable, Hashable {
    case video
    case article
}

enum AnalysisSourceKind: String, Codable, Hashable {
    case subtitle
    case article
}

enum ReaderLayoutMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case single
    case spread

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .single: return "1P"
        case .spread: return "2P"
        }
    }
}

enum StatsGranularity: String, CaseIterable, Identifiable {
    case day
    case month

    var id: String { rawValue }
}

enum WordTag: String, Codable, CaseIterable, Hashable {
    case top3000 = "Top 3000"
    case top5000 = "Top 5000"
    case top10000 = "Top 10000"
    case top10000Plus = "10000+"
    case offList = "Off-list"

    var color: Color {
        switch self {
        case .top3000: return .green
        case .top5000: return .blue
        case .top10000: return .orange
        case .top10000Plus: return .red
        case .offList: return .gray
        }
    }
}

struct SubtitleLine: Codable, Hashable, Identifiable {
    var index: Int
    var start: Double
    var end: Double
    var duration: Double
    var text: String

    var id: String {
        "\(index)-\(start)-\(end)"
    }
}

struct LearningRecord: Codable, Hashable {
    var familiarity: Int
    var updatedAt: String
}

struct MaterialRecord: Codable, Hashable, Identifiable {
    var id: String
    var kind: MaterialKind
    var title: String
    var subtitleFileName: String
    var videoFileName: String
    var hasVideo: Bool
    var articleText: String
    var subtitleLines: [SubtitleLine]
    var videoRelativePath: String?
    var subtitleRelativePath: String?
    var lastUsedAt: TimeInterval

    var isArticle: Bool {
        kind == .article
    }
}

struct ReaderProgress: Codable, Hashable {
    var page: Int
    var blockIndex: Int
    var layoutMode: ReaderLayoutMode
    var updatedAt: TimeInterval
}

struct ReaderSessionData: Codable, Hashable {
    var materialID: String?
    var title: String
    var articleText: String
    var page: Int
    var blockIndex: Int
    var layoutMode: ReaderLayoutMode
    var savedAt: TimeInterval
}

struct AppSettings: Codable, Hashable {
    var playbackRate: Double = 1.0
    var subtitleFontScale: Double = 1.25
    var readerFontScale: Double = 1.25
    var readerLineSpacingMultiplier: Double = 1.0
    var readerLayoutMode: ReaderLayoutMode = .single
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case playbackRate
        case subtitleFontScale
        case readerFontScale
        case readerLineSpacingMultiplier
        case readerLayoutMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playbackRate = try container.decodeIfPresent(Double.self, forKey: .playbackRate) ?? 1.0
        let legacyTextScale = try container.decodeIfPresent(Double.self, forKey: .subtitleFontScale) ?? 1.25
        subtitleFontScale = legacyTextScale
        readerFontScale = try container.decodeIfPresent(Double.self, forKey: .readerFontScale) ?? legacyTextScale
        readerLineSpacingMultiplier = try container.decodeIfPresent(Double.self, forKey: .readerLineSpacingMultiplier) ?? 1.0
        readerLayoutMode = try container.decodeIfPresent(ReaderLayoutMode.self, forKey: .readerLayoutMode) ?? .single
    }
}

struct VocabularySession: Hashable {
    var sourceKind: AnalysisSourceKind
    var sourceTitle: String
    var lines: [SubtitleLine]
    var subtitleFileName: String
}

struct AnalysisWordRow: Identifiable, Hashable {
    var word: String
    var count: Int
    var tags: [WordTag]
    var familiarity: Int
    var mastered: Bool
    var updatedAt: String

    var id: String { word }
}

struct TagCountSummary: Hashable {
    var total: Int = 0
    var mastered: Int = 0
    var unmastered: Int = 0
}

struct VocabularyOverview: Hashable {
    var uniqueWords: Int
    var masteredWords: Int
    var tagCounts: [WordTag: TagCountSummary]
}

struct LearningProgressItem: Identifiable, Hashable {
    var label: String
    var title: String
    var total: Int
    var mastered: Int
    var percentage: Double

    var id: String { label }
}

struct LearningStatPoint: Identifiable, Hashable {
    var date: String
    var newWords: Int
    var cumulative: Int

    var id: String { date }
}

struct DifficultyMetric: Identifiable, Hashable {
    var label: String
    var value: String
    var hint: String

    var id: String { label }
}

struct DifficultyComponent: Hashable {
    var score: Int
    var label: String
    var levelKey: String
    var description: String
}

struct DifficultyAssessment: Hashable {
    var sampleLabel: String
    var summary: String
    var objective: DifficultyComponent
    var personal: DifficultyComponent
    var metrics: [DifficultyMetric]
}

struct FamiliarityReviewRow: Identifiable, Hashable {
    var word: String
    var familiarity: Int
    var updatedAt: String
    var tags: [WordTag]

    var id: String { word }
}

struct UnmasteredWordRow: Identifiable, Hashable {
    var word: String

    var id: String { word }
}

struct ArticleReaderUnit: Hashable, Identifiable {
    var key: String
    var text: String
    var paragraphIndex: Int
    var isParagraphStart: Bool
    var sourceIndex: Int
    var splitPartIndex: Int = 0

    var id: String { key }

    var anchorIndex: Int {
        ReaderProgressAnchor.encode(sourceIndex: sourceIndex, splitPartIndex: splitPartIndex)
    }
}

struct ArticlePage: Hashable, Identifiable {
    var index: Int
    var startIndex: Int
    var leftColumn: [ArticleReaderUnit]
    var rightColumn: [ArticleReaderUnit]

    var id: Int { index }
}

struct WordActionContext: Identifiable, Hashable {
    var displayToken: String
    var targetWord: String

    var id: String { "\(displayToken)-\(targetWord)" }
}

enum ReaderProgressAnchor {
    static let splitBase = 100_000

    static func encode(sourceIndex: Int, splitPartIndex: Int) -> Int {
        guard splitPartIndex > 0 else { return sourceIndex }
        return (sourceIndex + 1) * splitBase + splitPartIndex
    }

    static func decodeSourceIndex(_ anchor: Int) -> Int {
        guard anchor >= splitBase else { return anchor }
        return max(0, (anchor / splitBase) - 1)
    }
}

struct PersistedAppState: Hashable {
    var learningRecords: [String: LearningRecord]
    var materials: [MaterialRecord]
    var readerProgress: [String: ReaderProgress]
    var settings: AppSettings
    var readerSession: ReaderSessionData?
}

struct ImportedMaterialFiles: Hashable {
    var videoRelativePath: String?
    var subtitleRelativePath: String?
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}
