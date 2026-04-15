import Foundation
import NaturalLanguage
import UIKit

enum WordPowerText {
    static let articleChunkMaxWords = 110
    static let articleChunkMaxChars = 720

    private static let wordPattern = try! NSRegularExpression(
        pattern: #"[A-Za-z]+(?:['’][A-Za-z]+)*(?:-[A-Za-z]+(?:['’][A-Za-z]+)*)*"#
    )
    private static let htmlTagPattern = try! NSRegularExpression(
        pattern: #"<[A-Za-z!/][^>]*>"#
    )
    private static let htmlEntityPattern = try! NSRegularExpression(
        pattern: #"&(?:[A-Za-z]{2,10}|#[0-9]{2,5}|#x[0-9A-Fa-f]{2,4});"#
    )

    private static let validSingleCharacterWords: Set<String> = ["a", "i"]
    private static let hyphenPrefixParts: Set<String> = ["co", "re", "pre", "pro", "anti", "non", "de"]
    private static let lemmaProtectedWords: Set<String> = [
        "this",
        "analysis",
        "thesis",
        "crisis",
        "basis",
        "series",
        "species",
        "news",
        "neurips"
    ]
    private static let lemmaProtectedSuffixes = ["is", "us", "ss", "ous", "ics", "ips"]
    private static let lemmaIrregularMap: [String: String] = [
        "am": "be",
        "are": "be",
        "been": "be",
        "does": "do",
        "done": "do",
        "did": "do",
        "goes": "go",
        "has": "have",
        "is": "be",
        "was": "be",
        "were": "be"
    ]
    private static let contractionBaseGroups: [String: [String]] = [
        "'re": ["you", "we", "they", "these", "those", "who", "what", "where", "there"],
        "'ve": ["i", "you", "we", "they", "who", "what", "there"],
        "'ll": ["i", "you", "he", "she", "it", "we", "they", "that", "there", "who", "what"],
        "'m": ["i"],
        "'s": ["he", "she", "it", "that", "there", "here", "what", "where", "when", "why", "how", "who"]
    ]
    private static let contractionBaseExpansions: [String: String] = [
        "'re": "are",
        "'ve": "have",
        "'ll": "will",
        "'m": "am",
        "'s": "is"
    ]
    private static let contractionExactMap: [String: [String]] = {
        var exactMap: [String: [String]] = [
            "can't": ["can", "not"],
            "won't": ["will", "not"],
            "shan't": ["shall", "not"],
            "ain't": ["am", "not"],
            "let's": ["let", "us"]
        ]

        for (suffix, bases) in contractionBaseGroups {
            guard let expansion = contractionBaseExpansions[suffix] else { continue }
            for base in bases {
                exactMap["\(base)\(suffix)"] = [base, expansion]
            }
        }

        return exactMap
    }()

