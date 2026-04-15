import SwiftUI
import UIKit

struct ReaderView: View {
    @ObservedObject var appModel: AppModel

    @State private var pages: [ArticlePage] = []
    @State private var articleParagraphs: [String] = []
    @State private var articleAnalysisLines: [SubtitleLine] = []
    @State private var articleContextWords: Set<String> = []
    @State private var articleCoverage: (top3000: Double, top5000: Double, mastered: Double) = (0, 0, 0)
    @State private var articleContentVersion = 0
    @State private var renderedPageText: [String: NSAttributedString] = [:]
    @State private var renderedPageIndex: Int?
    @State private var isShowingMaterialPicker = false

    private let outerPadding: CGFloat = AppLayout.pagePadding
    private let bottomPadding: CGFloat = ReaderLayoutMetrics.bottomScreenPadding
    private let readerEdgeWidth: CGFloat = 56
    private let readerSpacing: CGFloat = 12
    private let contentMaxWidth: CGFloat = AppLayout.readerContentMaxWidth
    private let headerSpacing: CGFloat = 12
    init(appModel: AppModel) {
        _appModel = ObservedObject(wrappedValue: appModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = boundedContentWidth(for: proxy.size)

            Group {
                if appModel.currentArticleText.isEmpty {
                    MaterialOpenPromptView(
                        title: "No article loaded",
                        message: "Open an imported article from your local library to start reading.",
                        systemImage: "book",
                        buttonTitle: "Open Material"
                    ) {
                        isShowingMaterialPicker = true
                    }
                } else {
                    content
                }
            }
            .frame(maxWidth: contentWidth, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, outerPadding)
            .padding(.top, outerPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .task(id: articleSourceContext) {
                refreshArticleData()
            }
            .onChange(of: appModel.learningRecords) { _, _ in
                refreshArticleCoverage()
                refreshRenderedPage(force: true)
            }
            .onChange(of: appModel.currentReaderPage) { _, _ in
                refreshRenderedPage()
            }
            .sheet(isPresented: $isShowingMaterialPicker) {
                MaterialLibraryPickerSheet(
                    appModel: appModel,
                    kind: .article,
                    title: "Choose Article"
                )
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            header
            readerViewport
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerTitle(singleLine: false)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    headerMetrics
                    Spacer(minLength: 0)
                    headerActions
                }

                VStack(alignment: .leading, spacing: 12) {
                    headerMetrics
                    headerActions
                }
            }
        }
    }

