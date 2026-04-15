import Foundation
import SwiftUI

struct HomeView: View {
    @ObservedObject var appModel: AppModel

    @State private var errorMessage = ""

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth
    private let actionColumns = [
        GridItem(.flexible(), spacing: 18, alignment: .top),
        GridItem(.flexible(), spacing: 18, alignment: .top),
        GridItem(.flexible(), spacing: 18, alignment: .top)
    ]

    private var recentVideoMaterial: MaterialRecord? {
        appModel.sortedMaterials.first { $0.kind == .video }
    }

    private var recentArticleMaterial: MaterialRecord? {
        appModel.sortedMaterials.first { $0.kind == .article }
    }

    private var recentMaterials: [MaterialRecord] {
        Array(appModel.sortedMaterials.prefix(6))
    }

    private var masteredWordCount: Int {
        appModel.learningRecords.values.filter { $0.familiarity >= 5 }.count
    }

    private var ratedWordCount: Int {
        appModel.learningRecords.count
    }

    private var pendingReviewCount: Int {
        max(ratedWordCount - masteredWordCount, 0)
    }

    private var materialCount: Int {
        appModel.materials.count
    }

    private var playerStatusTitle: String {
        if let material = appModel.playerController.material {
            return material.title
        }
        if let recentVideoMaterial {
            return recentVideoMaterial.title
        }
        return "No video yet"
    }

    private var playerStatusSubtitle: String {
        if appModel.playerController.material != nil {
            return "Continue subtitle playback from where you left off."
        }
        if let recentVideoMaterial {
            return recentVideoMaterial.hasVideo ? "Latest video is ready." : "Latest subtitles are ready."
        }
        return "Import a video in Library."
    }

    private var playerActionTitle: String {
        if appModel.playerController.material != nil {
            return "Open Player"
        }
        if recentVideoMaterial != nil {
            return "Open Latest"
        }
        return "Import Video"
    }

    private var readerStatusTitle: String {
        if !appModel.currentArticleText.isEmpty {
            return appModel.currentArticleTitle.isEmpty ? "Untitled Article" : appModel.currentArticleTitle
        }
        if let recentArticleMaterial {
            return recentArticleMaterial.title
        }
        return "No article yet"
    }

    private var readerStatusSubtitle: String {
        if !appModel.currentArticleText.isEmpty {
            return "Continue reading from your saved page."
        }
        if recentArticleMaterial != nil {
            return "Latest article is ready."
        }
        return "Import an article in Library."
    }

    private var readerActionTitle: String {
        if !appModel.currentArticleText.isEmpty {
            return "Open Reader"
        }
        if recentArticleMaterial != nil {
            return "Open Latest"
        }
        return "Import Article"
    }

    private var familiarityStatusTitle: String {
        if ratedWordCount == 0 {
            return "No rated words yet"
        }
        if pendingReviewCount == 0 {
            return "Everything rated is mastered"
        }
        return "\(pendingReviewCount) words ready for review"
    }

    private var familiarityStatusSubtitle: String {
        if ratedWordCount == 0 {
            return "Read or play materials, then rate words to build a review queue."
        }
        if pendingReviewCount == 0 {
            return "Open Familiarity any time you want to adjust earlier ratings."
        }
        return "\(masteredWordCount) mastered and \(ratedWordCount) rated in total."
    }

    private var libraryBadgeText: String {
        materialCount == 0 ? "Empty" : "\(materialCount) saved"
    }

    private var libraryCardSubtitle: String {
        if materialCount == 0 {
            return "Import videos and articles to build your study library."
        }
        return "Import, organize, and reopen your saved materials."
    }

    private var statisticsBadgeText: String {
        ratedWordCount == 0 ? "Progress" : "\(masteredWordCount) mastered"
    }

    private var statisticsCardSubtitle: String {
        if ratedWordCount == 0 {
            return "See your learning progress once you start rating words."
        }
        return "\(ratedWordCount) rated words across your materials."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HomeTitleHeader()

                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 18) {
                    HomePrimaryActionCard(
                        title: "Player",
                        headline: playerStatusTitle,
                        subtitle: playerStatusSubtitle,
                        systemImage: "play.rectangle.fill",
                        accentColor: HomePalette.playerAccent,
                        actionTitle: playerActionTitle,
                        action: openPlayerEntry
                    )

                    HomePrimaryActionCard(
                        title: "Reader",
                        headline: readerStatusTitle,
                        subtitle: readerStatusSubtitle,
                        systemImage: "book.pages.fill",
                        accentColor: HomePalette.readerAccent,
                        actionTitle: readerActionTitle,
                        action: openReaderEntry
                    )

                    HomePrimaryActionCard(
                        title: "Familiarity",
                        headline: familiarityStatusTitle,
                        subtitle: familiarityStatusSubtitle,
                        systemImage: "star.leadinghalf.filled",
                        accentColor: HomePalette.familiarityAccent,
                        actionTitle: "Open Familiarity",
                        action: showFamiliarity
                    )
                }

