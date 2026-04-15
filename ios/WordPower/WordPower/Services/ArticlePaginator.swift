import CoreGraphics
import Foundation
import UIKit

struct ArticlePaginationLayout: Equatable {
    let columnWidth: CGFloat
    let columnHeight: CGFloat
}

enum ArticlePaginationMetrics {
    static let paragraphTopPadding: CGFloat = 8
    static let chunkTopPadding: CGFloat = 4
    static let lineSpacing: CGFloat = 0
}

enum ArticlePaginator {
    static func paginate(
        paragraphs: [String],
        layoutMode: ReaderLayoutMode,
        containerSize: CGSize,
        fontScale: Double,
        lineHeightMultiple: CGFloat = 1.0
    ) -> [ArticlePage] {
        var units = WordPowerText.buildArticleReaderUnits(paragraphs: paragraphs)
        guard !units.isEmpty else { return [] }
        guard let layout = layout(for: containerSize, layoutMode: layoutMode) else { return [] }
        let font = scaledBodyFont(scale: fontScale)
        var measurementCache = TextMeasurementCache(
            width: layout.columnWidth,
            font: font,
            lineHeightMultiple: lineHeightMultiple
        )

        var pages: [ArticlePage] = []
        var index = 0
        var pageNumber = 1
        while index < units.count {
            let leftPack = packColumn(
                units: &units,
                startIndex: index,
                width: layout.columnWidth,
                heightBudget: layout.columnHeight,
                font: font,
                lineHeightMultiple: lineHeightMultiple,
                measurementCache: &measurementCache
            )
            var nextIndex = leftPack.nextIndex
            var rightUnits: [ArticleReaderUnit] = []
            if layoutMode == .spread, nextIndex < units.count {
                let rightPack = packColumn(
                    units: &units,
                    startIndex: nextIndex,
                    width: layout.columnWidth,
                    heightBudget: layout.columnHeight,
                    font: font,
                    lineHeightMultiple: lineHeightMultiple,
                    measurementCache: &measurementCache
                )
                rightUnits = rightPack.units
                nextIndex = rightPack.nextIndex
            }
            pages.append(
                ArticlePage(
                    index: pageNumber,
                    startIndex: leftPack.units.first?.anchorIndex ?? 0,
                    leftColumn: leftPack.units,
                    rightColumn: rightUnits
                )
            )
            index = nextIndex
            pageNumber += 1
        }

        return pages
    }

    static func layout(for containerSize: CGSize, layoutMode: ReaderLayoutMode) -> ArticlePaginationLayout? {
        let contentWidth = containerSize.width - ReaderLayoutMetrics.pageInset
        let contentHeight = containerSize.height - ReaderLayoutMetrics.pageInset
        guard contentWidth > 0, contentHeight > 0 else { return nil }

        let columnWidth: CGFloat
        switch layoutMode {
        case .single:
            columnWidth = contentWidth
        case .spread:
            columnWidth = (contentWidth - ReaderLayoutMetrics.spreadReservedWidth) / 2
        }
        guard columnWidth > 0 else { return nil }

        return ArticlePaginationLayout(columnWidth: columnWidth, columnHeight: contentHeight)
    }

    static func clampPage(_ page: Int, totalPages: Int) -> Int {
        max(1, min(page, max(1, totalPages)))
    }

    static func pageIndex(for blockIndex: Int, pages: [ArticlePage]) -> Int {
        guard !pages.isEmpty else { return 1 }
        if let exactPage = pages.first(where: { $0.startIndex == blockIndex }) {
            return exactPage.index
        }

        let sourceIndex = ReaderProgressAnchor.decodeSourceIndex(blockIndex)
        if let sourcePage = pages.first(where: { ReaderProgressAnchor.decodeSourceIndex($0.startIndex) == sourceIndex }) {
            return sourcePage.index
        }

        return pages.last(where: { ReaderProgressAnchor.decodeSourceIndex($0.startIndex) < sourceIndex })?.index ?? 1
    }

    private static func packColumn(
        units: inout [ArticleReaderUnit],
        startIndex: Int,
        width: CGFloat,
        heightBudget: CGFloat,
        font: UIFont,
        lineHeightMultiple: CGFloat,
        measurementCache: inout TextMeasurementCache
    ) -> (units: [ArticleReaderUnit], nextIndex: Int) {
        var packed: [ArticleReaderUnit] = []
        var currentHeight: CGFloat = 0
        var index = startIndex
        while index < units.count {
            let unit = units[index]
            let measuredHeight = unitHeight(
                unit,
                width: width,
                font: font,
                lineHeightMultiple: lineHeightMultiple,
                measurementCache: &measurementCache
            )
            let topPadding = packed.isEmpty
                ? 0
                : (unit.isParagraphStart ? ArticlePaginationMetrics.paragraphTopPadding : ArticlePaginationMetrics.chunkTopPadding)
            let remainingHeight = heightBudget - currentHeight - topPadding

            if measuredHeight > remainingHeight {
                let splitBudget = packed.isEmpty ? heightBudget : remainingHeight
                if splitBudget > 0,
                   let splitResult = splitUnitToFit(
                    unit,
                    width: width,
                    heightBudget: splitBudget,
                    font: font,
                    lineHeightMultiple: lineHeightMultiple,
                    measurementCache: &measurementCache
                   ) {
                    packed.append(splitResult.head)
                    currentHeight += topPadding + splitResult.headHeight
                    units[index] = splitResult.tail
                    continue
                }

                if !packed.isEmpty {
                    break
                }
            }

            let nextHeight = currentHeight + topPadding + measuredHeight
            packed.append(unit)
            currentHeight = nextHeight
            index += 1
        }
        if packed.isEmpty, startIndex < units.count {
            packed.append(units[startIndex])
            index = startIndex + 1
        }
        return (packed, index)
    }