    private func headerTitle(singleLine: Bool) -> some View {
        Text(appModel.currentArticleTitle.isEmpty ? "Untitled Article" : appModel.currentArticleTitle)
            .font(.title3.weight(.semibold))
            .lineLimit(singleLine ? 1 : 2)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: !singleLine)
    }

    private var headerMetrics: some View {
        HStack(spacing: 10) {
            ForEach(coverageMetrics, id: \.title) { metric in
                summaryChip(title: metric.title, value: metric.value)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            layoutToggleButton
            pageMenu
            vocabularyButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var coverageMetrics: [(title: String, value: String)] {
        [
            ("Top 3000", percentageLabel(articleCoverage.top3000)),
            ("Top 5000", percentageLabel(articleCoverage.top5000)),
            ("Mastered", percentageLabel(articleCoverage.mastered))
        ]
    }

    private var pageMenu: some View {
        Menu {
            ForEach(pages, id: \.index) { page in
                Button("Page \(page.index)") {
                    setPage(page.index)
                }
            }
        } label: {
            Text("Page \(appModel.currentReaderPage) of \(max(1, pages.count))")
        }
        .buttonStyle(.bordered)
        .disabled(pages.isEmpty)
    }

    private var layoutToggleButton: some View {
        Button(nextLayoutButtonTitle, action: toggleReaderLayout)
            .buttonStyle(.bordered)
            .accessibilityLabel(layoutAccessibilityLabel)
            .help(layoutAccessibilityLabel)
    }

    private var vocabularyButton: some View {
        Button("Vocabulary") {
            appModel.analyzeCurrentArticle()
        }
        .buttonStyle(.bordered)
    }

    private var nextLayoutButtonTitle: String {
        appModel.currentReaderLayoutMode == .single ? "2P" : "1P"
    }

    private var layoutAccessibilityLabel: String {
        appModel.currentReaderLayoutMode == .single
            ? "Switch to two-page layout"
            : "Switch to one-page layout"
    }

    private func readerPage(page: ArticlePage) -> some View {
        HStack(alignment: .top, spacing: appModel.currentReaderLayoutMode == .spread ? ReaderLayoutMetrics.spreadColumnGap : 0) {
            readerColumn(units: page.leftColumn)

            if appModel.currentReaderLayoutMode == .spread {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.06),
                                Color.primary.opacity(0.16),
                                Color.primary.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: ReaderLayoutMetrics.spreadDividerWidth)

                readerColumn(units: page.rightColumn)
            }
        }
        .padding(ReaderLayoutMetrics.pageContentPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.readerPanelBackground, in: RoundedRectangle(cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func readerColumn(units: [ArticleReaderUnit]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                InteractiveTextView(attributedText: attributedText(for: unit)) { context in
                    appModel.presentWordAction(displayToken: context.displayToken, targetWord: context.targetWord)
                }
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, index == 0 ? 0 : (unit.isParagraphStart ? 8 : 4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var selectedPage: ArticlePage? {
        pages.first(where: { $0.index == appModel.currentReaderPage }) ?? pages.first
    }

    private var articleSourceContext: ReaderArticleSourceContext {
        ReaderArticleSourceContext(
            materialID: appModel.currentArticleID,
            title: appModel.currentArticleTitle,
            textCount: appModel.currentArticleText.count
        )
    }

    private func navigationButton(
        title: String,
        systemImage: String,
        shortcut: KeyEquivalent,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.45) : Color.secondary)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(disabled ? 0.04 : 0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: readerEdgeWidth)
        .frame(maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .disabled(disabled)
        .keyboardShortcut(shortcut, modifiers: [])
        .accessibilityLabel(title)
        .help(title)
    }

    private func summaryChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.readerSecondaryBackground, in: RoundedRectangle(cornerRadius: 16))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func recalculatePages(using size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        pages = ArticlePaginator.paginate(
            paragraphs: articleParagraphs,
            layoutMode: appModel.currentReaderLayoutMode,
            containerSize: size,
            fontScale: appModel.currentReaderFontScale,
            lineHeightMultiple: CGFloat(appModel.currentReaderLineSpacingMultiplier)
        )

        guard !pages.isEmpty else {
            renderedPageText.removeAll()
            renderedPageIndex = nil
            return
        }
        let currentPage = ArticlePaginator.clampPage(
            ArticlePaginator.pageIndex(for: appModel.currentReaderBlockIndex, pages: pages),
            totalPages: pages.count
        )
        setPage(currentPage)
    }

    private var readerViewport: some View {
        GeometryReader { proxy in
            let pageSize = availablePageSize(for: proxy.size)
            let paginationContext = ReaderPaginationContext(
                articleContentVersion: articleContentVersion,
                layoutMode: appModel.currentReaderLayoutMode,
                fontScale: appModel.currentReaderFontScale,
                lineSpacingMultiplier: appModel.currentReaderLineSpacingMultiplier,
                pageSize: pageSize
            )

            Group {
                if let currentPage = selectedPage {
                    HStack(alignment: .top, spacing: readerSpacing) {
                        navigationButton(
                            title: "Previous Page",
                            systemImage: "chevron.left",
                            shortcut: .leftArrow,
                            disabled: currentPage.index <= 1,
                            action: goToPreviousPage
                        )

                        readerPage(page: currentPage)

                        navigationButton(
                            title: "Next Page",
                            systemImage: "chevron.right",
                            shortcut: .rightArrow,
                            disabled: currentPage.index >= pages.count,
                            action: goToNextPage
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: pageSize.height, alignment: .top)
                } else {
                    EmptyStateView(
                        title: "No readable pages",
                        message: "The current article is empty after normalization.",
                        systemImage: "doc.text"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .task(id: paginationContext) {
                recalculatePages(using: pageSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func availablePageSize(for size: CGSize) -> CGSize {
        CGSize(
            width: max(0, floor(size.width - (readerEdgeWidth * 2) - (readerSpacing * 2))),
            height: max(0, floor(size.height))
        )
    }

    private func boundedContentWidth(for size: CGSize) -> CGFloat {
        max(320, min(size.width - outerPadding * 2, contentMaxWidth))
    }

    private func goToPreviousPage() {
        setPage(appModel.currentReaderPage - 1)
    }

    private func goToNextPage() {
        setPage(appModel.currentReaderPage + 1)
    }

    private func toggleReaderLayout() {
        let nextMode: ReaderLayoutMode = appModel.currentReaderLayoutMode == .single ? .spread : .single
        appModel.updateReaderLayoutMode(nextMode)
    }

    private func setPage(_ page: Int) {
        guard !pages.isEmpty else { return }
        let clampedPage = ArticlePaginator.clampPage(page, totalPages: pages.count)
        guard let selectedPage = pages.first(where: { $0.index == clampedPage }) else { return }
        rebuildRenderedPage(for: selectedPage)
        appModel.updateReaderPosition(page: selectedPage.index, blockIndex: selectedPage.startIndex)
    }

    private func scaledBodyFont(scale: Double) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        return baseFont.withSize(baseFont.pointSize * scale)
    }

    private func attributedText(for unit: ArticleReaderUnit) -> NSAttributedString {
        renderedPageText[unit.id] ?? makeAttributedText(for: unit)
    }

    private func refreshArticleData() {
        let paragraphs = WordPowerText.splitArticleIntoParagraphs(appModel.currentArticleText)
        guard !paragraphs.isEmpty else {
            articleParagraphs = []
            articleAnalysisLines = []
            articleContextWords = []
            articleCoverage = (0, 0, 0)
            articleContentVersion += 1
            pages = []
            renderedPageText.removeAll()
            renderedPageIndex = nil
            return
        }

        articleParagraphs = paragraphs
        articleAnalysisLines = WordPowerText.buildArticleAnalysisLines(paragraphs: paragraphs)
        articleContextWords = Set(paragraphs.flatMap { WordPowerText.extractWords(from: $0) })
        articleContentVersion += 1
        refreshArticleCoverage()
    }

    private func refreshArticleCoverage() {
        articleCoverage = TextAnalysis.buildCoverageStats(
            lines: articleAnalysisLines,
            catalog: appModel.wordCatalog,
            learningRecords: appModel.learningRecords
        )
    }

    private func refreshRenderedPage(force: Bool = false) {
        guard let selectedPage else {
            renderedPageText.removeAll()
            renderedPageIndex = nil
            return
        }
        guard force || renderedPageIndex != selectedPage.index else { return }
        rebuildRenderedPage(for: selectedPage)
    }

    private func rebuildRenderedPage(for page: ArticlePage) {
        let units = page.leftColumn + page.rightColumn
        renderedPageIndex = page.index
        renderedPageText = Dictionary(uniqueKeysWithValues: units.map { unit in
            (unit.id, makeAttributedText(for: unit))
        })
    }

    private func makeAttributedText(for unit: ArticleReaderUnit) -> NSAttributedString {
        HighlightTextBuilder.makeAttributedText(
            text: unit.text,
            contextWords: articleContextWords,
            catalog: appModel.wordCatalog,
            learningRecords: appModel.learningRecords,
            font: scaledBodyFont(scale: appModel.currentReaderFontScale),
            lineSpacing: 0,
            lineHeightMultiple: CGFloat(appModel.currentReaderLineSpacingMultiplier),
            highlightStyle: .reader
        )
    }

    private func percentageLabel(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

private struct ReaderPaginationContext: Equatable {
    let articleContentVersion: Int
    let layoutMode: ReaderLayoutMode
    let fontScale: Double
    let lineSpacingMultiplier: Double
    let pageSize: CGSize
}

private struct ReaderArticleSourceContext: Equatable {
    let materialID: String?
    let title: String
    let textCount: Int
}
