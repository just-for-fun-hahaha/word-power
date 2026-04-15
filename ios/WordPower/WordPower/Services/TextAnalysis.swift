import Foundation

enum TextAnalysis {
    static func masteredWords(from learningRecords: [String: LearningRecord]) -> [String: String] {
        var result: [String: String] = [:]
        for (word, record) in learningRecords where record.familiarity == LearningDataCodec.maxFamiliarityLevel {
            result[word] = LearningDataCodec.normalizedDate(record.updatedAt)
        }
        return result
    }

    static func wordFamiliarity(_ word: String, learningRecords: [String: LearningRecord]) -> Int {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return LearningDataCodec.normalizeFamiliarity(learningRecords[normalizedWord]?.familiarity ?? 0)
    }

    static func wordUpdatedAt(_ word: String, learningRecords: [String: LearningRecord]) -> String {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return learningRecords[normalizedWord]?.updatedAt ?? ""
    }

    static func buildNormalizedLemmaLines(
        lines: [SubtitleLine],
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> [[String]] {
        let transcriptWordSet = Set(lines.flatMap { WordPowerText.extractWords(from: $0.text) })
        return lines.map { line in
            WordPowerText.extractWords(from: line.text).map {
                WordPowerText.simpleLemmatize($0, catalog: catalog, learningRecords: learningRecords, contextWords: transcriptWordSet)
            }
        }
    }

    static func analyzeWords(
        lines: [SubtitleLine],
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> [AnalysisWordRow] {
        let lemmaLines = buildNormalizedLemmaLines(lines: lines, catalog: catalog, learningRecords: learningRecords)
        var wordCounter: [String: Int] = [:]
        for words in lemmaLines {
            for word in words {
                wordCounter[word, default: 0] += 1
            }
        }

        let masteredSet = Set(masteredWords(from: learningRecords).keys)
        return sortAnalysisRows(wordCounter.map { word, count in
            AnalysisWordRow(
                word: word,
                count: count,
                tags: catalog.tags(for: word),
                familiarity: wordFamiliarity(word, learningRecords: learningRecords),
                mastered: masteredSet.contains(word),
                updatedAt: wordUpdatedAt(word, learningRecords: learningRecords)
            )
        })
    }

    static func sortAnalysisRows(_ rows: [AnalysisWordRow]) -> [AnalysisWordRow] {
        rows.sorted { lhs, rhs in
            let lhsRank = difficultyRank(for: lhs.tags)
            let rhsRank = difficultyRank(for: rhs.tags)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            if lhs.familiarity != rhs.familiarity {
                return lhs.familiarity > rhs.familiarity
            }
            return lhs.word < rhs.word
        }
    }

    static func buildVocabularyOverview(
        rows: [AnalysisWordRow]
    ) -> VocabularyOverview {
        var tagCounts: [WordTag: TagCountSummary] = [:]
        for tag in WordTag.allCases {
            tagCounts[tag] = TagCountSummary()
        }
        for row in rows {
            for tag in row.tags {
                var summary = tagCounts[tag] ?? TagCountSummary()
                summary.total += 1
                if row.mastered {
                    summary.mastered += 1
                } else {
                    summary.unmastered += 1
                }
                tagCounts[tag] = summary
            }
        }
        return VocabularyOverview(
            uniqueWords: rows.count,
            masteredWords: rows.filter(\.mastered).count,
            tagCounts: tagCounts
        )
    }

    static func buildLearningProgress(
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> [LearningProgressItem] {
        let masteredSet = Set(masteredWords(from: learningRecords).keys)
        let labels = WordLabelCatalog.baseLabels
        var items: [LearningProgressItem] = labels.map { label in
            let words = catalog.words(for: label)
            let mastered = words.filter { masteredSet.contains($0) }.count
            let total = words.count
            let percentage = total > 0 ? (Double(mastered) / Double(total)) * 100 : 0
            return LearningProgressItem(
                label: label,
                title: label == "3000" ? "Top 3000" : "Top \(label)",
                total: total,
                mastered: mastered,
                percentage: percentage
            )
        }

        let fallbackMastered = masteredSet.filter { catalog.label(for: $0) == WordLabelCatalog.fallbackLabel }.count
        let fallbackPercentage = min(Double(fallbackMastered), Double(WordLabelCatalog.fallbackWordTotal)) / Double(WordLabelCatalog.fallbackWordTotal) * 100
        items.append(
            LearningProgressItem(
                label: WordLabelCatalog.fallbackLabel,
                title: WordLabelCatalog.fallbackLabel,
                total: WordLabelCatalog.fallbackWordTotal,
                mastered: fallbackMastered,
                percentage: fallbackPercentage
            )
        )
        return items
    }

    static func buildFamiliarityRows(
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> [FamiliarityReviewRow] {
        learningRecords
            .compactMap { word, record in
                guard (1...4).contains(record.familiarity) else { return nil }
                return FamiliarityReviewRow(
                    word: word,
                    familiarity: record.familiarity,
                    updatedAt: record.updatedAt,
                    tags: catalog.tags(for: word)
                )
            }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.word < $1.word
            }
    }

    static func buildStatistics(
        learningRecords: [String: LearningRecord],
        granularity: StatsGranularity
    ) -> [LearningStatPoint] {
        var dateCounts: [String: Int] = [:]
        for record in learningRecords.values where record.familiarity == LearningDataCodec.maxFamiliarityLevel {
            let key = granularity == .month ? String(record.updatedAt.prefix(7)) : record.updatedAt
            dateCounts[key, default: 0] += 1
        }

        var cumulative = 0
        return dateCounts.keys.sorted().map { date in
            cumulative += dateCounts[date, default: 0]
            return LearningStatPoint(date: date, newWords: dateCounts[date, default: 0], cumulative: cumulative)
        }
    }

    static func buildSummary(lines: [SubtitleLine], catalog: WordLabelCatalog, learningRecords: [String: LearningRecord]) -> String {
        let lemmaLines = buildNormalizedLemmaLines(lines: lines, catalog: catalog, learningRecords: learningRecords)
        let totalWords = lemmaLines.reduce(0) { $0 + $1.count }
        let uniqueWords = Set(lemmaLines.flatMap { $0 }).count
        return "\(lines.count) paragraphs · \(totalWords) words · \(uniqueWords) unique"
    }

    static func buildCoverageStats(
        lines: [SubtitleLine],
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> (top3000: Double, top5000: Double, mastered: Double) {
        let lemmaLines = buildNormalizedLemmaLines(lines: lines, catalog: catalog, learningRecords: learningRecords)
        let words = lemmaLines.flatMap { $0 }
        guard !words.isEmpty else { return (0, 0, 0) }

        var top3000 = 0
        var top5000 = 0
        var mastered = 0
        for word in words {
            let label = catalog.label(for: word)
            if label == "3000" {
                top3000 += 1
                top5000 += 1
            } else if label == "5000" {
                top5000 += 1
            }
            if wordFamiliarity(word, learningRecords: learningRecords) == LearningDataCodec.maxFamiliarityLevel {
                mastered += 1
            }
        }

        return (
            (Double(top3000) / Double(words.count)) * 100,
            (Double(top5000) / Double(words.count)) * 100,
            (Double(mastered) / Double(words.count)) * 100
        )
    }

    static func buildDifficultyAssessment(
        sourceKind: AnalysisSourceKind,
        lines: [SubtitleLine],
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> DifficultyAssessment? {
        let normalizedLineWords = buildNormalizedLemmaLines(lines: lines, catalog: catalog, learningRecords: learningRecords)
        guard !normalizedLineWords.isEmpty else { return nil }

        let masteredSet = Set(masteredWords(from: learningRecords).keys)
        var labelUniqueSets: [String: Set<String>] = [
            "3000": [],
            "5000": [],
            "10000": [],
            "10000+": []
        ]
        var uniqueWords: Set<String> = []
        var totalTokens = 0
        var unknownTokens = 0
        var sentenceCount = 0
        var linesWithUnknown = 0
        var cleanLines = 0
        var longLines = 0
        var longLinesWithUnknown = 0

        for words in normalizedLineWords where !words.isEmpty {
            sentenceCount += 1
            let isLongLine = words.count >= 9
            if isLongLine {
                longLines += 1
            }

            var lineUnknownCount = 0
            for word in words {
                totalTokens += 1
                uniqueWords.insert(word)
                labelUniqueSets[catalog.label(for: word), default: []].insert(word)
                if !masteredSet.contains(word) {
                    unknownTokens += 1
                    lineUnknownCount += 1
                }
            }
            if lineUnknownCount > 0 {
                linesWithUnknown += 1
                if isLongLine {
                    longLinesWithUnknown += 1
                }
            } else {
                cleanLines += 1
            }
        }

        guard totalTokens > 0, sentenceCount > 0, !uniqueWords.isEmpty else { return nil }

        let uniqueCount = uniqueWords.count
        let unknownUniqueCount = uniqueWords.filter { !masteredSet.contains($0) }.count
        let uniquePerThousand = (Double(uniqueCount) / Double(totalTokens)) * 1000
        let avgLineLength = Double(totalTokens) / Double(sentenceCount)
        let offListUniqueRatio = Double(labelUniqueSets["10000+", default: []].count) / Double(uniqueCount)
        let unknownUniqueRatio = Double(unknownUniqueCount) / Double(uniqueCount)
        let linesWithUnknownRatio = Double(linesWithUnknown) / Double(sentenceCount)
        let cleanLineRatio = Double(cleanLines) / Double(sentenceCount)
        let longLineRatio = Double(longLines) / Double(sentenceCount)
        let longLinesWithUnknownRatio = Double(longLinesWithUnknown) / Double(sentenceCount)
        let durationSeconds = max(1, (lines.last?.end ?? 0) - (lines.first?.start ?? 0))
        let unknownWordsPerMinute = Double(unknownTokens) / (durationSeconds / 60)

        let objectiveScore = roundMetric(
            normalizeScore(uniquePerThousand, min: 180, max: 360) * 0.35 +
                normalizeScore(offListUniqueRatio * 100, min: 2, max: 22) * 0.25 +
                normalizeScore(avgLineLength, min: 4.5, max: 12) * 0.2 +
                normalizeScore(longLineRatio * 100, min: 15, max: 55) * 0.2
        )
        let personalScore = roundMetric(
            normalizeScore(linesWithUnknownRatio * 100, min: 15, max: 70) * 0.4 +
                normalizeScore(unknownWordsPerMinute, min: 2, max: 8) * 0.35 +
                normalizeScore(longLinesWithUnknownRatio * 100, min: 5, max: 35) * 0.15 +
                normalizeScore(unknownUniqueRatio * 100, min: 5, max: 45) * 0.1
        )

        let objective = difficultyComponent(
            score: objectiveScore,
            description: buildObjectiveDescription(
                uniquePerThousand: roundMetric(uniquePerThousand, digits: 1),
                offListUniqueRatioPct: roundMetric(offListUniqueRatio * 100, digits: 1),
                avgLineLength: roundMetric(avgLineLength, digits: 1),
                longLineRatioPct: roundMetric(longLineRatio * 100, digits: 1)
            )
        )
        let personal = difficultyComponent(
            score: personalScore,
            description: buildPersonalDescription(
                unknownWordsPerMinute: roundMetric(unknownWordsPerMinute, digits: 1),
                cleanLineRatioPct: roundMetric(cleanLineRatio * 100, digits: 1),
                linesWithUnknownRatioPct: roundMetric(linesWithUnknownRatio * 100, digits: 1),
                longLinesWithUnknownRatioPct: roundMetric(longLinesWithUnknownRatio * 100, digits: 1)
            )
        )

        return DifficultyAssessment(
            sampleLabel: difficultySampleLabel(
                sourceKind: sourceKind,
                sentenceCount: sentenceCount,
                totalTokens: totalTokens,
                durationSeconds: durationSeconds
            ),
            summary: buildDifficultyNarrative(objective: objective.score, personal: personal.score),
            objective: objective,
            personal: personal,
            metrics: [
                DifficultyMetric(
                    label: "Unknown Words / Minute",
                    value: String(roundMetric(unknownWordsPerMinute, digits: 1)),
                    hint: "About 3 to 5 unknown words per minute is the comfort zone for chunk-based practice."
                ),
                DifficultyMetric(
                    label: "Clean Lines",
                    value: "\(roundMetric(cleanLineRatio * 100, digits: 1))%",
                    hint: "Lines with zero unknown words. The app measures subtitle lines, not full grammar sentences."
                ),
                DifficultyMetric(
                    label: "Unmastered Unique Word Share",
                    value: "\(roundMetric(unknownUniqueRatio * 100, digits: 1))%",
                    hint: "Among unique words in this material, this is the percentage you have not mastered yet."
                )
            ]
        )
    }

    static func buildUnmasteredWords(
        label: String,
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord]
    ) -> [UnmasteredWordRow] {
        let words: [String]
        if label == WordLabelCatalog.fallbackLabel {
            words = learningRecords.keys.filter { catalog.label(for: $0) == WordLabelCatalog.fallbackLabel }
        } else {
            words = Array(catalog.words(for: label))
        }

        return words
            .filter { wordFamiliarity($0, learningRecords: learningRecords) < LearningDataCodec.maxFamiliarityLevel }
            .sorted()
            .map(UnmasteredWordRow.init)
    }

    private static func difficultyComponent(score: Double, description: String) -> DifficultyComponent {
        let roundedScore = Int(score.rounded())
        let descriptor: (String, String)
        switch roundedScore {
        case ..<25: descriptor = ("Easy", "easy")
        case ..<50: descriptor = ("Moderate", "medium")
        case ..<75: descriptor = ("Hard", "hard")
        default: descriptor = ("Very Hard", "very-hard")
        }
        return DifficultyComponent(score: roundedScore, label: descriptor.0, levelKey: descriptor.1, description: description)
    }

    private static func difficultySampleLabel(
        sourceKind: AnalysisSourceKind,
        sentenceCount: Int,
        totalTokens: Int,
        durationSeconds: Double
    ) -> String {
        switch sourceKind {
        case .subtitle:
            return "\(sentenceCount) lines · \(totalTokens) tokens · \(roundMetric(durationSeconds / 60, digits: 1)) min"
        case .article:
            return "\(sentenceCount) paragraphs · \(totalTokens) tokens"
        }
    }

    private static func buildObjectiveDescription(uniquePerThousand: Double, offListUniqueRatioPct: Double, avgLineLength: Double, longLineRatioPct: Double) -> String {
        var reasons: [String] = []
        if uniquePerThousand >= 320 { reasons.append("fast-changing vocabulary") }
        if offListUniqueRatioPct >= 15 { reasons.append("many off-list words") }
        if avgLineLength >= 9 { reasons.append("longer sentences") }
        if longLineRatioPct >= 35 { reasons.append("many longer subtitle lines") }
        return reasons.isEmpty ? "Vocabulary density and sentence length are fairly steady." : reasons.joined(separator: ", ") + "."
    }

    private static func buildPersonalDescription(unknownWordsPerMinute: Double, cleanLineRatioPct: Double, linesWithUnknownRatioPct: Double, longLinesWithUnknownRatioPct: Double) -> String {
        if unknownWordsPerMinute <= 2, cleanLineRatioPct >= 70 {
            return "Most lines are clean for shadowing, so this behaves more like review than growth input."
        }
        if unknownWordsPerMinute <= 5, linesWithUnknownRatioPct <= 40, longLinesWithUnknownRatioPct <= 18 {
            return "The pressure is present but controlled, which matches chunk-based shadowing fairly well."
        }
        if unknownWordsPerMinute <= 7, linesWithUnknownRatioPct <= 60, longLinesWithUnknownRatioPct <= 30 {
            return "You can still work with it, but many lines will require pausing, splitting, or replaying."
        }
        if linesWithUnknownRatioPct >= 70 {
            return "Most lines contain at least one unknown word, so it is not clean enough for comfortable shadowing."
        }
        return "The line-by-line pressure is high for chunk accumulation, so previewing key words will help."
    }

    private static func buildDifficultyNarrative(objective: Int, personal: Int) -> String {
        if objective >= 60, personal <= 35 {
            return "The material is objectively difficult, but your coverage keeps it manageable."
        }
        if objective <= 35, personal >= 60 {
            return "The material is not objectively very hard, but it is still hard for you, which suggests an unfamiliar domain."
        }
        if objective >= 60, personal >= 60 {
            return "The material is dense both objectively and personally. Breaking it into smaller chunks will help."
        }
        if objective <= 35, personal <= 35 {
            return "This material is easy both objectively and personally, so it is better for review and fluency work."
        }
        return "Objective difficulty and your personal difficulty are fairly aligned for this material."
    }

    private static func normalizeScore(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        guard maximum > minimum else { return 0 }
        let normalized = ((value - minimum) / (maximum - minimum)) * 100
        return Swift.max(0, Swift.min(100, normalized))
    }

    private static func roundMetric(_ value: Double, digits: Int = 0) -> Double {
        guard value.isFinite else { return 0 }
        let multiplier = pow(10.0, Double(digits))
        return (value * multiplier).rounded() / multiplier
    }

    private static func difficultyRank(for tags: [WordTag]) -> Int {
        switch tags.first ?? .top10000Plus {
        case .top3000:
            return 0
        case .top5000:
            return 1
        case .top10000:
            return 2
        case .top10000Plus:
            return 3
        case .offList:
            return 4
        }
    }
}
