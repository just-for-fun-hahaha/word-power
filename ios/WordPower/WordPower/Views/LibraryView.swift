import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var appModel: AppModel

    @State private var errorMessage = ""
    @State private var selectionMode = false
    @State private var selectedMaterialIDs: Set<String> = []
    @State private var isShowingImportSheet = false

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth

    private var videoCount: Int {
        appModel.materials.filter { $0.kind == .video }.count
    }

    private var articleCount: Int {
        appModel.materials.filter { $0.kind == .article }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LibraryHeaderSection(importAction: showImportSheet)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        LibrarySummaryTile(title: "All Materials", value: "\(appModel.materials.count)")
                        LibrarySummaryTile(title: "Videos", value: "\(videoCount)")
                        LibrarySummaryTile(title: "Articles", value: "\(articleCount)")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        LibrarySummaryTile(title: "All Materials", value: "\(appModel.materials.count)")
                        LibrarySummaryTile(title: "Videos", value: "\(videoCount)")
                        LibrarySummaryTile(title: "Articles", value: "\(articleCount)")
                    }
                }

                libraryListSection
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $isShowingImportSheet) {
            LibraryImportSheet(appModel: appModel)
                .presentationSizing(.page)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Library", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var libraryListSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    listHeader
                    Spacer(minLength: 0)
                    listActions
                }

                VStack(alignment: .leading, spacing: 14) {
                    listHeader
                    listActions
                }
            }

            if appModel.sortedMaterials.isEmpty {
                LibraryEmptyStateCard(importAction: showImportSheet)
            } else {
                VStack(spacing: 12) {
                    ForEach(appModel.sortedMaterials) { material in
                        Button {
                            if selectionMode {
                                toggleSelection(material.id)
                            } else {
                                openMaterial(material)
                            }
                        } label: {
                            LibraryMaterialRow(
                                material: material,
                                isSelectionMode: selectionMode,
                                isSelected: selectedMaterialIDs.contains(material.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imported Materials")
                .font(.title2.weight(.semibold))
            Text(selectionMode ? "\(selectedMaterialIDs.count) selected" : "Reopen Player or Reader from your saved local library.")
                .foregroundStyle(.secondary)
        }
    }

    private var listActions: some View {
        HStack(spacing: 10) {
            Button(selectionMode ? "Cancel" : "Select") {
                selectionMode.toggle()
                if !selectionMode {
                    selectedMaterialIDs.removeAll()
                }
            }
            .buttonStyle(.bordered)

            if selectionMode {
                Button("Delete Selected", role: .destructive, action: deleteSelectedMaterials)
                    .buttonStyle(.bordered)
                    .disabled(selectedMaterialIDs.isEmpty)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { !errorMessage.isEmpty },
            set: { isPresented in
                if !isPresented {
                    errorMessage = ""
                }
            }
        )
    }

    private func showImportSheet() {
        isShowingImportSheet = true
    }

    private func deleteSelectedMaterials() {
        Task { @MainActor in
            await appModel.deleteMaterials(ids: selectedMaterialIDs)
            selectedMaterialIDs.removeAll()
            selectionMode = false
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedMaterialIDs.contains(id) {
            selectedMaterialIDs.remove(id)
        } else {
            selectedMaterialIDs.insert(id)
        }
    }

    private func openMaterial(_ material: MaterialRecord) {
        Task { @MainActor in
            do {
                try await appModel.reopenMaterial(material)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct LibraryHeaderSection: View {
    let importAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerText
                Spacer(minLength: 0)
                importButton
            }

            VStack(alignment: .leading, spacing: 14) {
                headerText
                importButton
            }
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Keep your imported subtitle-based videos and articles in one place, then reopen them in Player or Reader anytime.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var importButton: some View {
        Button(action: importAction) {
            Label("Import", systemImage: "square.and.arrow.down")
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct LibrarySummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LibraryMaterialRow: View {
    let material: MaterialRecord
    let isSelectionMode: Bool
    let isSelected: Bool

    private static let lastUsedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(iconColor.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(material.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(detailLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(lastUsedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var iconName: String {
        material.kind == .video ? "play.rectangle.fill" : "doc.text.fill"
    }

    private var iconColor: Color {
        material.kind == .video ? .accentColor : .orange
    }

    private var detailLabel: String {
        switch material.kind {
        case .article:
            return "Article"
        case .video where material.hasVideo:
            return material.subtitleFileName
        case .video:
            return "Subtitle only · \(material.subtitleFileName)"
        }
    }

    private var lastUsedLabel: String {
        Self.lastUsedFormatter.string(from: Date(timeIntervalSince1970: material.lastUsedAt))
    }
}

private struct LibraryEmptyStateCard: View {
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No local materials yet")
                .font(.title3.weight(.semibold))
            Text("Import a subtitle-based video or a TXT article to start building your study library.")
                .foregroundStyle(.secondary)
            Button("Import Material", action: importAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct LibraryImportSheet: View {
    @ObservedObject var appModel: AppModel

    @Environment(\.dismiss) private var dismiss

    @State private var materialTitle = ""
    @State private var articleTitle = ""
    @State private var articleText = ""
    @State private var selectedVideoURL: URL?
    @State private var selectedSubtitleURL: URL?
    @State private var importedArticleFileName = ""
    @State private var activeImportTarget: LibraryImportTarget?
    @State private var isShowingImporter = false
    @State private var errorMessage = ""
    @State private var activeSheet: LibraryImportSheetRoute?
    @State private var shouldDismissAfterArticleSave = false

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth

    private var importerContentTypes: [UTType] {
        activeImportTarget?.allowedContentTypes ?? [.data]
    }

    private var hasArticleDraft: Bool {
        !articleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    importIntroCard
                    importSection
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .padding(AppLayout.pagePadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(AppTheme.workspaceBackground)
            .navigationTitle("Import Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: importerContentTypes
        ) { result in
            handleImportResult(result)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .articleDraft:
                ArticleDraftEditorSheet(
                    title: $articleTitle,
                    text: $articleText,
                    importedFileName: importedArticleFileName,
                    saveAction: saveArticleToLibrary
                )
                .presentationSizing(.page)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: isShowingImporter) { _, isShowing in
            if !isShowing {
                activeImportTarget = nil
            }
        }
        .onChange(of: shouldDismissAfterArticleSave) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .alert("Import", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var importIntroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bring new study material into Word Power")
                .font(.title2.weight(.semibold))
            Text("Use `Video + Subtitle` for synced playback and transcript study, or `Article` for paginated reading. Imports land in Library automatically.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var importSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                VideoImportCard(
                    materialTitle: $materialTitle,
                    selectedVideoTitle: selectionButtonTitle(for: selectedVideoURL, fallback: "Choose Video"),
                    selectedSubtitleTitle: selectionButtonTitle(for: selectedSubtitleURL, fallback: "Choose Subtitle"),
                    canSave: selectedSubtitleURL != nil,
                    canClear: selectedVideoURL != nil || selectedSubtitleURL != nil || !materialTitle.isEmpty,
                    chooseVideoAction: { presentImporter(for: .video) },
                    chooseSubtitleAction: { presentImporter(for: .subtitle) },
                    saveAction: saveMediaToLibrary,
                    clearAction: resetMaterialInputs
                )
                .frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)

                ArticleImportCard(
                    articleTitle: articleTitle,
                    importedFileName: importedArticleFileName,
                    articleTextCount: articleText.count,
                    hasDraft: hasArticleDraft,
                    loadAction: { presentImporter(for: .articleText) },
                    reviewAction: { activeSheet = .articleDraft },
                    clearAction: resetArticleInputs
                )
                .frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 24) {
                VideoImportCard(
                    materialTitle: $materialTitle,
                    selectedVideoTitle: selectionButtonTitle(for: selectedVideoURL, fallback: "Choose Video"),
                    selectedSubtitleTitle: selectionButtonTitle(for: selectedSubtitleURL, fallback: "Choose Subtitle"),
                    canSave: selectedSubtitleURL != nil,
                    canClear: selectedVideoURL != nil || selectedSubtitleURL != nil || !materialTitle.isEmpty,
                    chooseVideoAction: { presentImporter(for: .video) },
                    chooseSubtitleAction: { presentImporter(for: .subtitle) },
                    saveAction: saveMediaToLibrary,
                    clearAction: resetMaterialInputs
                )

                ArticleImportCard(
                    articleTitle: articleTitle,
                    importedFileName: importedArticleFileName,
                    articleTextCount: articleText.count,
                    hasDraft: hasArticleDraft,
                    loadAction: { presentImporter(for: .articleText) },
                    reviewAction: { activeSheet = .articleDraft },
                    clearAction: resetArticleInputs
                )
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { !errorMessage.isEmpty },
            set: { isPresented in
                if !isPresented {
                    errorMessage = ""
                }
            }
        )
    }

    private func presentImporter(for target: LibraryImportTarget) {
        activeImportTarget = nil
        isShowingImporter = false
        Task { @MainActor in
            activeImportTarget = target
            isShowingImporter = true
        }
    }

    private func saveMediaToLibrary() {
        guard let subtitleURL = selectedSubtitleURL else {
            errorMessage = "Choose a subtitle file first."
            return
        }

        Task { @MainActor in
            do {
                _ = try await appModel.saveVideoMaterial(title: materialTitle, videoURL: selectedVideoURL, subtitleURL: subtitleURL)
                resetMaterialInputs()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveArticleToLibrary() -> Bool {
        guard appModel.saveArticleMaterial(title: articleTitle, text: articleText) != nil else {
            errorMessage = "Load a local `.txt` file first."
            return false
        }
        resetArticleInputs()
        shouldDismissAfterArticleSave = true
        return true
    }

    private func handleImportResult(_ result: Result<URL, any Error>) {
        guard let importTarget = activeImportTarget else { return }
        defer {
            activeImportTarget = nil
            isShowingImporter = false
        }

        do {
            let url = try result.get()
            switch importTarget {
            case .video:
                selectedVideoURL = url
            case .subtitle:
                selectedSubtitleURL = url
            case .articleText:
                try loadArticleDraft(from: url)
            }
        } catch {
            if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func loadArticleDraft(from url: URL) throws {
        let text = try readTextFile(from: url)
        articleText = text
        importedArticleFileName = url.lastPathComponent
        if articleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            articleTitle = url.deletingPathExtension().lastPathComponent
        }
        activeSheet = .articleDraft
    }

    private func readTextFile(from url: URL) throws -> String {
        try SecurityScopedFileAccess.withAccess(to: url) {
            let data = try Data(contentsOf: url)
            for encoding in [String.Encoding.utf8, .utf16, .unicode, .ascii] {
                if let text = String(data: data, encoding: encoding) {
                    return text
                }
            }
            throw NSError(
                domain: "WordPower.Library",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The selected text file could not be decoded."]
            )
        }
    }

    private func selectionButtonTitle(for url: URL?, fallback: String) -> String {
        url?.lastPathComponent ?? fallback
    }

    private func resetMaterialInputs() {
        materialTitle = ""
        selectedVideoURL = nil
        selectedSubtitleURL = nil
    }

    private func resetArticleInputs() {
        articleTitle = ""
        articleText = ""
        importedArticleFileName = ""
        activeSheet = nil
    }
}

private struct VideoImportCard: View {
    @Binding var materialTitle: String

    let selectedVideoTitle: String
    let selectedSubtitleTitle: String
    let canSave: Bool
    let canClear: Bool
    let chooseVideoAction: () -> Void
    let chooseSubtitleAction: () -> Void
    let saveAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video + Subtitle")
                .font(.title2.weight(.semibold))
            Text("Choose a subtitle file to create a library item. Video is optional if you only want transcript study.")
                .foregroundStyle(.secondary)

            TextField("Optional material title", text: $materialTitle)
                .textFieldStyle(.roundedBorder)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Button(selectedVideoTitle, action: chooseVideoAction)
                        .buttonStyle(.bordered)
                    Button(selectedSubtitleTitle, action: chooseSubtitleAction)
                        .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button(selectedVideoTitle, action: chooseVideoAction)
                        .buttonStyle(.bordered)
                    Button(selectedSubtitleTitle, action: chooseSubtitleAction)
                        .buttonStyle(.bordered)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Button("Save to Library", action: saveAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    Button("Clear Selection", action: clearAction)
                        .buttonStyle(.bordered)
                        .disabled(!canClear)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button("Save to Library", action: saveAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    Button("Clear Selection", action: clearAction)
                        .buttonStyle(.bordered)
                        .disabled(!canClear)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ArticleImportCard: View {
    let articleTitle: String
    let importedFileName: String
    let articleTextCount: Int
    let hasDraft: Bool
    let loadAction: () -> Void
    let reviewAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Article")
                .font(.title2.weight(.semibold))
            Text("Load a local `.txt` or `.md` file, review it in a continuous editor, then save it into the library.")
                .foregroundStyle(.secondary)

            articleDraftSummary

            Spacer(minLength: 0)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Button(hasDraft ? "Replace File" : "Load File", action: loadAction)
                        .buttonStyle(.bordered)
                    Button("Review Draft", action: reviewAction)
                        .buttonStyle(.bordered)
                        .disabled(!hasDraft)
                    Button("Clear Draft", action: clearAction)
                        .buttonStyle(.bordered)
                        .disabled(!hasDraft)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button(hasDraft ? "Replace File" : "Load File", action: loadAction)
                        .buttonStyle(.bordered)
                    Button("Review Draft", action: reviewAction)
                        .buttonStyle(.bordered)
                        .disabled(!hasDraft)
                    Button("Clear Draft", action: clearAction)
                        .buttonStyle(.bordered)
                        .disabled(!hasDraft)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var articleDraftSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hasDraft ? (articleTitle.isEmpty ? "Untitled Article" : articleTitle) : "No article draft loaded")
                .font(.headline)

            Text(summarySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if hasDraft {
                Text("\(articleTextCount) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summarySubtitle: String {
        if hasDraft {
            return importedFileName.isEmpty ? "Draft ready to review" : importedFileName
        }
        return "Choose a local text file to preview and edit before it enters the library."
    }
}

private enum LibraryImportSheetRoute: String, Identifiable {
    case articleDraft

    var id: String { rawValue }
}

private struct ArticleDraftEditorSheet: View {
    @Binding var title: String
    @Binding var text: String

    let importedFileName: String
    let saveAction: () -> Bool

    @Environment(\.dismiss) private var dismiss

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Article title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    Text(importedFileName.isEmpty ? "TXT draft" : importedFileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("Review and adjust the article before saving it into the local library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $text)
                    .focused($isEditorFocused)
                    .font(.body)
                    .padding(12)
                    .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    Spacer()
                    Text("\(text.count) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(24)
            .frame(maxWidth: AppLayout.standardContentMaxWidth, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.workspaceBackground)
            .navigationTitle("Article Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Library") {
                        if saveAction() {
                            dismiss()
                        }
                    }
                    .disabled(!hasEditableContent)
                }
            }
            .onAppear {
                isEditorFocused = true
            }
        }
    }

    private var hasEditableContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private enum LibraryImportTarget {
    case video
    case subtitle
    case articleText

    var allowedContentTypes: [UTType] {
        switch self {
        case .video:
            return Self.buildTypes(
                base: [.movie, .video, .audiovisualContent, .data],
                extensions: ["mp4", "mov", "m4v", "mkv", "avi", "webm"]
            )
        case .subtitle:
            return Self.buildTypes(
                base: [.data, .json, .text, .plainText],
                extensions: ["srt", "vtt", "json", "txt", "sub"]
            )
        case .articleText:
            return Self.buildTypes(
                base: [.text, .plainText],
                extensions: ["txt", "md"]
            )
        }
    }

    private static func buildTypes(base: [UTType], extensions: [String]) -> [UTType] {
        var seen = Set<String>()
        let extensionTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        return (base + extensionTypes).filter { seen.insert($0.identifier).inserted }
    }
}
