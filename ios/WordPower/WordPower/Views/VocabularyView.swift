import SwiftUI

struct VocabularyView: View {
    @ObservedObject var appModel: AppModel

    @State private var selectedProgressItem: ProgressSheetItem?
    @State private var wordSearchText = ""

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth
    private let progressCardMinHeight: CGFloat = 112
    private let overviewCardMinHeight: CGFloat = 118
    private let compactMetricColumns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        count: 2
    )

    private var normalizedWordSearchText: String {
        wordSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private var filteredAnalysisRows: [AnalysisWordRow] {
        guard !normalizedWordSearchText.isEmpty else {
            return appModel.currentAnalysisRows
        }

        return appModel.currentAnalysisRows.filter { row in
            row.word
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .hasPrefix(normalizedWordSearchText)
        }
    }

    var body: some View {
        Group {
            if appModel.currentVocabularySession == nil {
                EmptyStateView(
                    title: "No vocabulary analysis yet",
                    message: "Open a material in Player or Reader, then enter vocabulary analysis from there.",
                    systemImage: "textformat.abc"
                )
            } else {
                content
            }
        }
        .sheet(item: $selectedProgressItem) { item in
            NavigationStack {
                UnmasteredWordsSheet(appModel: appModel, label: item.label)
            }
            .presentationSizing(.page)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let assessment = appModel.currentDifficultyAssessment {
                    difficultySection(assessment: assessment)
                }
                learningProgressSection
                overviewSection
                wordListSection
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.currentVocabularySession?.sourceTitle ?? "Word List")
                .font(.title2.weight(.semibold))
        }
    }

    private var learningProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Learning Progress")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(appModel.learningProgressItems) { item in
                        progressCard(item)
                            .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: compactMetricColumns, spacing: 12) {
                    ForEach(appModel.learningProgressItems) { item in
                        progressCard(item)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        let overview = appModel.currentVocabularyOverview
        let trackedTags: [WordTag] = [.top3000, .top5000, .top10000]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    overviewSummaryCard(overview)
                    ForEach(trackedTags, id: \.self) { tag in
                        overviewBandCard(
                            tag: tag,
                            summary: overview.tagCounts[tag] ?? TagCountSummary(),
                            isSelected: appModel.selectedVocabularyTag == tag
                        )
                    }
                }

                LazyVGrid(columns: compactMetricColumns, spacing: 12) {
                    overviewSummaryCard(overview)
                    ForEach(trackedTags, id: \.self) { tag in
                        overviewBandCard(
                            tag: tag,
                            summary: overview.tagCounts[tag] ?? TagCountSummary(),
                            isSelected: appModel.selectedVocabularyTag == tag
                        )
                    }
                }
            }
        }
    }

    private func difficultySection(assessment: DifficultyAssessment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DifficultyCardView(title: "Objective Difficulty", component: assessment.objective)
            DifficultyCardView(title: "Difficulty for Me", component: assessment.personal)
        }
    }

    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    Text("Word List")
                        .font(.headline)

                    Spacer(minLength: 0)

                    wordSearchField
                        .frame(width: 240)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Word List")
                        .font(.headline)

                    wordSearchField
                }
            }

            if filteredAnalysisRows.isEmpty {
                wordListEmptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredAnalysisRows) { row in
                        wordListCard(row)
                    }
                }
            }
        }
    }

    private var wordSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("", text: $wordSearchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel("Search vocabulary")
    }

    private var wordListEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No matching words")
                .font(.subheadline.weight(.semibold))
            Text("Try a different prefix.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func progressCard(_ item: LearningProgressItem) -> some View {
        Button {
            selectedProgressItem = ProgressSheetItem(label: item.label)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.mastered)/\(item.total)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(String(format: "%.1f%%", item.percentage))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: item.percentage, total: 100)

                Text("\(item.mastered) mastered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: progressCardMinHeight, alignment: .topLeading)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func wordListCard(_ row: AnalysisWordRow) -> some View {
        HStack(alignment: .center, spacing: 28) {
            Text(row.word)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 12) {
                vocabularyTagButton(for: row)

                if row.count > 1 {
                    Text("\(row.count)x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(width: 220, alignment: .leading)

            HStack {
                Spacer(minLength: 0)
                StarRatingControl(value: row.familiarity) { newValue in
                    appModel.updateFamiliarity(for: row.word, familiarity: newValue)
                }
            }
            .frame(width: 140, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func vocabularyTagButton(for row: AnalysisWordRow) -> some View {
        let primaryTag = row.tags.first ?? .offList

        return Button {
            appModel.selectedVocabularyTag = appModel.selectedVocabularyTag == primaryTag ? nil : primaryTag
        } label: {
            Text(primaryTag.rawValue)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(primaryTag.color.opacity(0.14), in: Capsule())
                .foregroundStyle(primaryTag.color)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func overviewSummaryCard(_ overview: VocabularyOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(overview.uniqueWords)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mastered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(overview.masteredWords)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: overviewCardMinHeight, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func overviewBandCard(tag: WordTag, summary: TagCountSummary, isSelected: Bool) -> some View {
        Button {
            appModel.selectedVocabularyTag = isSelected ? nil : tag
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(tag.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("\(summary.total)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: overviewCardMinHeight, alignment: .topLeading)
            .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? tag.color : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

}

private struct DifficultyCardView: View {
    let title: String
    let component: DifficultyComponent

    @State private var isShowingDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Button {
                        isShowingDescription = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isShowingDescription) {
                        Text(component.description)
                            .font(.body)
                            .padding(16)
                            .frame(width: 280, alignment: .leading)
                    }
                }

                Spacer(minLength: 12)

                Text(component.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            Text("\(component.score)%")
                .font(.largeTitle.weight(.bold))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ProgressSheetItem: Identifiable {
    let label: String

    var id: String { label }
}

private struct UnmasteredWordsSheet: View {
    @ObservedObject var appModel: AppModel
    let label: String

    @State private var currentPage = 1

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        count: 5
    )
    private let pageSize = 60

    private var rows: [UnmasteredWordRow] {
        TextAnalysis.buildUnmasteredWords(label: label, catalog: appModel.wordCatalog, learningRecords: appModel.learningRecords)
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(rows.count) / Double(pageSize))))
    }

    private var pageRows: [UnmasteredWordRow] {
        guard !rows.isEmpty else { return [] }
        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(rows.count, startIndex + pageSize)
        guard startIndex < endIndex else { return [] }
        return Array(rows[startIndex..<endIndex])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if rows.isEmpty {
                    EmptyStateView(
                        title: "No words below 5 stars",
                        message: "Everything in this band is already mastered.",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    HStack {
                        Text("\(rows.count) words")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy List") {
                            UIPasteboard.general.string = rows.map(\.word).joined(separator: "\n")
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 10) {
                        Button {
                            currentPage = max(1, currentPage - 1)
                        } label: {
                            Label("Prev", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentPage <= 1)

                        Menu {
                            ForEach(1...totalPages, id: \.self) { page in
                                Button("Page \(page)") {
                                    currentPage = page
                                }
                            }
                        } label: {
                            Label("Page \(currentPage)/\(totalPages)", systemImage: "rectangle.grid.1x2")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            currentPage = min(totalPages, currentPage + 1)
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentPage >= totalPages)

                        Spacer()
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pageRows) { row in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(row.word)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                StarRatingControl(value: familiarity(for: row.word)) { newValue in
                                    appModel.updateFamiliarity(for: row.word, familiarity: newValue)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .padding(14)
                            .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: rows.count) { _, _ in
            currentPage = min(currentPage, totalPages)
        }
        .navigationTitle(label == WordLabelCatalog.fallbackLabel ? WordLabelCatalog.fallbackLabel : "Top \(label)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func familiarity(for word: String) -> Int {
        TextAnalysis.wordFamiliarity(word, learningRecords: appModel.learningRecords)
    }
}