    private static func splitUnitToFit(
        _ unit: ArticleReaderUnit,
        width: CGFloat,
        heightBudget: CGFloat,
        font: UIFont,
        lineHeightMultiple: CGFloat,
        measurementCache: inout TextMeasurementCache
    ) -> (head: ArticleReaderUnit, headHeight: CGFloat, tail: ArticleReaderUnit)? {
        guard heightBudget > 0 else { return nil }
        let words = unit.text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return nil }

        let end = bestFittingWordEnd(
            words: words,
            start: 0,
            heightBudget: heightBudget,
            measurementCache: &measurementCache
        )
        guard end > 0, end < words.count else { return nil }

        let head = makeSplitUnit(
            from: unit,
            text: words[..<end].joined(separator: " "),
            splitPartIndex: unit.splitPartIndex,
            isParagraphStart: unit.isParagraphStart
        )
        let tail = makeSplitUnit(
            from: unit,
            text: words[end...].joined(separator: " "),
            splitPartIndex: unit.splitPartIndex + 1,
            isParagraphStart: false
        )

        return (
            head,
            unitHeight(
                head,
                width: width,
                font: font,
                lineHeightMultiple: lineHeightMultiple,
                measurementCache: &measurementCache
            ),
            tail
        )
    }

    private static func makeSplitUnit(
        from unit: ArticleReaderUnit,
        text: String,
        splitPartIndex: Int,
        isParagraphStart: Bool
    ) -> ArticleReaderUnit {
        ArticleReaderUnit(
            key: "article-reader-unit-\(unit.sourceIndex)-split-\(splitPartIndex)",
            text: text,
            paragraphIndex: unit.paragraphIndex,
            isParagraphStart: isParagraphStart,
            sourceIndex: unit.sourceIndex,
            splitPartIndex: splitPartIndex
        )
    }

    private static func bestFittingWordEnd(
        words: [String],
        start: Int,
        heightBudget: CGFloat,
        measurementCache: inout TextMeasurementCache
    ) -> Int {
        guard start < words.count else { return start }

        var low = start
        var high = words.count
        var best = start

        while low < high {
            let mid = (low + high + 1) / 2
            let candidateText = words[start..<mid].joined(separator: " ")
            let candidateHeight = measurementCache.height(for: candidateText)
            if candidateHeight <= heightBudget {
                best = mid
                low = mid
            } else {
                high = mid - 1
            }
        }

        return best
    }

    private static func unitHeight(
        _ unit: ArticleReaderUnit,
        width: CGFloat,
        font: UIFont,
        lineHeightMultiple: CGFloat,
        measurementCache: inout TextMeasurementCache
    ) -> CGFloat {
        guard width == measurementCache.width,
              font.pointSize == measurementCache.font.pointSize,
              lineHeightMultiple == measurementCache.lineHeightMultiple else {
            let attributedText = HighlightTextBuilder.baseAttributedText(
                text: unit.text,
                font: font,
                lineSpacing: ArticlePaginationMetrics.lineSpacing,
                lineHeightMultiple: lineHeightMultiple
            )
            return HighlightTextBuilder.measureHeight(for: attributedText, width: width)
        }

        return measurementCache.height(for: unit.text)
    }

    private struct TextMeasurementCache {
        let width: CGFloat
        let font: UIFont
        let lineHeightMultiple: CGFloat

        private var heights: [String: CGFloat] = [:]

        init(width: CGFloat, font: UIFont, lineHeightMultiple: CGFloat) {
            self.width = width
            self.font = font
            self.lineHeightMultiple = lineHeightMultiple
        }

        mutating func height(for text: String) -> CGFloat {
            if let cached = heights[text] {
                return cached
            }

            let attributedText = HighlightTextBuilder.baseAttributedText(
                text: text,
                font: font,
                lineSpacing: ArticlePaginationMetrics.lineSpacing,
                lineHeightMultiple: lineHeightMultiple
            )
            let measuredHeight = HighlightTextBuilder.measureHeight(for: attributedText, width: width)
            heights[text] = measuredHeight
            return measuredHeight
        }
    }

    private static func scaledBodyFont(scale: Double) -> UIFont {
        let normalizedScale = max(1.0, scale)
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        return baseFont.withSize(baseFont.pointSize * normalizedScale)
    }
}