    static func stripHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    }

    static func decodeHTMLEntities(_ value: String) -> String {
        let range = NSRange(value.startIndex..., in: value)
        let containsHTMLTag = htmlTagPattern.firstMatch(in: value, options: [], range: range) != nil
        let containsHTMLEntity = htmlEntityPattern.firstMatch(in: value, options: [], range: range) != nil
        guard containsHTMLTag || containsHTMLEntity else {
            return value
        }
        let wrapped = "<span>\(value)</span>"
        guard let data = wrapped.data(using: .utf8) else { return value }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
        return attributed?.string ?? value
    }

    static func normalizeSubtitleText(_ value: String) -> String {
        decodeHTMLEntities(stripHTML(value)).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeArticleText(_ value: String) -> String {
        let plainText = decodeHTMLEntities(stripHTML(value)).replacingOccurrences(of: "\r", with: "")
        let paragraphs = plainText
            .components(separatedBy: .newlines)
            .reduce(into: [[String]]()) { result, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if !result.isEmpty, !result[result.count - 1].isEmpty {
                        result.append([])
                    }
                } else if result.isEmpty {
                    result.append([trimmed])
                } else {
                    result[result.count - 1].append(trimmed)
                }
            }
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs.joined(separator: "\n\n")
    }

    static func splitArticleIntoParagraphs(_ value: String) -> [String] {
        let normalized = normalizeArticleText(value)
        guard !normalized.isEmpty else { return [] }
        return normalized.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    static func splitLongTextIntoReaderChunks(_ value: String) -> [String] {
        let normalized = normalizeSubtitleText(value)
        guard !normalized.isEmpty else { return [] }

        let words = normalized.split(whereSeparator: \.isWhitespace)
        if words.count <= articleChunkMaxWords, normalized.count <= articleChunkMaxChars {
            return [normalized]
        }

        let sentenceChunks = sentenceAwareChunks(for: normalized)
        if !sentenceChunks.isEmpty {
            return sentenceChunks
        }

        return wordPackedChunks(for: normalized)
    }

    private static func sentenceAwareChunks(for text: String) -> [String] {
        let sentences = splitIntoSentences(text)
        guard sentences.count > 1 else { return [] }

        var chunks: [String] = []
        var currentSentences: [String] = []
        var currentLength = 0

        for sentence in sentences {
            let sentenceWordCount = sentence.split(whereSeparator: \.isWhitespace).count
            if sentenceWordCount > articleChunkMaxWords || sentence.count > articleChunkMaxChars {
                if !currentSentences.isEmpty {
                    chunks.append(currentSentences.joined(separator: " "))
                    currentSentences.removeAll(keepingCapacity: true)
                    currentLength = 0
                }
                chunks.append(contentsOf: wordPackedChunks(for: sentence))
                continue
            }

            let currentWordCount = currentSentences.reduce(into: 0) { count, value in
                count += value.split(whereSeparator: \.isWhitespace).count
            }
            let nextWordCount = currentWordCount + sentenceWordCount
            let nextLength = currentSentences.isEmpty ? sentence.count : currentLength + 1 + sentence.count
            if !currentSentences.isEmpty,
               (nextWordCount > articleChunkMaxWords || nextLength > articleChunkMaxChars) {
                chunks.append(currentSentences.joined(separator: " "))
                currentSentences = [sentence]
                currentLength = sentence.count
                continue
            }

            currentSentences.append(sentence)
            currentLength = nextLength
        }

        if !currentSentences.isEmpty {
            chunks.append(currentSentences.joined(separator: " "))
        }

        return chunks
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    private static func wordPackedChunks(for text: String) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }

        var chunks: [String] = []
        var currentWords: [String] = []
        var currentLength = 0

        for word in words {
            let nextLength = currentWords.isEmpty ? word.count : currentLength + 1 + word.count
            if !currentWords.isEmpty && (currentWords.count >= articleChunkMaxWords || nextLength > articleChunkMaxChars) {
                chunks.append(currentWords.joined(separator: " "))
                currentWords = [word]
                currentLength = word.count
                continue
            }

            currentWords.append(word)
            currentLength = nextLength
        }

        if !currentWords.isEmpty {
            chunks.append(currentWords.joined(separator: " "))
        }

        return chunks
    }

    static func buildArticleReaderUnits(paragraphs: [String]) -> [ArticleReaderUnit] {
        var units: [ArticleReaderUnit] = []
        var sourceIndex = 0

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let normalizedParagraph = normalizeSubtitleText(paragraph)
            guard !normalizedParagraph.isEmpty else { continue }

            for (unitIndex, chunk) in splitLongTextIntoReaderChunks(normalizedParagraph).enumerated() {
                units.append(ArticleReaderUnit(
                    key: "article-reader-unit-\(paragraphIndex)-\(unitIndex)",
                    text: chunk,
                    paragraphIndex: paragraphIndex,
                    isParagraphStart: unitIndex == 0,
                    sourceIndex: sourceIndex
                ))
                sourceIndex += 1
            }
        }

        return units
    }

    static func buildArticleAnalysisLines(paragraphs: [String]) -> [SubtitleLine] {
        paragraphs.enumerated().compactMap { index, paragraph in
            let text = normalizeSubtitleText(paragraph)
            guard !text.isEmpty else { return nil }
            return SubtitleLine(index: index, start: Double(index), end: Double(index + 1), duration: 1, text: text)
        }
    }

    static func extractWords(from text: String) -> [String] {
        let nsText = text as NSString
        let matches = tokenMatches(in: text)
        var words: [String] = []
        for match in matches {
            let rawToken = nsText.substring(with: match.range)
            let parts = rawToken.lowercased()
                .split(separator: "-")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let hasHyphen = parts.count > 1
            for (index, part) in parts.enumerated() {
                let normalizedPart = part.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
                if hasHyphen && index < parts.count - 1 && hyphenPrefixParts.contains(normalizedPart) {
                    continue
                }
                expandContraction(part).forEach { item in
                    if isValidWordToken(item) {
                        words.append(item)
                    }
                }
            }
        }
        return words
    }

    static func tokenMatches(in text: String) -> [NSTextCheckingResult] {
        let nsText = text as NSString
        return wordPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    }

    static func expandContraction(_ rawToken: String) -> [String] {
        let token = rawToken.lowercased().replacingOccurrences(of: "’", with: "'")
        if let exact = contractionExactMap[token] {
            return exact
        }
        if token.hasSuffix("n't"), token.count > 3 {
            return [normalizeNegativeContractionBase(String(token.dropLast(3))), "not"]
        }
        if token.hasSuffix("'re"), token.count > 3 { return [String(token.dropLast(3)), "are"] }
        if token.hasSuffix("'ve"), token.count > 3 { return [String(token.dropLast(3)), "have"] }
        if token.hasSuffix("'ll"), token.count > 3 { return [String(token.dropLast(3)), "will"] }
        if token.hasSuffix("'m"), token.count > 2 { return [String(token.dropLast(2)), "am"] }
        if token.hasSuffix("'d"), token.count > 2 { return [String(token.dropLast(2))] }
        if token.hasSuffix("'s"), token.count > 2 { return [String(token.dropLast(2))] }
        return [token.replacingOccurrences(of: "'", with: "")]
    }

    static func simpleLemmatize(_ word: String, catalog: WordLabelCatalog, learningRecords: [String: LearningRecord], contextWords: Set<String>) -> String {
        let normalizedWord = word.lowercased()
        if let irregular = lemmaIrregularMap[normalizedWord] {
            return irregular
        }

        let candidates = buildLemmaCandidates(for: normalizedWord)
        var bestCandidate = normalizedWord
        var bestScore = Double.leastNormalMagnitude
        for candidate in candidates {
            let score = scoreLemmaCandidate(
                source: normalizedWord,
                candidate: candidate,
                catalog: catalog,
                learningRecords: learningRecords,
                contextWords: contextWords,
                allCandidates: candidates
            )
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate.candidate
            }
        }

        return bestScore > Double.leastNormalMagnitude ? bestCandidate : normalizedWord
    }

    private static func isValidWordToken(_ token: String) -> Bool {
        token.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil &&
            (token.count >= 2 || validSingleCharacterWords.contains(token))
    }

    private static func normalizeNegativeContractionBase(_ base: String) -> String {
        switch base {
        case "ca": return "can"
        case "wo": return "will"
        case "sha": return "shall"
        default: return base
        }
    }

    private static func isConsonant(_ character: Character) -> Bool {
        "bcdfghjklmnpqrstvwxyz".contains(character)
    }

    private static func hasDoubleConsonantEnding(_ stem: String) -> Bool {
        guard stem.count >= 2 else { return false }
        let characters = Array(stem)
        let last = characters[characters.count - 1]
        let previous = characters[characters.count - 2]
        return last == previous && isConsonant(last)
    }

    private static func addLemmaCandidate(_ candidates: inout [LemmaCandidate], candidate: String, kind: String) {
        guard isValidWordToken(candidate) else { return }
        guard !candidates.contains(where: { $0.candidate == candidate }) else { return }
        candidates.append(LemmaCandidate(candidate: candidate, kind: kind))
    }

    private static func buildLemmaCandidates(for word: String) -> [LemmaCandidate] {
        guard word.count > 3 else { return [] }
        var candidates: [LemmaCandidate] = []

        if word.hasSuffix("ies"), word.count > 4, word.range(of: #"[^aeiou]ies$"#, options: .regularExpression) != nil {
            addLemmaCandidate(&candidates, candidate: String(word.dropLast(3)) + "y", kind: "y_restore")
        }
        if word.hasSuffix("ied"), word.count > 4 {
            addLemmaCandidate(&candidates, candidate: String(word.dropLast(3)) + "y", kind: "y_restore")
        }
        if word.hasSuffix("ing"), word.count > 5 {
            let stem = String(word.dropLast(3))
            addLemmaCandidate(&candidates, candidate: stem, kind: "bare")
            if !stem.hasSuffix("e") {
                addLemmaCandidate(&candidates, candidate: stem + "e", kind: "silent_e")
            }
            if hasDoubleConsonantEnding(stem) {
                addLemmaCandidate(&candidates, candidate: String(stem.dropLast()), kind: "undouble")
            }
        }
        if word.hasSuffix("ed"), word.count > 4 {
            let stem = String(word.dropLast(2))
            addLemmaCandidate(&candidates, candidate: stem, kind: "bare")
            if !stem.hasSuffix("e") {
                addLemmaCandidate(&candidates, candidate: stem + "e", kind: "silent_e")
            }
            if hasDoubleConsonantEnding(stem) {
                addLemmaCandidate(&candidates, candidate: String(stem.dropLast()), kind: "undouble")
            }
        }
        if word.hasSuffix("es"), word.count > 4 {
            if word.range(of: #"(?:sses|xes|zes|ches|shes)$"#, options: .regularExpression) != nil {
                addLemmaCandidate(&candidates, candidate: String(word.dropLast(2)), kind: "es_plural")
            }
            addLemmaCandidate(&candidates, candidate: String(word.dropLast()), kind: "s_plural")
        }
        if
            word.hasSuffix("s"),
            word.count > 3,
            !lemmaProtectedWords.contains(word),
            !lemmaProtectedSuffixes.contains(where: { word.hasSuffix($0) }),
            word.range(of: #"[^aeiouy]s$"#, options: .regularExpression) != nil
        {
            addLemmaCandidate(&candidates, candidate: String(word.dropLast()), kind: "s_plural")
        }

        return candidates
    }

    private static func scoreLemmaCandidate(
        source: String,
        candidate: LemmaCandidate,
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord],
        contextWords: Set<String>,
        allCandidates: [LemmaCandidate]
    ) -> Double {
        guard candidate.candidate != source else { return -.infinity }
        guard isValidWordToken(candidate.candidate), candidate.candidate.count > 2 else { return -.infinity }
        let hasLabel = catalog.labels[candidate.candidate] != nil
        let inContext = contextWords.contains(candidate.candidate)
        guard hasLabel || inContext else { return -.infinity }

        var score = Double(catalog.priority(for: candidate.candidate) * 100)
        score += Double(learningRecords[candidate.candidate]?.familiarity ?? 0) * 10
        if inContext {
            score += 4
        }
        if candidate.kind == "bare" && (hasLabel || learningRecords[candidate.candidate] != nil) {
            score += 6
        }
        if candidate.kind == "y_restore" {
            score += 10
        }
        if candidate.kind == "undouble" {
            score += 6
        }
        if candidate.kind == "silent_e" {
            score += hasLabel || learningRecords[candidate.candidate] != nil ? 12 : -12
            if let bareCandidate = allCandidates.first(where: { $0.kind == "bare" }) {
                let barePriority = catalog.priority(for: bareCandidate.candidate)
                let candidatePriority = catalog.priority(for: candidate.candidate)
                if barePriority > candidatePriority {
                    score -= Double(20 + (barePriority - candidatePriority) * 10)
                }
            }
        }
        score += Double(candidate.candidate.count) * 0.01
        return score
    }

    private struct LemmaCandidate: Hashable {
        var candidate: String
        var kind: String
    }
}
