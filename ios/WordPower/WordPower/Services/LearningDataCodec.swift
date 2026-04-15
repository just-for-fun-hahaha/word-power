import Foundation

enum LearningDataCodec {
    static let maxFamiliarityLevel = 5
    static let currentHeader = "word,familiarity,updated_at"
    private static let iso8601Formatter = ISO8601DateFormatter()

    static func normalizeFamiliarity(_ value: some BinaryInteger) -> Int {
        max(0, min(maxFamiliarityLevel, Int(value)))
    }

    static func normalizeFamiliarity(_ value: String) -> Int {
        guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 0
        }

        return normalizeFamiliarity(number)
    }

    static func normalizedDate(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return trimmed
        }

        return iso8601Formatter.string(from: .now).prefix(10).description
    }

    static func exportCSV(_ records: [String: LearningRecord]) -> String {
        let sortedRecords = records.sorted { $0.key < $1.key }
        var rows = [currentHeader]
        rows.append(contentsOf: sortedRecords.map { word, record in
            "\(word),\(normalizeFamiliarity(record.familiarity)),\(normalizedDate(record.updatedAt))"
        })
        return rows.joined(separator: "\n") + "\n"
    }

    static func parseCSV(_ text: String) throws -> [String: LearningRecord] {
        let normalizedLines = text.replacingOccurrences(of: "\r", with: "").split(separator: "\n").map(String.init)
        guard !normalizedLines.isEmpty else {
            return [:]
        }

        let header = normalizedLines[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if header == currentHeader || header == "word,stars,updated_at" {
            return parseCurrentCSV(Array(normalizedLines.dropFirst()))
        }

        return parseLegacyCSV(normalizedLines)
    }

    static func parseCurrentCSV(_ lines: [String]) -> [String: LearningRecord] {
        var result: [String: LearningRecord] = [:]
        for line in lines where !line.isEmpty {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let familiarity = normalizeFamiliarity(String(parts[1]))
            let updatedAt = parts.count > 2 ? normalizedDate(String(parts[2])) : normalizedDate(nil)
            guard !word.isEmpty, familiarity > 0 else { continue }
            result[word] = LearningRecord(familiarity: familiarity, updatedAt: updatedAt)
        }
        return result
    }

    static func parseLegacyCSV(_ lines: [String]) -> [String: LearningRecord] {
        let hasHeader = lines.first?.localizedCaseInsensitiveContains("word,date") == true
        var result: [String: LearningRecord] = [:]
        for line in lines.dropFirst(hasHeader ? 1 : 0) where !line.isEmpty {
            let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let updatedAt = normalizedDate(String(parts[1]))
            guard !word.isEmpty else { continue }
            result[word] = LearningRecord(familiarity: maxFamiliarityLevel, updatedAt: updatedAt)
        }
        return result
    }

    static func normalizeRecords(_ records: [String: LearningRecord]) -> [String: LearningRecord] {
        var normalized: [String: LearningRecord] = [:]
        for (word, record) in records {
            let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let familiarity = normalizeFamiliarity(record.familiarity)
            guard !normalizedWord.isEmpty, familiarity > 0 else { continue }
            normalized[normalizedWord] = LearningRecord(
                familiarity: familiarity,
                updatedAt: normalizedDate(record.updatedAt)
            )
        }
        return normalized
    }
}
