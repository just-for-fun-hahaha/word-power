import Foundation

enum SubtitleParser {
    enum ParserError: LocalizedError {
        case unsupportedFile
        case invalidJSON
        case missingLinesArray
        case noValidLines

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return "Only SRT, VTT, or JSON subtitle files are supported."
            case .invalidJSON:
                return "Invalid JSON subtitle format."
            case .missingLinesArray:
                return "JSON subtitle file is missing the lines array."
            case .noValidLines:
                return "No valid subtitles were parsed from the file."
            }
        }
    }

    static func parse(url: URL) throws -> [SubtitleLine] {
        let data = try SecurityScopedFileAccess.withAccess(to: url) {
            try Data(contentsOf: url)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw ParserError.unsupportedFile
        }
        return try parse(text: text, fileName: url.lastPathComponent)
    }

    static func parse(text: String, fileName: String) throws -> [SubtitleLine] {
        let lowercasedName = fileName.lowercased()
        let lines: [SubtitleLine]
        if lowercasedName.hasSuffix(".srt") {
            lines = parseSRT(text)
        } else if lowercasedName.hasSuffix(".vtt") {
            lines = parseVTT(text)
        } else if lowercasedName.hasSuffix(".json") {
            lines = try parseJSON(text)
        } else {
            let srtLines = parseSRT(text)
            lines = srtLines.isEmpty && text.localizedCaseInsensitiveContains("WEBVTT")
                ? parseVTT(text)
                : srtLines
        }

        guard !lines.isEmpty else {
            throw ParserError.noValidLines
        }
        return lines
    }

    static func parseSRT(_ content: String) -> [SubtitleLine] {
        let blocks = content.replacingOccurrences(of: "\r", with: "").components(separatedBy: .newlines)
        var groupedBlocks: [[String]] = []
        var current: [String] = []
        for line in blocks {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    groupedBlocks.append(current)
                    current = []
                }
                continue
            }
            current.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !current.isEmpty {
            groupedBlocks.append(current)
        }

        var result: [SubtitleLine] = []
        for block in groupedBlocks {
            guard let timeLineIndex = block.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeLine = block[timeLineIndex]
            guard let match = timeLine.range(
                of: #"(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})"#,
                options: .regularExpression
            ) else {
                continue
            }

            let parts = String(timeLine[match]).components(separatedBy: "-->").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            guard let start = parseTimestamp(parts[0]), let end = parseTimestamp(parts[1]) else { continue }
            let text = block[(timeLineIndex + 1)...].joined(separator: " ")
            if let normalized = normalizeLine(index: result.count, start: start, end: end, text: text) {
                result.append(normalized)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    static func parseVTT(_ content: String) -> [SubtitleLine] {
        let cleaned = content
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: #"^\u{FEFF}?WEBVTT[^\n]*\n+"#, with: "", options: .regularExpression)
        let blocks = cleaned.components(separatedBy: "\n\n")
        var result: [SubtitleLine] = []
        for block in blocks {
            let lines = block.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeParts = lines[timeLineIndex].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard timeParts.count >= 3 else { continue }
            guard let start = parseTimestamp(timeParts[0]), let end = parseTimestamp(timeParts[2]) else { continue }
            let text = lines[(timeLineIndex + 1)...].joined(separator: " ")
            if let normalized = normalizeLine(index: result.count, start: start, end: end, text: text) {
                result.append(normalized)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    static func parseJSON(_ content: String) throws -> [SubtitleLine] {
        guard let data = content.data(using: .utf8) else {
            throw ParserError.invalidJSON
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        let rawLines: [[String: Any]]
        if let lines = rawObject as? [[String: Any]] {
            rawLines = lines
        } else if
            let object = rawObject as? [String: Any],
            let lines = object["lines"] as? [[String: Any]]
        {
            rawLines = lines
        } else {
            throw ParserError.missingLinesArray
        }

        var result: [SubtitleLine] = []
        for entry in rawLines {
            let start = (entry["start"] as? NSNumber)?.doubleValue ?? 0
            let end = (entry["end"] as? NSNumber)?.doubleValue ?? 0
            let duration = (entry["duration"] as? NSNumber)?.doubleValue ?? max(0.1, end - start)
            let text = entry["text"] as? String ?? ""
            if let line = normalizeLine(index: result.count, start: start, end: max(end, start + duration), text: text) {
                result.append(line)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    static func parseTimestamp(_ rawValue: String) -> Double? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = value.split(separator: ":")
        guard (2...3).contains(parts.count) else { return nil }
        guard
            let seconds = Double(parts[parts.count - 1]),
            let minutes = Double(parts[parts.count - 2])
        else {
            return nil
        }
        let hours = parts.count == 3 ? Double(parts[0]) ?? 0 : 0
        return hours * 3600 + minutes * 60 + seconds
    }

    static func normalizeLine(index: Int, start: Double, end: Double, text: String) -> SubtitleLine? {
        let normalizedText = WordPowerText.normalizeSubtitleText(text)
        guard !normalizedText.isEmpty else { return nil }
        let safeEnd = max(end, start + 0.1)
        return SubtitleLine(
            index: index,
            start: round(start * 1000) / 1000,
            end: round(safeEnd * 1000) / 1000,
            duration: round(max(0.1, safeEnd - start) * 1000) / 1000,
            text: normalizedText
        )
    }
}