                HomeSectionDivider()

                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 18) {
                    HomeSecondaryActionCard(
                        title: "Library",
                        subtitle: libraryCardSubtitle,
                        badgeText: libraryBadgeText,
                        systemImage: "books.vertical.fill",
                        accentColor: HomePalette.libraryAccent,
                        actionTitle: "Open Library",
                        action: showLibrary
                    )

                    HomeSecondaryActionCard(
                        title: "Statistics",
                        subtitle: statisticsCardSubtitle,
                        badgeText: statisticsBadgeText,
                        systemImage: "chart.xyaxis.line",
                        accentColor: HomePalette.statisticsAccent,
                        actionTitle: "Open Statistics",
                        action: showStatistics
                    )

                    HomeSecondaryActionCard(
                        title: "Settings",
                        subtitle: "Adjust reading, playback, and subtitle behavior.",
                        badgeText: appModel.currentReaderLayoutMode.shortTitle,
                        systemImage: "slider.horizontal.3",
                        accentColor: HomePalette.settingsAccent,
                        actionTitle: "Open Settings",
                        action: showSettings
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    HomeSectionHeader(
                        title: "Recent",
                        subtitle: recentMaterials.isEmpty ? "Nothing imported yet." : "Open a recent item."
                    )

                    if recentMaterials.isEmpty {
                        HomeEmptyLibraryCard(action: showLibrary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(recentMaterials.enumerated()), id: \.element.id) { index, material in
                                HomeRecentMaterialRow(material: material) {
                                    openMaterial(material)
                                }

                                if index < recentMaterials.count - 1 {
                                    Divider()
                                        .padding(.leading, 76)
                                }
                            }
                        }
                        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        }
                    }
                }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .alert("Home", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
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

    private func openPlayerEntry() {
        if appModel.playerController.material != nil {
            appModel.selectedSection = .player
            return
        }
        guard let recentVideoMaterial else {
            showLibrary()
            return
        }
        openMaterial(recentVideoMaterial)
    }

    private func openReaderEntry() {
        if !appModel.currentArticleText.isEmpty {
            appModel.selectedSection = .reader
            return
        }
        guard let recentArticleMaterial else {
            showLibrary()
            return
        }
        appModel.openArticleMaterial(recentArticleMaterial.id)
    }

    private func showLibrary() {
        appModel.selectedSection = .library
    }

    private func showFamiliarity() {
        appModel.selectedSection = .familiarity
    }

    private func showStatistics() {
        appModel.selectedSection = .statistics
    }

    private func showSettings() {
        appModel.selectedSection = .settings
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

private struct HomeTitleHeader: View {
    var body: some View {
        Text("Home")
            .font(.system(size: 34, weight: .bold, design: .rounded))
    }
}

private struct HomeSectionDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            Circle()
                .fill(AppTheme.panelSecondaryBackground)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }

            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HomePrimaryActionCard: View {
    let title: String
    let headline: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(headline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(actionTitle)
                        .font(.headline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(accentColor)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 226, alignment: .topLeading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(0.14),
                AppTheme.panelBackground,
                AppTheme.panelBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeSecondaryActionCard: View {
    let title: String
    let subtitle: String
    let badgeText: String
    let systemImage: String
    let accentColor: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }

                    Spacer(minLength: 0)

                    Text(badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(accentColor)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(0.08),
                AppTheme.panelBackground,
                AppTheme.panelBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeRecentMaterialRow: View {
    let material: MaterialRecord
    let action: () -> Void

    private static let lastUsedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdHm")
        return formatter
    }()

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                wideLayout
                compactLayout
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var wideLayout: some View {
        HStack(spacing: 14) {
            iconView
            titleBlock
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            metadataBlock
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                iconView
                titleBlock
            }

            HStack(spacing: 12) {
                metadataBlock

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var iconView: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(iconColor.opacity(0.14))
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(detailLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var metadataBlock: some View {
        HStack(spacing: 12) {
            kindBadge

            Text(lastUsedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var kindBadge: some View {
        Text(material.kind == .video ? "Video" : "Article")
            .font(.caption.weight(.semibold))
            .foregroundStyle(iconColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(iconColor.opacity(0.12), in: Capsule())
    }

    private var iconName: String {
        material.kind == .video ? "play.rectangle.fill" : "doc.text.fill"
    }

    private var iconColor: Color {
        material.kind == .video ? HomePalette.playerAccent : HomePalette.readerAccent
    }

    private var displayTitle: String {
        let trimmedTitle = material.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let maximumLength = 32
        guard trimmedTitle.count > maximumLength else {
            return trimmedTitle
        }
        return String(trimmedTitle.prefix(maximumLength - 1)) + "…"
    }

    private var detailLabel: String {
        switch material.kind {
        case .article:
            return "Imported article"
        case .video where material.hasVideo:
            return material.subtitleFileName
        case .video:
            return "Subtitle only"
        }
    }

    private var lastUsedLabel: String {
        Self.lastUsedFormatter.string(from: Date(timeIntervalSince1970: material.lastUsedAt))
    }
}

private struct HomeEmptyLibraryCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No materials yet")
                .font(.title3.weight(.semibold))
            Text("Open Library to import your first video or article.")
                .foregroundStyle(.secondary)
            Button("Open Library", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private enum HomePalette {
    static let playerAccent = Color(red: 0.06, green: 0.29, blue: 0.47)
    static let readerAccent = Color(red: 0.70, green: 0.46, blue: 0.15)
    static let libraryAccent = Color(red: 0.06, green: 0.37, blue: 0.54)
    static let familiarityAccent = Color(red: 0.78, green: 0.43, blue: 0.13)
    static let statisticsAccent = Color(red: 0.15, green: 0.55, blue: 0.45)
    static let settingsAccent = Color(red: 0.39, green: 0.41, blue: 0.51)
}
