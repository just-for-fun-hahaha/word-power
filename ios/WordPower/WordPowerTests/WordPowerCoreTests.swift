import CoreGraphics
import UIKit
import XCTest
@testable import WordPower

@MainActor
final class WordPowerCoreTests: XCTestCase {
    func testBuiltInWordLabelCSVParsesFromAppResourceSource() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../WordPower/Resources/word_labels.csv")
            .standardizedFileURL

        let text = try String(contentsOf: url, encoding: .utf8)
        let labels = WordLabelCatalog.parseCSV(text)

        XCTAssertGreaterThan(labels.count, 1000)
        XCTAssertTrue(Set(labels.values).isSubset(of: Set(WordLabelCatalog.baseLabels)))
    }

    func testLearningDataCurrentCSVRoundTripMatchesWebFormat() throws {
        let records: [String: LearningRecord] = [
            "focus": LearningRecord(familiarity: 3, updatedAt: "2026-03-20"),
            "run": LearningRecord(familiarity: 5, updatedAt: "2026-03-21")
        ]

        let exported = LearningDataCodec.exportCSV(records)
        let parsed = try LearningDataCodec.parseCSV(exported)

        XCTAssertEqual(exported.components(separatedBy: .newlines).first, LearningDataCodec.currentHeader)
        XCTAssertEqual(parsed, LearningDataCodec.normalizeRecords(records))
    }

    func testLegacyMasteredWordsCSVImportsAsFiveStarRecords() throws {
        let csv = """
        word,date
        Alpha,2025-01-03
        Beta,2025-02-14
        """

        let parsed = try LearningDataCodec.parseCSV(csv)

        XCTAssertEqual(parsed["alpha"], LearningRecord(familiarity: 5, updatedAt: "2025-01-03"))
        XCTAssertEqual(parsed["beta"], LearningRecord(familiarity: 5, updatedAt: "2025-02-14"))
    }

    func testAppSettingsDecodesLegacyJSONWithDefaultSidebarState() throws {
        let data = Data(
            """
            {
              "playbackRate": 1.5,
              "subtitleFontScale": 1.75,
              "didDismissWelcome": true
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.playbackRate, 1.5)
        XCTAssertEqual(settings.subtitleFontScale, 1.75)
        XCTAssertEqual(settings.readerFontScale, 1.75)
        XCTAssertEqual(settings.readerLineSpacingMultiplier, 1.0)
        XCTAssertTrue(settings.didDismissWelcome)
        XCTAssertFalse(settings.sidebarCollapsed)
        XCTAssertEqual(settings.readerLayoutMode, .single)
    }

    func testAppSettingsDecodesReaderLayoutModeWhenPresent() throws {
        let data = Data(
            """
            {
              "playbackRate": 1.0,
              "subtitleFontScale": 1.25,
              "readerFontScale": 1.5,
              "readerLineSpacingMultiplier": 1.3,
              "readerLayoutMode": "spread"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.subtitleFontScale, 1.25)
        XCTAssertEqual(settings.readerFontScale, 1.5)
        XCTAssertEqual(settings.readerLineSpacingMultiplier, 1.3)
        XCTAssertEqual(settings.readerLayoutMode, .spread)
    }

    func testFileStoreLoadsLearningRecordsEvenIfSettingsJSONIsLegacy() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let records: [String: LearningRecord] = [
            "focus": LearningRecord(familiarity: 4, updatedAt: "2026-03-29")
        ]
        let recordsData = try JSONEncoder().encode(records)
        try recordsData.write(to: rootURL.appendingPathComponent("learning-records.json"))

        let legacySettingsData = Data(
            """
            {
              "playbackRate": 1.25,
              "subtitleFontScale": 1.5,
              "didDismissWelcome": true
            }
            """.utf8
        )
        try legacySettingsData.write(to: rootURL.appendingPathComponent("settings.json"))

        let store = AppFileStore(rootDirectoryURL: rootURL)
        let state = try await store.loadState()

        XCTAssertEqual(state.learningRecords, records)
        XCTAssertTrue(state.settings.didDismissWelcome)
        XCTAssertFalse(state.settings.sidebarCollapsed)
        XCTAssertEqual(state.settings.subtitleFontScale, 1.5)
        XCTAssertEqual(state.settings.readerFontScale, 1.5)
        XCTAssertEqual(state.settings.readerLineSpacingMultiplier, 1.0)
        XCTAssertEqual(state.settings.readerLayoutMode, .single)
    }

    func testSubtitleParserParsesSRTVTTAndJSON() throws {
        let srt = """
        1
        00:00:01,000 --> 00:00:02,500
        Hello <b>world</b>

        2
        00:00:03,000 --> 00:00:04,200
        We're back.
        """
        let vtt = """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        First line

        00:00:02.500 --> 00:00:04.000
        Second line
        """
        let json = """
        {
          "lines": [
            { "start": 0.0, "end": 1.5, "text": "Alpha" },
            { "start": 1.5, "duration": 1.0, "text": "Beta" }
          ]
        }
        """

        let srtLines = try SubtitleParser.parse(text: srt, fileName: "sample.srt")
        let vttLines = try SubtitleParser.parse(text: vtt, fileName: "sample.vtt")
        let jsonLines = try SubtitleParser.parse(text: json, fileName: "sample.json")

        XCTAssertEqual(srtLines.map(\.text), ["Hello world", "We're back."])
        XCTAssertEqual(vttLines.map(\.text), ["First line", "Second line"])
        XCTAssertEqual(jsonLines.map(\.text), ["Alpha", "Beta"])
        XCTAssertEqual(jsonLines[1].end, 2.5, accuracy: 0.001)
    }

    func testResolvedSubtitleIndexMatchesExistingPlaybackSelectionSemantics() {
        let lines = [
            subtitleLine(index: 0, start: 1.0, end: 2.0, text: "Alpha"),
            subtitleLine(index: 1, start: 3.0, end: 4.0, text: "Beta"),
            subtitleLine(index: 2, start: 6.0, end: 7.0, text: "Gamma")
        ]

        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 0.9, in: lines), -1)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 1.0, in: lines), 0)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 1.8, in: lines), 0)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 2.5, in: lines), 0)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 3.0, in: lines), 1)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 5.2, in: lines), 1)
        XCTAssertEqual(PlayerController.resolvedSubtitleIndex(for: 7.5, in: lines), 2)
    }

    func testTokenizerExpandsContractionsAndRespectsHyphenPrefixes() {
        let words = WordPowerText.extractWords(from: "We're re-entering co-operative spaces and can't stop.")

        XCTAssertEqual(words, ["we", "are", "entering", "operative", "spaces", "and", "can", "not", "stop"])
    }

    func testDecodeHTMLEntitiesSkipsPlainTextSymbolsButDecodesRealEntities() {
        XCTAssertEqual(
            WordPowerText.decodeHTMLEntities("2 < 3 & 4 > 1"),
            "2 < 3 & 4 > 1"
        )
        XCTAssertEqual(
            WordPowerText.decodeHTMLEntities("Tom &amp; Jerry"),
            "Tom & Jerry"
        )
    }

    func testSimpleLemmatizerNormalizesCommonWordForms() {
        let catalog = WordLabelCatalog(labels: [
            "box": "5000",
            "make": "3000",
            "run": "3000",
            "study": "5000"
        ])

        XCTAssertEqual(WordPowerText.simpleLemmatize("running", catalog: catalog, learningRecords: [:], contextWords: []), "run")
        XCTAssertEqual(WordPowerText.simpleLemmatize("studies", catalog: catalog, learningRecords: [:], contextWords: []), "study")
        XCTAssertEqual(WordPowerText.simpleLemmatize("boxes", catalog: catalog, learningRecords: [:], contextWords: []), "box")
        XCTAssertEqual(WordPowerText.simpleLemmatize("making", catalog: catalog, learningRecords: [:], contextWords: []), "make")
    }

    func testCoverageStatsReflectTagsAndMasteredWords() {
        let catalog = WordLabelCatalog(labels: [
            "focus": "5000",
            "rare": "10000",
            "run": "3000"
        ])
        let learningRecords = [
            "run": LearningRecord(familiarity: 5, updatedAt: "2026-03-01")
        ]
        let lines = [
            subtitleLine(index: 0, text: "Running focus rare")
        ]

        let coverage = TextAnalysis.buildCoverageStats(lines: lines, catalog: catalog, learningRecords: learningRecords)

        XCTAssertEqual(coverage.top3000, 33.333, accuracy: 0.01)
        XCTAssertEqual(coverage.top5000, 66.667, accuracy: 0.01)
        XCTAssertEqual(coverage.mastered, 33.333, accuracy: 0.01)
    }

    func testDifficultyAssessmentProducesStableMetrics() {
        let catalog = WordLabelCatalog(labels: [
            "anchor": "3000",
            "build": "5000",
            "context": "10000",
            "rare": "10000",
            "shadow": "5000"
        ])
        let learningRecords = [
            "anchor": LearningRecord(familiarity: 5, updatedAt: "2026-03-01")
        ]
        let lines = [
            subtitleLine(index: 0, start: 0, end: 4, text: "Anchor build rare context"),
            subtitleLine(index: 1, start: 5, end: 9, text: "Shadow build rare"),
            subtitleLine(index: 2, start: 10, end: 14, text: "Rare context shadow")
        ]

        let assessment = TextAnalysis.buildDifficultyAssessment(lines: lines, catalog: catalog, learningRecords: learningRecords)

        XCTAssertNotNil(assessment)
        XCTAssertEqual(assessment?.metrics.count, 3)
        XCTAssertFalse(assessment?.summary.isEmpty ?? true)
        XCTAssertTrue((assessment?.objective.score ?? -1) >= 0)
        XCTAssertTrue((assessment?.personal.score ?? -1) >= 0)
    }

    func testArticlePaginatorSplitsParagraphsIntoPages() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu. ", count: 18),
            String(repeating: "Nu xi omicron pi rho sigma tau upsilon phi chi psi omega. ", count: 18),
            String(repeating: "Crimson amber cobalt silver violet bronze ivory charcoal azure jade. ", count: 16)
        ]

        let singlePages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .single,
            containerSize: CGSize(width: 820, height: 560),
            fontScale: 1.25
        )
        let spreadPages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .spread,
            containerSize: CGSize(width: 1080, height: 680),
            fontScale: 1.25
        )

        XCTAssertFalse(singlePages.isEmpty)
        XCTAssertFalse(spreadPages.isEmpty)
        XCTAssertGreaterThan(singlePages.count, 1)
        XCTAssertTrue(spreadPages.contains { !$0.rightColumn.isEmpty })
    }

    func testArticlePaginatorPreservesReaderUnitOrderAcrossPages() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu. ", count: 10),
            String(repeating: "One two three four five six seven eight nine ten eleven twelve. ", count: 10),
            String(repeating: "Red blue green yellow black white orange purple silver gold bronze. ", count: 10)
        ]
        let expectedText = WordPowerText.buildArticleReaderUnits(paragraphs: paragraphs)
            .map(\.text)
            .joined(separator: " ")
        let scenarios: [(layout: ReaderLayoutMode, size: CGSize)] = [
            (.single, CGSize(width: 900, height: 700)),
            (.spread, CGSize(width: 1200, height: 800))
        ]

        for scenario in scenarios {
            let pages = ArticlePaginator.paginate(
                paragraphs: paragraphs,
                layoutMode: scenario.layout,
                containerSize: scenario.size,
                fontScale: 1.25
            )
            let actualText = pages
                .flatMap { $0.leftColumn + $0.rightColumn }
                .map(\.text)
                .joined(separator: " ")

            XCTAssertEqual(actualText, expectedText, "layout: \(scenario.layout.rawValue)")
        }
    }

    func testArticlePaginatorUsesActualHeightBudgetInSingleColumnMode() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu. ", count: 16),
            String(repeating: "Nu xi omicron pi rho sigma tau upsilon phi chi psi omega. ", count: 16),
            String(repeating: "Crimson amber cobalt silver violet bronze ivory charcoal azure jade. ", count: 16)
        ]
        let containerSize = CGSize(width: 860, height: 560)
        let fontScale = 1.5
        let lineHeightMultiple: CGFloat = 1.3

        let pages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .single,
            containerSize: containerSize,
            fontScale: fontScale,
            lineHeightMultiple: lineHeightMultiple
        )

        assertColumnsUseAvailableHeight(
            pages.map(\.leftColumn),
            containerSize: containerSize,
            layoutMode: .single,
            fontScale: fontScale,
            lineHeightMultiple: lineHeightMultiple
        )
    }

    func testArticlePaginatorSplitsOversizedReaderUnitsForSpreadLayout() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu ", count: 30),
            String(repeating: "Nu xi omicron pi rho sigma tau upsilon phi chi psi omega ", count: 30)
        ]
        let containerSize = CGSize(width: 940, height: 420)
        let fontScale = 1.75
        let lineHeightMultiple: CGFloat = 1.5

        let pages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .spread,
            containerSize: containerSize,
            fontScale: fontScale,
            lineHeightMultiple: lineHeightMultiple
        )
        let columns = pages.flatMap { page in
            [page.leftColumn, page.rightColumn].filter { !$0.isEmpty }
        }

        XCTAssertTrue(columns.contains { $0.contains(where: { $0.splitPartIndex > 0 }) })
        assertColumnsUseAvailableHeight(
            columns,
            containerSize: containerSize,
            layoutMode: .spread,
            fontScale: fontScale,
            lineHeightMultiple: lineHeightMultiple
        )
    }

    func testArticlePaginatorSplitsAcrossSingleColumnPagesWhenRemainingHeightIsTight() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa. ", count: 2),
            String(repeating: "Lambda mu nu xi omicron pi rho sigma tau upsilon. ", count: 7)
        ]

        let pages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .single,
            containerSize: CGSize(width: 620, height: 320),
            fontScale: 1.45,
            lineHeightMultiple: 1.2
        )

        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertEqual(pages[0].leftColumn.last?.sourceIndex, 1)
        XCTAssertEqual(pages[1].leftColumn.first?.sourceIndex, 1)
        XCTAssertLessThan(
            pages[0].leftColumn.last?.splitPartIndex ?? .max,
            pages[1].leftColumn.first?.splitPartIndex ?? .min
        )
    }

    func testArticlePaginatorSplitsAcrossSpreadColumnsToBalanceFill() {
        let paragraphs = [
            String(repeating: "Alpha beta gamma delta epsilon zeta eta theta iota kappa. ", count: 3),
            String(repeating: "Lambda mu nu xi omicron pi rho sigma tau upsilon. ", count: 8)
        ]

        let pages = ArticlePaginator.paginate(
            paragraphs: paragraphs,
            layoutMode: .spread,
            containerSize: CGSize(width: 980, height: 420),
            fontScale: 1.35,
            lineHeightMultiple: 1.2
        )

        guard let firstSpreadPage = pages.first(where: { !$0.rightColumn.isEmpty }) else {
            XCTFail("Expected at least one spread page with both columns populated.")
            return
        }

        XCTAssertEqual(firstSpreadPage.leftColumn.last?.sourceIndex, firstSpreadPage.rightColumn.first?.sourceIndex)
        XCTAssertLessThan(
            firstSpreadPage.leftColumn.last?.splitPartIndex ?? .max,
            firstSpreadPage.rightColumn.first?.splitPartIndex ?? .min
        )
    }

    func testPlayerControllerBuildsABCopyTextFromSelectedSubtitleRange() {
        let controller = PlayerController()
        controller.subtitleLines = [
            subtitleLine(index: 0, text: "Alpha"),
            subtitleLine(index: 1, text: "Beta"),
            subtitleLine(index: 2, text: "Gamma")
        ]
        controller.abStartIndex = 0
        controller.abEndIndex = 2

        XCTAssertEqual(controller.copyableABText(), "Alpha Beta Gamma")
    }

    func testReaderHighlightStyleUsesSimplifiedRedAndYellowBackgroundsWithoutUnderline() {
        let catalog = WordLabelCatalog(labels: [
            "novel": "10000",
            "alpha": "3000",
            "beta": "3000",
            "gamma": "3000",
            "delta": "3000",
            "mastered": "3000"
        ])
        let learningRecords = [
            "alpha": LearningRecord(familiarity: 1, updatedAt: "2026-03-01"),
            "beta": LearningRecord(familiarity: 2, updatedAt: "2026-03-01"),
            "gamma": LearningRecord(familiarity: 3, updatedAt: "2026-03-01"),
            "delta": LearningRecord(familiarity: 4, updatedAt: "2026-03-01"),
            "mastered": LearningRecord(familiarity: 5, updatedAt: "2026-03-01")
        ]
        let text = "Novel alpha beta gamma delta mastered"
        let attributed = HighlightTextBuilder.makeAttributedText(
            text: text,
            contextWords: ["novel", "alpha", "beta", "gamma", "delta", "mastered"],
            catalog: catalog,
            learningRecords: learningRecords,
            font: UIFont.preferredFont(forTextStyle: .body),
            lineSpacing: 0,
            highlightStyle: .reader
        )
        let nsText = text as NSString

        let unknownBackground = backgroundColor(in: attributed, token: "Novel", source: nsText)
        let oneStarBackground = backgroundColor(in: attributed, token: "alpha", source: nsText)
        let twoStarBackground = backgroundColor(in: attributed, token: "beta", source: nsText)
        let threeStarBackground = backgroundColor(in: attributed, token: "gamma", source: nsText)
        let fourStarBackground = backgroundColor(in: attributed, token: "delta", source: nsText)

        XCTAssertNotNil(unknownBackground)
        XCTAssertNotNil(oneStarBackground)
        XCTAssertNotNil(twoStarBackground)
        XCTAssertNotNil(threeStarBackground)
        XCTAssertNotNil(fourStarBackground)
        XCTAssertNil(backgroundColor(in: attributed, token: "mastered", source: nsText))

        XCTAssertFalse(hasUnderline(in: attributed, token: "Novel", source: nsText))
        XCTAssertFalse(hasUnderline(in: attributed, token: "alpha", source: nsText))

        XCTAssertGreaterThan(brightness(of: oneStarBackground), 0)
        XCTAssertLessThan(brightness(of: oneStarBackground), brightness(of: twoStarBackground))
        XCTAssertLessThan(brightness(of: twoStarBackground), brightness(of: threeStarBackground))
        XCTAssertLessThan(brightness(of: threeStarBackground), brightness(of: fourStarBackground))
    }

    private func subtitleLine(
        index: Int,
        start: Double = 0,
        end: Double = 1,
        text: String
    ) -> SubtitleLine {
        SubtitleLine(index: index, start: start, end: end, duration: max(0.1, end - start), text: text)
    }

    private func assertColumnsUseAvailableHeight(
        _ columns: [[ArticleReaderUnit]],
        containerSize: CGSize,
        layoutMode: ReaderLayoutMode,
        fontScale: Double,
        lineHeightMultiple: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let layout = ArticlePaginator.layout(for: containerSize, layoutMode: layoutMode) else {
            XCTFail("Expected a valid pagination layout", file: file, line: line)
            return
        }

        for (index, units) in columns.enumerated() {
            let columnHeight = measuredColumnHeight(
                units,
                width: layout.columnWidth,
                fontScale: fontScale,
                lineHeightMultiple: lineHeightMultiple
            )
            XCTAssertLessThanOrEqual(columnHeight, layout.columnHeight + 1, file: file, line: line)

            guard index < columns.count - 1, let nextUnit = columns[index + 1].first else { continue }
            let nextUnitHeight = measuredUnitHeight(
                nextUnit,
                width: layout.columnWidth,
                fontScale: fontScale,
                lineHeightMultiple: lineHeightMultiple
            )
            let nextTopPadding = units.isEmpty
                ? 0
                : (nextUnit.isParagraphStart
                    ? ArticlePaginationMetrics.paragraphTopPadding
                    : ArticlePaginationMetrics.chunkTopPadding)

            XCTAssertGreaterThan(
                columnHeight + nextTopPadding + nextUnitHeight,
                layout.columnHeight,
                "column \(index) left too much usable space",
                file: file,
                line: line
            )
        }
    }

    private func measuredColumnHeight(
        _ units: [ArticleReaderUnit],
        width: CGFloat,
        fontScale: Double,
        lineHeightMultiple: CGFloat
    ) -> CGFloat {
        units.enumerated().reduce(CGFloat.zero) { height, item in
            let topPadding: CGFloat
            if item.offset == 0 {
                topPadding = 0
            } else {
                topPadding = item.element.isParagraphStart
                    ? ArticlePaginationMetrics.paragraphTopPadding
                    : ArticlePaginationMetrics.chunkTopPadding
            }

            return height + topPadding + measuredUnitHeight(
                item.element,
                width: width,
                fontScale: fontScale,
                lineHeightMultiple: lineHeightMultiple
            )
        }
    }

    private func measuredUnitHeight(
        _ unit: ArticleReaderUnit,
        width: CGFloat,
        fontScale: Double,
        lineHeightMultiple: CGFloat
    ) -> CGFloat {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let font = baseFont.withSize(baseFont.pointSize * fontScale)
        let attributedText = HighlightTextBuilder.baseAttributedText(
            text: unit.text,
            font: font,
            lineSpacing: ArticlePaginationMetrics.lineSpacing,
            lineHeightMultiple: lineHeightMultiple
        )
        return HighlightTextBuilder.measureHeight(for: attributedText, width: width)
    }

    private func backgroundColor(in attributed: NSAttributedString, token: String, source: NSString) -> UIColor? {
        let range = source.range(of: token)
        guard range.location != NSNotFound else { return nil }
        return attributed.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
    }

    private func hasUnderline(in attributed: NSAttributedString, token: String, source: NSString) -> Bool {
        let range = source.range(of: token)
        guard range.location != NSNotFound else { return false }
        return (attributed.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int) != nil
    }

    private func brightness(of color: UIColor?) -> CGFloat {
        guard let color else { return 0 }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return red * 0.299 + green * 0.587 + blue * 0.114
    }
}
