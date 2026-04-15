import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playerController: PlayerController

    private static let exportFileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private let playbackRateOptions: [Double] = [0.5, 1.0, 1.25, 1.5, 2.0]
    private let textScaleOptions: [Double] = [1.0, 1.25, 1.5, 1.75]
    private let readerLineSpacingOptions: [Double] = [1.0, 1.15, 1.3, 1.5]
    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth
    private let settingsPanelMinHeight: CGFloat = 288
    private let settingsColumns = [
        GridItem(.adaptive(minimum: 360, maximum: .infinity), spacing: 20, alignment: .top)
    ]
    private let compactMetricColumns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        count: 2
    )

    @State private var isImportingLearningData = false
    @State private var isExportingLearningData = false
    @State private var exportDocument = CSVDocument(text: "")
    @State private var errorMessage = ""

    init(appModel: AppModel) {
        _appModel = ObservedObject(wrappedValue: appModel)
        _playerController = ObservedObject(wrappedValue: appModel.playerController)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsSummaryCard

                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 20) {
                    readerSettingsCard
                    playerSettingsCard
                    learningDataCard
                }
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .fileImporter(
            isPresented: $isImportingLearningData,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            do {
                let url = try result.get()
                Task {
                    do {
                        try await appModel.importLearningData(from: url)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExportingLearningData,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: defaultExportFileName
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Settings", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var settingsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Reading and playback changes are saved automatically.")
                    .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    settingsMetric(title: "Reader Size", value: multiplierLabel(appModel.currentReaderFontScale))
                    settingsMetric(title: "Subtitle Size", value: multiplierLabel(playerController.subtitleFontScale))
                    settingsMetric(title: "Rated Words", value: "\(appModel.learningRecords.count)")
                }

                LazyVGrid(columns: compactMetricColumns, alignment: .leading, spacing: 12) {
                    settingsMetric(title: "Reader Size", value: multiplierLabel(appModel.currentReaderFontScale))
                    settingsMetric(title: "Subtitle Size", value: multiplierLabel(playerController.subtitleFontScale))
                    settingsMetric(title: "Rated Words", value: "\(appModel.learningRecords.count)")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var readerSettingsCard: some View {
        SettingsPanel(
            title: "Reader",
            subtitle: "Text size and line spacing.",
            minHeight: settingsPanelMinHeight
        ) {
            SettingsPickerBlock(title: "Reading Text Size") {
                Picker("Reading Text Size", selection: readerFontScaleBinding) {
                    ForEach(textScaleOptions, id: \.self) { scale in
                        Text(multiplierLabel(scale)).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsPickerBlock(title: "Line Spacing") {
                Picker("Line Spacing", selection: readerLineSpacingBinding) {
                    ForEach(readerLineSpacingOptions, id: \.self) { spacing in
                        Text(multiplierLabel(spacing)).tag(spacing)
                    }
                }
                .pickerStyle(.segmented)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    settingsMetric(title: "Text Size", value: multiplierLabel(appModel.currentReaderFontScale))
                    settingsMetric(title: "Spacing", value: multiplierLabel(appModel.currentReaderLineSpacingMultiplier))
                }

                LazyVGrid(columns: compactMetricColumns, alignment: .leading, spacing: 12) {
                    settingsMetric(title: "Text Size", value: multiplierLabel(appModel.currentReaderFontScale))
                    settingsMetric(title: "Spacing", value: multiplierLabel(appModel.currentReaderLineSpacingMultiplier))
                }
            }
        }
    }

    private var playerSettingsCard: some View {
        SettingsPanel(
            title: "Player",
            subtitle: "Subtitle size and playback speed.",
            minHeight: settingsPanelMinHeight
        ) {
            SettingsPickerBlock(title: "Subtitle Text Size") {
                Picker("Subtitle Text Size", selection: subtitleScaleBinding) {
                    ForEach(textScaleOptions, id: \.self) { scale in
                        Text(multiplierLabel(scale)).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsPickerBlock(title: "Playback Speed") {
                Picker("Playback Speed", selection: playbackRateBinding) {
                    ForEach(playbackRateOptions, id: \.self) { rate in
                        Text(multiplierLabel(rate)).tag(rate)
                    }
                }
                .pickerStyle(.segmented)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    settingsMetric(title: "Subtitle Size", value: multiplierLabel(playerController.subtitleFontScale))
                    settingsMetric(title: "Playback", value: multiplierLabel(playerController.playbackRate))
                }

                LazyVGrid(columns: compactMetricColumns, alignment: .leading, spacing: 12) {
                    settingsMetric(title: "Subtitle Size", value: multiplierLabel(playerController.subtitleFontScale))
                    settingsMetric(title: "Playback", value: multiplierLabel(playerController.playbackRate))
                }
            }
        }
    }

    private var learningDataCard: some View {
        SettingsPanel(
            title: "Learning Data",
            subtitle: "Import or export familiarity records.",
            minHeight: settingsPanelMinHeight
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    importLearningDataButton
                    exportLearningDataButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    importLearningDataButton
                    exportLearningDataButton
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    settingsMetric(title: "Rated Words", value: "\(appModel.learningRecords.count)")
                    settingsMetric(title: "Library Items", value: "\(appModel.materials.count)")
                }

                LazyVGrid(columns: compactMetricColumns, alignment: .leading, spacing: 12) {
                    settingsMetric(title: "Rated Words", value: "\(appModel.learningRecords.count)")
                    settingsMetric(title: "Library Items", value: "\(appModel.materials.count)")
                }
            }
        }
    }

    private var importLearningDataButton: some View {
        Button("Import Learning Data") {
            isImportingLearningData = true
        }
        .buttonStyle(.borderedProminent)
    }

    private var exportLearningDataButton: some View {
        Button("Export Learning Data") {
            exportDocument = appModel.exportLearningDataDocument()
            isExportingLearningData = true
        }
        .buttonStyle(.bordered)
    }

    private func settingsMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var defaultExportFileName: String {
        "learning_data-\(Self.exportFileNameFormatter.string(from: .now))"
    }

    private func multiplierLabel(_ value: Double) -> String {
        let label = String(format: "%.2f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
        return "\(label)x"
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

    private var playbackRateBinding: Binding<Double> {
        Binding(
            get: { playerController.playbackRate },
            set: { newValue in
                appModel.updatePlaybackRate(newValue)
            }
        )
    }

    private var subtitleScaleBinding: Binding<Double> {
        Binding(
            get: { playerController.subtitleFontScale },
            set: { newValue in
                appModel.updateSubtitleScale(newValue)
            }
        )
    }

    private var readerFontScaleBinding: Binding<Double> {
        Binding(
            get: { appModel.currentReaderFontScale },
            set: { newValue in
                appModel.updateReaderFontScale(newValue)
            }
        )
    }

    private var readerLineSpacingBinding: Binding<Double> {
        Binding(
            get: { appModel.currentReaderLineSpacingMultiplier },
            set: { newValue in
                appModel.updateReaderLineSpacingMultiplier(newValue)
            }
        )
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let minHeight: CGFloat?
    let content: Content

    init(
        title: String,
        subtitle: String,
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SettingsPickerBlock<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content
        }
    }
}
