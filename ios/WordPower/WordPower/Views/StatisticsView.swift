import Charts
import SwiftUI

struct StatisticsView: View {
    @ObservedObject var appModel: AppModel
    @State private var dailyRange: StatisticsDayRange = .days15

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth
    private static let dayParser = statisticsDateFormatter(format: "yyyy-MM-dd")
    private static let monthParser = statisticsDateFormatter(format: "yyyy-MM")
    private static let shortDayFormatter = statisticsDateFormatter(format: "M/d")
    private static let longDayFormatter = statisticsDateFormatter(format: "yy/M/d")
    private static let detailDayFormatter = statisticsDateFormatter(format: "yyyy/M/d")
    private static let shortMonthFormatter = statisticsDateFormatter(format: "MMM")
    private static let longMonthFormatter = statisticsDateFormatter(format: "yy/MM")
    private static let detailMonthFormatter = statisticsDateFormatter(format: "yyyy/MM")

    var body: some View {
        if appModel.statsPoints.isEmpty {
            EmptyStateView(
                title: "No statistics yet",
                message: "Set words to 5 stars to build your learning history.",
                systemImage: "chart.xyaxis.line"
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    chartsSection
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .padding(AppLayout.pagePadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                headerText
                Spacer()
                headerControls
                    .frame(width: 280)
            }

            VStack(alignment: .leading, spacing: 12) {
                headerText
                headerControls
            }
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learning Statistics")
                .font(.title2.weight(.semibold))
            Text("Cumulative mastered words and new mastered words over time.")
                .foregroundStyle(.secondary)
        }
    }

    private var granularityPicker: some View {
        Picker("Granularity", selection: statsBinding) {
            Text("Daily").tag(StatsGranularity.day)
            Text("Monthly").tag(StatsGranularity.month)
        }
        .pickerStyle(.segmented)
    }

    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            granularityPicker
            if appModel.statsGranularity == .day {
                dailyRangePicker
            }
        }
    }

    private var dailyRangePicker: some View {
        Picker("Range", selection: $dailyRange) {
            ForEach(StatisticsDayRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var chartsSection: some View {
        StatisticsChartCard(
            title: "Mastered Words Over Time",
            points: displayedStatsPoints,
            granularity: appModel.statsGranularity,
            axisLabel: axisLabel(for:),
            detailDateLabel: detailDateLabel(for:)
        )
    }

    private var statsBinding: Binding<StatsGranularity> {
        Binding(
            get: { appModel.statsGranularity },
            set: { appModel.statsGranularity = $0 }
        )
    }

    private var displayedStatsPoints: [LearningStatPoint] {
        switch appModel.statsGranularity {
        case .day:
            return filledDailyPoints(for: dailyRange)
        case .month:
            return appModel.statsPoints
        }
    }

    private func filledDailyPoints(for range: StatisticsDayRange) -> [LearningStatPoint] {
        let calendar = Calendar.current
        let parsedPoints = appModel.statsPoints.compactMap { point -> ParsedStatPoint? in
            guard let date = Self.dayParser.date(from: point.date) else { return nil }
            return ParsedStatPoint(date: calendar.startOfDay(for: date), point: point)
        }
        .sorted { $0.date < $1.date }

        guard let firstDate = parsedPoints.first?.date else { return [] }

        let endDate = max(calendar.startOfDay(for: .now), parsedPoints.last?.date ?? firstDate)
        let startDate: Date
        if let dayCount = range.dayCount {
            startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate) ?? firstDate
        } else {
            startDate = firstDate
        }

        let pointsByDate = Dictionary(uniqueKeysWithValues: parsedPoints.map { ($0.point.date, $0.point) })
        var cumulative = parsedPoints.last(where: { $0.date < startDate })?.point.cumulative ?? 0
        var currentDate = startDate
        var filledPoints: [LearningStatPoint] = []

        while currentDate <= endDate {
            let key = Self.dayParser.string(from: currentDate)
            if let point = pointsByDate[key] {
                cumulative = point.cumulative
                filledPoints.append(point)
            } else {
                filledPoints.append(LearningStatPoint(date: key, newWords: 0, cumulative: cumulative))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return filledPoints
    }

    private func axisLabel(for date: String) -> String {
        guard let parsedDate = parsedDate(from: date) else { return date }

        switch appModel.statsGranularity {
        case .day:
            let formatter = spansMultipleYears ? Self.longDayFormatter : Self.shortDayFormatter
            return formatter.string(from: parsedDate)
        case .month:
            let formatter = spansMultipleYears ? Self.longMonthFormatter : Self.shortMonthFormatter
            return formatter.string(from: parsedDate)
        }
    }

    private func detailDateLabel(for date: String) -> String {
        guard let parsedDate = parsedDate(from: date) else { return date }

        switch appModel.statsGranularity {
        case .day:
            return Self.detailDayFormatter.string(from: parsedDate)
        case .month:
            return Self.detailMonthFormatter.string(from: parsedDate)
        }
    }

    private var spansMultipleYears: Bool {
        let years = displayedStatsPoints.compactMap {
            parsedDate(from: $0.date).map { Calendar.current.component(.year, from: $0) }
        }
        return Set(years).count > 1
    }

    private func parsedDate(from value: String) -> Date? {
        switch appModel.statsGranularity {
        case .day:
            return Self.dayParser.date(from: value)
        case .month:
            return Self.monthParser.date(from: value)
        }
    }

    private static func statisticsDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}

private enum StatisticsDayRange: CaseIterable, Hashable, Identifiable {
    case days7
    case days15
    case days30
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .days7: return "7"
        case .days15: return "15"
        case .days30: return "30"
        case .all: return "All"
        }
    }

    var dayCount: Int? {
        switch self {
        case .days7: return 7
        case .days15: return 15
        case .days30: return 30
        case .all: return nil
        }
    }
}

private struct ParsedStatPoint {
    let date: Date
    let point: LearningStatPoint
}

private struct IndexedStatPoint: Identifiable {
    let index: Int
    let point: LearningStatPoint

    var id: String { point.id }
    var xValue: Double { Double(index) }
}

private struct StatisticsAxis {
    let lowerBound: Double
    let upperBound: Double
    let step: Double

    var range: Double {
        upperBound - lowerBound
    }

    var values: [Double] {
        guard step > 0 else { return [lowerBound, upperBound] }

        var current = lowerBound
        var result: [Double] = []
        while current <= upperBound + (step * 0.5) {
            result.append(current)
            current += step
        }
        return result
    }
}

private struct StatisticsChartCard: View {
    let title: String
    let points: [LearningStatPoint]
    let granularity: StatsGranularity
    let axisLabel: (String) -> String
    let detailDateLabel: (String) -> String

    @State private var selectedDate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            if let selectedPoint {
                selectionSummary(for: selectedPoint)
            }
            legend
            Chart(indexedPoints) { item in
                chartMarks(for: item)
            }
            .chartXAxis {
                chartXAxis
            }
            .chartYAxis {
                chartYAxis
            }
            .chartYScale(domain: cumulativeAxis.lowerBound...cumulativeAxis.upperBound)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                }
                        )
                }
            }
            .frame(height: 320)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 24))
        .onAppear {
            refreshSelection()
        }
        .onChange(of: points) { _, _ in
            refreshSelection()
        }
    }

    private var indexedPoints: [IndexedStatPoint] {
        points.enumerated().map { index, point in
            IndexedStatPoint(index: index, point: point)
        }
    }

    private var selectedPoint: LearningStatPoint? {
        if let selectedDate,
           let point = points.first(where: { $0.date == selectedDate }) {
            return point
        }
        return points.last
    }

    private func selectionSummary(for point: LearningStatPoint) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detailDateLabel(point.date))
                    .font(.subheadline.weight(.semibold))
                Text("Tap or drag the chart to inspect another point.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            metricValue(title: "Total", value: point.cumulative, color: .accentColor)
            metricValue(title: "Added", value: point.newWords, color: .orange)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .accentColor, label: "Cumulative (left)")
            legendItem(color: .orange, label: "New Words (right)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    @ViewBuilder
    private func metricValue(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    @ChartContentBuilder
    private func chartMarks(for item: IndexedStatPoint) -> some ChartContent {
        BarMark(
            x: .value("Index", item.xValue),
            yStart: .value("New Words Baseline", cumulativeAxis.lowerBound),
            yEnd: .value("New Words", scaledNewWordsValue(for: item.point.newWords))
        )
        .foregroundStyle(.orange.opacity(0.3))

        LineMark(
            x: .value("Index", item.xValue),
            y: .value("Cumulative", Double(item.point.cumulative))
        )
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .foregroundStyle(Color.accentColor)

        if item.point.date == selectedPoint?.date {
            RuleMark(x: .value("Index", item.xValue))
                .foregroundStyle(.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            PointMark(
                x: .value("Index", item.xValue),
                y: .value("Cumulative", Double(item.point.cumulative))
            )
            .symbolSize(80)
            .foregroundStyle(Color.accentColor)

            PointMark(
                x: .value("Index", item.xValue),
                y: .value("New Words", scaledNewWordsValue(for: item.point.newWords))
            )
            .symbolSize(65)
            .foregroundStyle(.orange)
        }
    }

    @AxisContentBuilder
    private var chartXAxis: some AxisContent {
        AxisMarks(position: .bottom, values: axisValues) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let rawValue = value.as(Double.self) {
                    let index = Int(rawValue.rounded())
                    if points.indices.contains(index) {
                        Text(axisLabel(points[index].date))
                    }
                }
            }
        }
    }

    @AxisContentBuilder
    private var chartYAxis: some AxisContent {
        AxisMarks(position: .leading, values: cumulativeAxis.values) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let rawValue = value.as(Double.self) {
                    Text(Int(rawValue.rounded()), format: .number)
                }
            }
        }

        AxisMarks(position: .trailing, values: newWordsAxis.values.map { scaledValue($0, from: newWordsAxis, to: cumulativeAxis) }) { value in
            AxisTick()
            AxisValueLabel {
                if let scaledPosition = value.as(Double.self) {
                    let rawValue = scaledValue(scaledPosition, from: cumulativeAxis, to: newWordsAxis)
                    Text(Int(rawValue.rounded()), format: .number)
                }
            }
        }
    }

    private var axisValues: [Double] {
        guard !indexedPoints.isEmpty else { return [] }
        guard indexedPoints.count > axisTargetCount else {
            return indexedPoints.map(\.xValue)
        }

        let lastIndex = indexedPoints.count - 1
        let rawIndices = (0..<axisTargetCount).map { index in
            Int(round(Double(index) * Double(lastIndex) / Double(axisTargetCount - 1)))
        }

        var seen = Set<Int>()
        return rawIndices.compactMap { index in
            guard seen.insert(index).inserted else { return nil }
            return Double(index)
        }
    }

    private var axisTargetCount: Int {
        switch granularity {
        case .day:
            switch points.count {
            case 0...7:
                return points.count
            case 8...14:
                return 5
            case 15...31:
                return 6
            default:
                return 7
            }
        case .month:
            return min(6, points.count)
        }
    }

    private var cumulativeAxis: StatisticsAxis {
        makeAxis(values: points.map(\.cumulative), anchoredAtZero: false)
    }

    private var newWordsAxis: StatisticsAxis {
        makeAxis(values: points.map(\.newWords), anchoredAtZero: true)
    }

    private func scaledNewWordsValue(for value: Int) -> Double {
        scaledValue(Double(value), from: newWordsAxis, to: cumulativeAxis)
    }

    private func scaledValue(_ value: Double, from source: StatisticsAxis, to target: StatisticsAxis) -> Double {
        guard source.range > 0 else { return target.lowerBound }

        let progress = (value - source.lowerBound) / source.range
        let clampedProgress = min(max(progress, 0), 1)
        return target.lowerBound + (clampedProgress * target.range)
    }

    private func makeAxis(values: [Int], anchoredAtZero: Bool) -> StatisticsAxis {
        let minimum = Double(values.min() ?? 0)
        let maximum = Double(values.max() ?? 0)

        guard maximum > 0 else {
            return StatisticsAxis(lowerBound: 0, upperBound: 1, step: 1)
        }

        let rawLowerBound = anchoredAtZero ? 0 : minimum
        let span = max(maximum - rawLowerBound, 1)
        let padding = anchoredAtZero ? max(span * 0.15, 1) : max(span * 0.1, 1)
        let step = niceStep(for: max((span + padding) / 4, 1))
        let lowerBound = anchoredAtZero ? 0 : max(0, floor((minimum - padding) / step) * step)
        let upperBound = max(lowerBound + step, ceil((maximum + padding) / step) * step)

        return StatisticsAxis(lowerBound: lowerBound, upperBound: upperBound, step: step)
    }

    private func niceStep(for value: Double) -> Double {
        let magnitude = pow(10, floor(log10(max(value, 1))))
        let normalized = value / magnitude

        switch normalized {
        case ...1:
            return magnitude
        case ...2:
            return 2 * magnitude
        case ...5:
            return 5 * magnitude
        default:
            return 10 * magnitude
        }
    }

    private func refreshSelection() {
        if let selectedDate,
           points.contains(where: { $0.date == selectedDate }) {
            return
        }
        self.selectedDate = points.last?.date
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard !indexedPoints.isEmpty else { return }
        guard let plotFrame = proxy.plotFrame else { return }

        let frame = geometry[plotFrame]
        let xPosition = min(max(location.x - frame.minX, 0), frame.width)
        guard let rawIndex = proxy.value(atX: xPosition, as: Double.self) else { return }

        let clampedIndex = min(max(Int(rawIndex.rounded()), 0), indexedPoints.count - 1)
        selectedDate = indexedPoints[clampedIndex].point.date
    }
}
