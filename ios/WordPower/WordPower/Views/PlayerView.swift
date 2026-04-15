import AVKit
import SwiftUI
import UIKit

struct PlayerView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playerController: PlayerController

    @State private var isSeeking = false
    @State private var seekPreviewTime = 0.0
    @State private var subtitleContextWords: Set<String> = []
    @State private var subtitleTextCache = AttributedTextCache()
    @State private var didCopyAB = false
    @State private var copyABFeedbackTask: Task<Void, Never>?
    @State private var isShowingMaterialPicker = false

    private let playbackRateOptions: [Double] = [0.5, 1.0, 1.25, 1.5, 2.0]
    private let contentMaxWidth: CGFloat = AppLayout.playerContentMaxWidth
    private let compactLayoutThreshold: CGFloat = 980

    init(appModel: AppModel) {
        _appModel = ObservedObject(wrappedValue: appModel)
        _playerController = ObservedObject(wrappedValue: appModel.playerController)
    }

    var body: some View {
        Group {
            if let material = playerController.material {
                GeometryReader { proxy in
                    content(material: material, size: proxy.size)
                }
            } else {
                MaterialOpenPromptView(
                    title: "No player material loaded",
                    message: "Open an imported video material from your local library to start the player.",
                    systemImage: "play.rectangle",
                    buttonTitle: "Open Material"
                ) {
                    isShowingMaterialPicker = true
                }
            }
        }
        .sheet(isPresented: $isShowingMaterialPicker) {
            MaterialLibraryPickerSheet(
                appModel: appModel,
                kind: .video,
                title: "Choose Video Material"
            )
        }
        .onAppear {
            refreshSubtitlePresentationData()
        }
        .onChange(of: playerController.subtitleLines) { _, _ in
            refreshSubtitlePresentationData()
        }
        .onChange(of: playerController.subtitleFontScale) { _, _ in
            refreshSubtitleRenderCache()
        }
        .onChange(of: appModel.learningRecords) { _, _ in
            refreshSubtitleRenderCache()
        }
        .onChange(of: playerController.canPlayABRange) { _, canPlay in
            if !canPlay {
                resetABCopyFeedback()
            }
        }
        .onDisappear {
            copyABFeedbackTask?.cancel()
        }
        .fullScreenCover(isPresented: fullscreenBinding) {
            NavigationStack {
                VideoPlayer(player: playerController.player)
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                playerController.isFullscreenPresented = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func content(material: MaterialRecord, size: CGSize) -> some View {
        let horizontalPadding = AppLayout.pagePadding
        let availableWidth = min(contentMaxWidth, max(size.width - horizontalPadding * 2, 0))
        let availableHeight = max(size.height - horizontalPadding * 2, 0)
        let usesCompactLayout = availableWidth < compactLayoutThreshold

        if usesCompactLayout {
            ScrollView {
                compactLayout(
                    material: material,
                    contextWords: subtitleContextWords,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight
                )
                .frame(width: availableWidth, alignment: .leading)
                .padding(horizontalPadding)
                .padding(.bottom, horizontalPadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            wideLayout(
                material: material,
                contextWords: subtitleContextWords,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )
            .frame(width: availableWidth, height: availableHeight, alignment: .leading)
            .padding(horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func wideLayout(
        material: MaterialRecord,
        contextWords: Set<String>,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        let panelSpacing: CGFloat = 24
        let subtitlePanelWidth = min(max(380, availableWidth * 0.38), 500)
        let videoColumnWidth = max(340, availableWidth - subtitlePanelWidth - panelSpacing)
        let videoPanelHeight = availableHeight
        let videoHeight = min(videoColumnWidth * 9 / 16, max(220, videoPanelHeight - 220))

        return HStack(alignment: .top, spacing: panelSpacing) {
            videoPanel(material: material, videoHeight: videoHeight)
                .frame(width: videoColumnWidth, height: videoPanelHeight, alignment: .topLeading)

            subtitlePanel(contextWords: contextWords)
                .frame(width: subtitlePanelWidth, height: availableHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactLayout(
        material: MaterialRecord,
        contextWords: Set<String>,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        let videoHeight = min(max(240, availableWidth * 9 / 16), 420)
        let subtitleHeight = max(360, availableHeight * 0.55)

        return VStack(alignment: .leading, spacing: 24) {
            videoPanel(material: material, videoHeight: videoHeight)
            subtitlePanel(contextWords: contextWords)
                .frame(maxWidth: .infinity, minHeight: subtitleHeight, alignment: .topLeading)
        }
    }

    private func playerMetadata(material: MaterialRecord) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(material.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(material.subtitleFileName.isEmpty ? "Local video" : material.subtitleFileName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(material.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                Text(material.subtitleFileName.isEmpty ? "Local video" : material.subtitleFileName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func videoPanel(material: MaterialRecord, videoHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                VideoPlayer(player: playerController.player)
                    .frame(maxWidth: .infinity)
                    .frame(height: videoHeight)

                if let previewImage = playerController.previewImage, shouldShowPreviewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                if !playerController.hasVideo {
                    Text("Missing local video")
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding()
                }
            }
            .background(.black, in: RoundedRectangle(cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 14) {
                playbackProgressSection
                mainPlaybackControls
                secondaryControlsSection
                playerMetadata(material: material)

                if let abHint = abHintText {
                    Text(abHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 22))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 28))
    }

    private var shouldShowPreviewImage: Bool {
        playerController.currentTime <= 0.05
    }

    private var playbackProgressSection: some View {
        VStack(spacing: 10) {
            Slider(
                value: sliderBinding,
                in: 0...max(playerController.duration, 0.1),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing {
                        playerController.seek(to: seekPreviewTime)
                    }
                }
            )
            .disabled(!playerController.canSeek)

            HStack {
                Text(timeLabel(for: isSeeking ? seekPreviewTime : playerController.currentTime))
                Spacer()
                Text(timeLabel(for: playerController.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var mainPlaybackControls: some View {
        transportControlRow
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var transportControlRow: some View {
        HStack(spacing: 12) {
            controlButton(systemImage: "backward.end.fill") {
                playerController.jumpToStart()
            }
            .disabled(playerController.subtitleLines.isEmpty)

            controlButton(
                systemImage: "backward.fill",
                helpText: "Previous Line (\u{2190})",
                shortcut: .leftArrow
            ) {
                playerController.playPreviousSubtitle()
            }
            .disabled(playerController.subtitleLines.isEmpty)

            Button {
                playerController.togglePlayPause()
            } label: {
                Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 64, height: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .keyboardShortcut(.space, modifiers: [])
            .help(playerController.isPlaying ? "Pause (Space)" : "Play (Space)")
            .disabled(!playerController.hasVideo)

            controlButton(
                systemImage: "forward.fill",
                helpText: "Next Line (\u{2192})",
                shortcut: .rightArrow
            ) {
                playerController.playNextSubtitle()
            }
            .disabled(playerController.subtitleLines.isEmpty)

            controlButton(systemImage: "forward.end.fill") {
                playerController.jumpToEnd()
            }
            .disabled(playerController.subtitleLines.isEmpty)
        }
    }

    private var playbackSpeedMenu: some View {
        Menu(rateLabel(playerController.playbackRate)) {
            ForEach(playbackRateOptions, id: \.self) { rate in
                Button(rateLabel(rate)) {
                    appModel.updatePlaybackRate(rate)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var secondaryControlsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                secondaryControlButtons
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    fullscreenButton
                    abSelectionButton
                    copyABButton
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    vocabularyButton
                    playbackSpeedMenu
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var secondaryControlButtons: some View {
        fullscreenButton
        abSelectionButton
        copyABButton
        vocabularyButton
        playbackSpeedMenu
    }

    private var fullscreenButton: some View {
        Button {
            playerController.isFullscreenPresented.toggle()
        } label: {
            Image(systemName: playerController.isFullscreenPresented ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(playerController.isFullscreenPresented ? "Exit Fullscreen" : "Fullscreen")
        .disabled(!playerController.hasVideo)
    }

    private var abSelectionButton: some View {
        Button(abButtonTitle) {
            playerController.toggleABSelectionMode()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(playerController.abSelectionMode || playerController.canPlayABRange ? .accentColor : .primary)
    }

    private var copyABButton: some View {
        Button(copyABButtonTitle) {
            copyABText()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!playerController.canPlayABRange)
    }

    private var vocabularyButton: some View {
        Button("Vocabulary") {
            appModel.analyzeCurrentPlayerMaterial()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(playerController.subtitleLines.isEmpty)
    }

    private func subtitlePanel(contextWords: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Subtitles")
                    .font(.headline)
                Spacer()
                if !playerController.subtitleLines.isEmpty {
                    Text("\(playerController.subtitleLines.count) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if playerController.subtitleLines.isEmpty {
                EmptyStateView(
                    title: "No subtitles loaded",
                    message: "Import a video with subtitles from Library to view the transcript here.",
                    systemImage: "captions.bubble"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(playerController.subtitleLines.enumerated()), id: \.element.id) { index, line in
                                subtitleRow(index: index, line: line, contextWords: contextWords)
                                    .id(index)
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onChange(of: playerController.activeSubtitleIndex) { _, newValue in
                        guard newValue >= 0 else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scrollProxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 28))
    }

    private var abHintText: String? {
        if playerController.abSelectionMode {
            return "Select two subtitle lines as A and B. Then press Play to loop, or Copy AB to copy."
        }
        if playerController.canPlayABRange {
            return "A \(shortTimeLabel(for: playerController.subtitleLines[playerController.abStartIndex].start)) · B \(shortTimeLabel(for: playerController.subtitleLines[playerController.abEndIndex].start)) · Press Play to loop, or Copy AB to copy."
        }
        return nil
    }

    private func subtitleRow(index: Int, line: SubtitleLine, contextWords: Set<String>) -> some View {
        let isActive = playerController.activeSubtitleIndex == index
        let inABRange = playerController.canPlayABRange && index >= min(playerController.abStartIndex, playerController.abEndIndex) && index <= max(playerController.abStartIndex, playerController.abEndIndex)

        return HStack(alignment: .center, spacing: 10) {
            Button(shortTimeLabel(for: line.start)) {
                if playerController.abSelectionMode {
                    playerController.selectSubtitleForAB(index)
                } else {
                    playerController.playSingleLine(at: index)
                }
            }
            .buttonStyle(.plain)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 52, alignment: .center)

            InteractiveTextView(attributedText: attributedText(for: line, contextWords: contextWords)) { context in
                appModel.presentWordAction(displayToken: context.displayToken, targetWord: context.targetWord)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor(isActive: isActive, inABRange: inABRange, isSelecting: playerController.abSelectionMode), in: RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            if playerController.abSelectionMode {
                playerController.selectSubtitleForAB(index)
            } else {
                playerController.playSingleLine(at: index)
            }
        }
    }

    private func backgroundColor(isActive: Bool, inABRange: Bool, isSelecting: Bool) -> Color {
        if isActive {
            return Color.accentColor.opacity(0.15)
        }
        if inABRange {
            return Color.orange.opacity(0.12)
        }
        if isSelecting {
            return Color.secondary.opacity(0.08)
        }
        return AppTheme.panelSecondaryBackground
    }

    @ViewBuilder
    private func controlButton(
        systemImage: String,
        helpText: String? = nil,
        shortcut: KeyEquivalent? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .help(helpText ?? "")
        .modifier(PlayerKeyboardShortcutModifier(shortcut: shortcut))
    }

    private func timeLabel(for seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func shortTimeLabel(for seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func rateLabel(_ rate: Double) -> String {
        rate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fx", rate) : String(format: "%.2gx", rate)
    }

    private var abButtonTitle: String {
        if playerController.abSelectionMode {
            return "Cancel AB"
        }
        if playerController.canPlayABRange {
            return "Clear AB"
        }
        return "AB"
    }

    private var copyABButtonTitle: String {
        didCopyAB ? "Copied" : "Copy AB"
    }

    private func scaledBodyFont(scale: Double) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        return baseFont.withSize(baseFont.pointSize * scale)
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                isSeeking ? seekPreviewTime : playerController.currentTime
            },
            set: { newValue in
                seekPreviewTime = newValue
            }
        )
    }

    private var fullscreenBinding: Binding<Bool> {
        Binding(
            get: { playerController.isFullscreenPresented },
            set: { newValue in
                playerController.isFullscreenPresented = newValue
            }
        )
    }

    private func attributedText(for line: SubtitleLine, contextWords: Set<String>) -> NSAttributedString {
        subtitleTextCache.value(for: line.id) {
            HighlightTextBuilder.makeAttributedText(
                text: line.text,
                contextWords: contextWords,
                catalog: appModel.wordCatalog,
                learningRecords: appModel.learningRecords,
                font: scaledBodyFont(scale: playerController.subtitleFontScale),
                lineSpacing: 0
            )
        }
    }

    private func refreshSubtitlePresentationData() {
        let lines = playerController.subtitleLines
        guard !lines.isEmpty else {
            subtitleContextWords = []
            subtitleTextCache.clear()
            return
        }

        subtitleContextWords = Set(lines.flatMap { WordPowerText.extractWords(from: $0.text) })
        refreshSubtitleRenderCache()
    }

    private func refreshSubtitleRenderCache() {
        subtitleTextCache.clear()
    }

    private func copyABText() {
        let text = playerController.copyableABText()
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        didCopyAB = true
        copyABFeedbackTask?.cancel()
        copyABFeedbackTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                didCopyAB = false
                copyABFeedbackTask = nil
            }
        }
    }

    private func resetABCopyFeedback() {
        copyABFeedbackTask?.cancel()
        copyABFeedbackTask = nil
        didCopyAB = false
    }
}

private struct PlayerKeyboardShortcutModifier: ViewModifier {
    let shortcut: KeyEquivalent?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let shortcut {
            content.keyboardShortcut(shortcut, modifiers: [])
        } else {
            content
        }
    }
}

private final class AttributedTextCache {
    private var storage: [String: NSAttributedString] = [:]

    func value(for key: String, build: () -> NSAttributedString) -> NSAttributedString {
        if let cached = storage[key] {
            return cached
        }

        let value = build()
        storage[key] = value
        return value
    }

    func clear() {
        storage.removeAll(keepingCapacity: true)
    }
}
