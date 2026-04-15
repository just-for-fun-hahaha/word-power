import AVFoundation
import Combine
import UIKit

@MainActor
final class PlayerController: ObservableObject {
    private static let playbackObserverInterval = 0.05
    private static let playbackUIUpdateInterval = 0.15

    enum PlaybackMode: Hashable {
        case single(start: Double, end: Double)
        case ab(start: Double, end: Double)
    }

    let player = AVPlayer()

    @Published var material: MaterialRecord?
    @Published var subtitleLines: [SubtitleLine] = []
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var activeSubtitleIndex: Int = -1
    @Published var isPlaying = false
    @Published var playbackRate: Double = 1.0
    let availablePlaybackRates: [Double] = [0.5, 1.0, 1.25, 1.5, 2.0]
    @Published var subtitleFontScale: Double = 1.25
    @Published var abSelectionMode = false
    @Published var abSelectionCandidates: [Int] = []
    @Published var abStartIndex: Int = -1
    @Published var abEndIndex: Int = -1
    @Published var pinnedSubtitleIndex: Int = -1
    @Published var isFullscreenPresented = false
    @Published var errorMessage = ""
    @Published var previewImage: UIImage?

    private var timeObserver: Any?
    private var playbackMode: PlaybackMode?
    private var previewImageTask: Task<Void, Never>?

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var hasVideo: Bool {
        material?.hasVideo == true && player.currentItem != nil
    }

    var hasMaterial: Bool {
        material != nil
    }

    var canPlayABRange: Bool {
        abStartIndex >= 0 && abEndIndex >= 0 && abStartIndex < subtitleLines.count && abEndIndex < subtitleLines.count
    }

    var canSeek: Bool {
        hasVideo && duration > 0
    }

    func open(material: MaterialRecord, videoURL: URL?, settings: AppSettings) {
        close()
        self.material = material
        subtitleLines = material.subtitleLines
        playbackRate = normalizePlaybackRate(settings.playbackRate)
        subtitleFontScale = normalizeSubtitleScale(settings.subtitleFontScale)
        if let videoURL {
            player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
            player.actionAtItemEnd = .pause
            installTimeObserverIfNeeded()
            applyPlaybackRate(playbackRate)
            let initialDuration = player.currentItem?.duration.seconds ?? 0
            duration = initialDuration.isFinite ? initialDuration : 0
            loadPreviewImage(from: videoURL, materialID: material.id)
        } else {
            player.replaceCurrentItem(with: nil)
            duration = 0
            previewImage = nil
        }
        updateActiveSubtitleIndex(for: currentTime)
    }

    func close() {
        previewImageTask?.cancel()
        previewImageTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        material = nil
        subtitleLines = []
        currentTime = 0
        duration = 0
        activeSubtitleIndex = -1
        isPlaying = false
        errorMessage = ""
        previewImage = nil
        clearABSelection()
        pinnedSubtitleIndex = -1
        playbackMode = nil
    }

