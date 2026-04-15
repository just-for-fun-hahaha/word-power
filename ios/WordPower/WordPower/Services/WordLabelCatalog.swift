import Foundation

struct WordLabelCatalog: Hashable {
    static let baseLabels = ["3000", "5000", "10000"]
    static let fallbackLabel = "10000+"
    static let builtInVersion = "built-in"
    static let fallbackWordTotal = 20_000

    var labels: [String: String]

    var count: Int {
        labels.count
    }

    func label(for word: String) -> String {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let label = labels[normalizedWord], Self.baseLabels.contains(label) else {
            return Self.fallbackLabel
        }

        return label
    }

    func tags(for word: String) -> [WordTag] {
        switch label(for: word) {
        case "3000": return [.top3000]
        case "5000": return [.top5000]
        case "10000": return [.top10000]
        default: return [.top10000Plus]
        }
    }

    func priority(for word: String) -> Int {
        switch label(for: word) {
        case "3000": return 3
        case "5000": return 2
        case "10000": return 1
        default: return 0
        }
    }

    func words(for label: String) -> Set<String> {
        Set(labels.compactMap { key, value in
            value == label ? key : nil
        })
    }

    static func load(bundle: Bundle = .main) throws -> WordLabelCatalog {
        guard let url = bundle.url(forResource: "word_labels", withExtension: "csv") else {
            throw NSError(domain: "WordPower.WordLabelCatalog", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing built-in word_labels.csv in app bundle."
            ])
        }

        let text = try String(contentsOf: url, encoding: .utf8)
        return WordLabelCatalog(labels: parseCSV(text))
    }

    static func parseCSV(_ text: String) -> [String: String] {
        let lines = text.replacingOccurrences(of: "\r", with: "").split(separator: "\n")
        guard !lines.isEmpty else {
            return [:]
        }

        let startIndex = lines.first?.localizedCaseInsensitiveContains("word,label") == true ? 1 : 0
        var result: [String: String] = [:]
        for line in lines.dropFirst(startIndex) {
            let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let label = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, baseLabels.contains(label) else { continue }
            result[word] = label
        }

        return result
    }
}
