import Foundation

actor AppFileStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rootDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        rootDirectoryURL: URL? = AppFileStore.defaultRootDirectoryURL()
    ) {
        self.fileManager = fileManager
        self.rootDirectoryURL = rootDirectoryURL ?? Self.defaultRootDirectoryURL(fileManager: fileManager)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadState() throws -> PersistedAppState {
        try ensureDirectories()
        let learningRecords = loadValue([String: LearningRecord].self, from: learningRecordsURL(), default: [:])
        let materials = loadValue([MaterialRecord].self, from: materialsIndexURL(), default: [])
        let readerProgress = loadValue([String: ReaderProgress].self, from: readerProgressURL(), default: [:])
        let settings = loadValue(AppSettings.self, from: settingsURL(), default: AppSettings())
        let readerSession = loadOptionalValue(ReaderSessionData.self, from: readerSessionURL())
        return PersistedAppState(
            learningRecords: learningRecords,
            materials: materials,
            readerProgress: readerProgress,
            settings: settings,
            readerSession: readerSession
        )
    }

    func saveLearningRecords(_ records: [String: LearningRecord]) throws {
        try ensureDirectories()
        try saveJSON(records, to: learningRecordsURL())
    }

    func saveMaterials(_ materials: [MaterialRecord]) throws {
        try ensureDirectories()
        try saveJSON(materials, to: materialsIndexURL())
    }

    func saveReaderProgress(_ progress: [String: ReaderProgress]) throws {
        try ensureDirectories()
        try saveJSON(progress, to: readerProgressURL())
    }

    func saveSettings(_ settings: AppSettings) throws {
        try ensureDirectories()
        try saveJSON(settings, to: settingsURL())
    }

    func saveReaderSession(_ session: ReaderSessionData?) throws {
        try ensureDirectories()
        if let session {
            try saveJSON(session, to: readerSessionURL())
        } else if fileManager.fileExists(atPath: readerSessionURL().path) {
            try fileManager.removeItem(at: readerSessionURL())
        }
    }

    func importFiles(materialID: String, videoURL: URL?, subtitleURL: URL?) throws -> ImportedMaterialFiles {
        try ensureDirectories()
        let materialDirectory = materialsDirectory().appendingPathComponent(materialID, isDirectory: true)
        if !fileManager.fileExists(atPath: materialDirectory.path) {
            try fileManager.createDirectory(at: materialDirectory, withIntermediateDirectories: true)
        }

        var imported = ImportedMaterialFiles()
        if let videoURL {
            let destination = materialDirectory.appendingPathComponent("video" + "." + videoURL.pathExtension)
            try copyImportedFile(from: videoURL, to: destination)
            imported.videoRelativePath = relativeMaterialPath(for: materialID, fileName: destination.lastPathComponent)
        }
        if let subtitleURL {
            let destination = materialDirectory.appendingPathComponent("subtitle" + "." + subtitleURL.pathExtension)
            try copyImportedFile(from: subtitleURL, to: destination)
            imported.subtitleRelativePath = relativeMaterialPath(for: materialID, fileName: destination.lastPathComponent)
        }

        return imported
    }

    func removeFiles(for materialID: String) throws {
        let materialDirectory = materialsDirectory().appendingPathComponent(materialID, isDirectory: true)
        guard fileManager.fileExists(atPath: materialDirectory.path) else { return }
        try fileManager.removeItem(at: materialDirectory)
    }

    func materialFileURL(relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        return appSupportDirectory().appendingPathComponent(relativePath)
    }

    private func appSupportDirectory() -> URL {
        rootDirectoryURL
    }

    private func materialsDirectory() -> URL {
        appSupportDirectory().appendingPathComponent("Materials", isDirectory: true)
    }

    private func learningRecordsURL() -> URL {
        appSupportDirectory().appendingPathComponent("learning-records.json")
    }

    private func materialsIndexURL() -> URL {
        appSupportDirectory().appendingPathComponent("materials-index.json")
    }

    private func readerProgressURL() -> URL {
        appSupportDirectory().appendingPathComponent("reader-progress.json")
    }

    private func settingsURL() -> URL {
        appSupportDirectory().appendingPathComponent("settings.json")
    }

    private func readerSessionURL() -> URL {
        appSupportDirectory().appendingPathComponent("reader-session.json")
    }

    private func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: appSupportDirectory().path) {
            try fileManager.createDirectory(at: appSupportDirectory(), withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: materialsDirectory().path) {
            try fileManager.createDirectory(at: materialsDirectory(), withIntermediateDirectories: true)
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    private func loadValue<T: Decodable>(_ type: T.Type, from url: URL, default defaultValue: @autoclosure () -> T) -> T {
        do {
            return try loadJSON(type, from: url) ?? defaultValue()
        } catch {
            print("AppFileStore: failed to load \(url.lastPathComponent): \(error)")
            return defaultValue()
        }
    }

    private func loadOptionalValue<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            return try loadJSON(type, from: url)
        } catch {
            print("AppFileStore: failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func saveJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func relativeMaterialPath(for materialID: String, fileName: String) -> String {
        "Materials/\(materialID)/\(fileName)"
    }

    private func copyImportedFile(from sourceURL: URL, to destinationURL: URL) throws {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private static func defaultRootDirectoryURL(fileManager: FileManager = .default) -> URL {
        if let customPath = ProcessInfo.processInfo.environment["WORDPOWER_APP_SUPPORT_ROOT"], !customPath.isEmpty {
            return URL(fileURLWithPath: customPath, isDirectory: true)
        }

        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WordPower", isDirectory: true)
    }
}