    func installTimeObserverIfNeeded() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: Self.playbackObserverInterval, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let observedTime = time.seconds.isFinite ? time.seconds : 0
                self.publishCurrentTimeIfNeeded(observedTime)
                self.updateActiveSubtitleIndex(for: observedTime)
                self.updateIsPlayingIfNeeded()
                self.updateDurationIfNeeded()
                self.handlePlaybackBoundaryIfNeeded(at: observedTime)
            }
        }
    }

    func togglePlayPause() {
        guard hasVideo else { return }
        if isPlaying {
            pause()
            return
        }

        if case let .ab(start, end) = playbackMode {
            resumeABPlayback(start: start, end: end)
            return
        }

        if canPlayABRange {
            playABRange()
            return
        }

        if player.currentTime().seconds.isNaN {
            seek(to: 0)
        }
        play()
    }

    func play() {
        guard hasVideo else { return }
        applyPlaybackRate(playbackRate)
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
        if case .single = playbackMode {
            playbackMode = nil
        }
    }

    func seek(to seconds: Double) {
        guard hasVideo else { return }
        let safeSeconds = max(0, min(seconds, max(duration, seconds)))
        player.seek(to: CMTime(seconds: safeSeconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = safeSeconds
        if pinnedSubtitleIndex >= 0, !canPlayABRange {
            pinnedSubtitleIndex = -1
        }
        updateActiveSubtitleIndex(for: safeSeconds)
    }

    func setPlaybackRate(_ value: Double) {
        playbackRate = normalizePlaybackRate(value)
        applyPlaybackRate(playbackRate)
    }

    func setSubtitleFontScale(_ value: Double) {
        subtitleFontScale = normalizeSubtitleScale(value)
    }

    func playSingleLine(at index: Int) {
        guard subtitleLines.indices.contains(index), hasVideo else { return }
        let line = subtitleLines[index]
        let end = resolveSingleLineEnd(for: line, index: index)
        pinnedSubtitleIndex = index
        playbackMode = .single(start: line.start, end: end)
        seek(to: line.start)
        play()
    }

    func playPreviousSubtitle() {
        guard !subtitleLines.isEmpty else { return }
        let base = activeSubtitleIndex >= 0 ? activeSubtitleIndex : 0
        let targetIndex = max(0, base - 1)
        playSingleLine(at: targetIndex)
    }

    func playNextSubtitle() {
        guard !subtitleLines.isEmpty else { return }
        let base = activeSubtitleIndex >= 0 ? activeSubtitleIndex : -1
        let targetIndex = min(subtitleLines.count - 1, base + 1)
        playSingleLine(at: targetIndex)
    }

    func jumpToStart() {
        guard let firstLine = subtitleLines.first else { return }
        pinnedSubtitleIndex = -1
        playbackMode = nil
        seek(to: firstLine.start)
        play()
    }

    func jumpToEnd() {
        guard let lastLine = subtitleLines.last else { return }
        pinnedSubtitleIndex = -1
        playbackMode = nil
        seek(to: lastLine.start)
        play()
    }

    func toggleABSelectionMode() {
        guard !subtitleLines.isEmpty else { return }
        if abSelectionMode {
            clearABSelection()
            return
        }
        if canPlayABRange {
            clearABSelection()
            playbackMode = nil
            return
        }
        clearABSelection()
        abSelectionMode = true
    }

    func selectSubtitleForAB(_ index: Int) {
        guard subtitleLines.indices.contains(index) else { return }
        if !abSelectionMode {
            return
        }
        if let existingIndex = abSelectionCandidates.firstIndex(of: index) {
            abSelectionCandidates.remove(at: existingIndex)
            abStartIndex = -1
            abEndIndex = -1
            playbackMode = nil
            return
        }
        if abSelectionCandidates.count >= 2 {
            abSelectionCandidates.removeFirst()
        }
        abSelectionCandidates.append(index)
        if abSelectionCandidates.count == 2 {
            abStartIndex = min(abSelectionCandidates[0], abSelectionCandidates[1])
            abEndIndex = max(abSelectionCandidates[0], abSelectionCandidates[1])
            abSelectionCandidates = []
            abSelectionMode = false
            playbackMode = nil
        }
    }

    func playABRange() {
        guard canPlayABRange, hasVideo else { return }
        let startLine = subtitleLines[min(abStartIndex, abEndIndex)]
        let endLine = subtitleLines[max(abStartIndex, abEndIndex)]
        playbackMode = .ab(start: startLine.start, end: max(endLine.end, startLine.start + 0.3))
        pinnedSubtitleIndex = -1
        seek(to: startLine.start)
        play()
    }

    func copyableABText() -> String {
        guard canPlayABRange else { return "" }
        let start = min(abStartIndex, abEndIndex)
        let end = max(abStartIndex, abEndIndex)
        return subtitleLines[start...end]
            .map { line in
                line.text
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .joined(separator: " ")
    }

    func clearABSelection() {
        abSelectionMode = false
        abSelectionCandidates = []
        abStartIndex = -1
        abEndIndex = -1
    }

    private func applyPlaybackRate(_ rate: Double) {
        player.rate = isPlaying ? Float(rate) : 0
        if player.timeControlStatus == .playing {
            player.rate = Float(rate)
        }
    }

    private func publishCurrentTimeIfNeeded(_ time: Double, force: Bool = false) {
        guard force || abs(currentTime - time) >= Self.playbackUIUpdateInterval else { return }
        currentTime = time
    }

    private func updateIsPlayingIfNeeded() {
        let nextValue = player.timeControlStatus == .playing
        guard isPlaying != nextValue else { return }
        isPlaying = nextValue
    }

    private func updateDurationIfNeeded() {
        let itemDuration = player.currentItem?.duration.seconds ?? 0
        guard itemDuration.isFinite else { return }
        guard abs(duration - itemDuration) > 0.001 else { return }
        duration = itemDuration
    }

    private func handlePlaybackBoundaryIfNeeded(at observedTime: Double) {
        guard let playbackMode else { return }
        switch playbackMode {
        case let .single(_, end):
            let stopBuffer = 0.05
            if observedTime >= end - stopBuffer {
                player.pause()
                let stoppedTime = max(observedTime, end - stopBuffer)
                currentTime = stoppedTime
                isPlaying = false
                self.playbackMode = nil
            }
        case let .ab(start, end):
            let stopBuffer = 0.04
            if observedTime >= end - stopBuffer {
                seek(to: start)
                play()
            }
        }
    }

    private func resolveSingleLineEnd(for line: SubtitleLine, index: Int) -> Double {
        let start = line.start
        var end = max(line.end, start + 0.2)
        if subtitleLines.indices.contains(index + 1) {
            let nextLine = subtitleLines[index + 1]
            if nextLine.start > start {
                end = min(end, max(start + 0.2, nextLine.start - 0.03))
            }
        }
        return max(start + 0.2, end)
    }

    private func normalizePlaybackRate(_ value: Double) -> Double {
        let fallback = 1.0
        let supported = availablePlaybackRates
        guard value.isFinite else { return fallback }
        return supported.min(by: { abs($0 - value) < abs($1 - value) }) ?? fallback
    }

    private func loadPreviewImage(from videoURL: URL, materialID: String) {
        previewImageTask?.cancel()
        previewImage = nil

        previewImageTask = Task { [weak self] in
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let image: UIImage?
            do {
                let result = try await generator.image(at: .zero)
                image = UIImage(cgImage: result.image)
            } catch {
                image = nil
            }

            guard !Task.isCancelled else { return }
            guard let self, self.material?.id == materialID else { return }
            self.previewImage = image
            self.previewImageTask = nil
        }
    }

    private func normalizeSubtitleScale(_ value: Double) -> Double {
        let supported = [1.0, 1.25, 1.5, 1.75]
        guard value.isFinite else { return 1.25 }
        return supported.min(by: { abs($0 - value) < abs($1 - value) }) ?? 1.25
    }

    private func resumeABPlayback(start: Double, end: Double) {
        let current = currentTime
        if current < start || current > end - 0.04 {
            seek(to: start)
        }
        play()
    }

    private func updateActiveSubtitleIndex(for time: Double) {
        let resolvedIndex: Int
        if pinnedSubtitleIndex >= 0, pinnedSubtitleIndex < subtitleLines.count {
            resolvedIndex = pinnedSubtitleIndex
        } else {
            resolvedIndex = Self.resolvedSubtitleIndex(for: time, in: subtitleLines)
        }

        guard activeSubtitleIndex != resolvedIndex else { return }
        activeSubtitleIndex = resolvedIndex
    }

    static func resolvedSubtitleIndex(for time: Double, in lines: [SubtitleLine]) -> Int {
        guard time.isFinite, !lines.isEmpty else { return -1 }
        guard time >= lines[0].start else { return -1 }

        var low = 0
        var high = lines.count
        while low < high {
            let mid = (low + high) / 2
            if time >= lines[mid].start {
                low = mid + 1
            } else {
                high = mid
            }
        }

        return low - 1
    }
}
