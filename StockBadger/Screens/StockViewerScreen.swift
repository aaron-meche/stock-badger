import SwiftUI

struct StockViewerScreen: View {
    let symbol: String
    let companyName: String
    let quote: StockQuote?

    @State private var selectedTimeframe: StockTimeframe = .oneDay

    private var displayQuote: StockQuote {
        if let quote {
            return quote
        }

        if let baselineQuote = BaselineStockQuoteProvider.quote(for: symbol) {
            return baselineQuote
        }

        return StockQuote(
            symbol: symbol,
            shortName: companyName,
            price: 100,
            dailyChange: 0,
            dailyChangePercent: 0,
            marketCap: 1
        )
    }

    private var chartPoints: [StockChartPoint] {
        StockChartDataFactory.points(for: displayQuote, timeframe: selectedTimeframe)
    }

    private var timeframeChange: StockTimeframeChange {
        StockTimeframeChange(points: chartPoints)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                priceHeader

                chartSection

                placeholderResearchSections
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(displayQuote.symbol)
                        .font(.headline.weight(.semibold))

                    Text(displayQuote.shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayQuote.price.formatted(.currency(code: "USD")))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Market data preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            timeframeChangeLabel

            StockLineChart(points: chartPoints, isPositive: timeframeChange.isPositive)
                .frame(height: 260)
                .padding(.top, 4)

            timeframePicker
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var timeframeChangeLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: timeframeChange.isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline.weight(.bold))

            Text(timeframeChange.formattedText)
                .font(.headline.weight(.semibold))
        }
        .foregroundStyle(timeframeChange.isPositive ? .green : .red)
    }

    private var timeframePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StockTimeframe.allCases) { timeframe in
                    Button {
                        selectedTimeframe = timeframe
                    } label: {
                        Text(timeframe.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedTimeframe == timeframe ? .white : .primary)
                            .frame(minWidth: 44)
                            .padding(.vertical, 9)
                            .background(
                                selectedTimeframe == timeframe ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var placeholderResearchSections: some View {
        VStack(spacing: 12) {
            StockViewerInfoRow(title: "Analysis", value: "Ratings and price targets will appear here")
            StockViewerInfoRow(title: "News", value: "Company-specific headlines will appear here")
            StockViewerInfoRow(title: "Lists", value: "Saved list actions will appear here")
        }
    }
}

private struct StockLineChart: View {
    let points: [StockChartPoint]
    let isPositive: Bool

    var body: some View {
        GeometryReader { proxy in
            let path = linePath(in: proxy.size)
            let fillPath = areaPath(in: proxy.size)
            let color = isPositive ? Color.green : Color.red

            ZStack {
                GridBackground()
                    .stroke(.quaternary, lineWidth: 1)

                fillPath
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.22), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                path
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityLabel("Stock price chart")
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)

            guard let first = coordinates.first else {
                return
            }

            path.move(to: first)

            for point in coordinates.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)

            guard let first = coordinates.first, let last = coordinates.last else {
                return
            }

            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)

            for point in coordinates.dropFirst() {
                path.addLine(to: point)
            }

            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func coordinates(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else {
            return []
        }

        let values = points.map(\.price)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let valueRange = max(maxValue - minValue, 0.01)
        let horizontalStep = size.width / CGFloat(points.count - 1)

        return points.enumerated().map { index, point in
            let x = CGFloat(index) * horizontalStep
            let normalizedY = (point.price - minValue) / valueRange
            let y = size.height - (CGFloat(normalizedY) * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct GridBackground: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0...3 {
                let y = rect.height * CGFloat(index) / 3
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}

private struct StockViewerInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private enum StockTimeframe: String, CaseIterable, Identifiable {
    case oneDay
    case oneWeek
    case oneMonth
    case threeMonths
    case yearToDate
    case oneYear
    case fiveYears
    case max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneDay: "1D"
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .yearToDate: "YTD"
        case .oneYear: "1Y"
        case .fiveYears: "5Y"
        case .max: "MAX"
        }
    }

    var pointCount: Int {
        switch self {
        case .oneDay: 32
        case .oneWeek: 35
        case .oneMonth: 42
        case .threeMonths: 54
        case .yearToDate: 58
        case .oneYear: 64
        case .fiveYears: 72
        case .max: 82
        }
    }

    var targetMoveMultiplier: Double {
        switch self {
        case .oneDay: 1
        case .oneWeek: 2.4
        case .oneMonth: 4.1
        case .threeMonths: 7.2
        case .yearToDate: 9.4
        case .oneYear: 12.6
        case .fiveYears: 34
        case .max: 58
        }
    }
}

private struct StockChartPoint: Identifiable {
    let id = UUID()
    let price: Double
}

private struct StockTimeframeChange {
    let priceChange: Double
    let percentChange: Double

    init(points: [StockChartPoint]) {
        guard let first = points.first?.price, let last = points.last?.price, first != 0 else {
            priceChange = 0
            percentChange = 0
            return
        }

        priceChange = last - first
        percentChange = (priceChange / first) * 100
    }

    var isPositive: Bool {
        priceChange >= 0
    }

    var formattedText: String {
        let price = abs(priceChange).formatted(.currency(code: "USD"))
        let percent = abs(percentChange).formatted(.number.precision(.fractionLength(2)))
        return "\(price) (\(percent)%)"
    }
}

private enum StockChartDataFactory {
    static func points(for quote: StockQuote, timeframe: StockTimeframe) -> [StockChartPoint] {
        let count = timeframe.pointCount
        let endPrice = max(quote.price, 1)
        let baseChange = quote.dailyChange == 0 ? fallbackChange(for: quote.symbol, price: endPrice) : quote.dailyChange
        let targetChange = baseChange * timeframe.targetMoveMultiplier
        let startPrice = max(endPrice - targetChange, 1)
        let seed = Double(abs(quote.symbol.hashValue % 100)) / 100

        return (0..<count).map { index in
            let progress = Double(index) / Double(max(count - 1, 1))
            let trend = startPrice + ((endPrice - startPrice) * progress)
            let wave = sin((progress * .pi * 4) + seed) * endPrice * 0.012
            let smallerWave = cos((progress * .pi * 9) + seed) * endPrice * 0.004
            return StockChartPoint(price: max(trend + wave + smallerWave, 0.01))
        }
    }

    private static func fallbackChange(for symbol: String, price: Double) -> Double {
        let symbolScore = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let direction = symbolScore.isMultiple(of: 2) ? 1.0 : -1.0
        let magnitude = 0.006 + (Double(symbolScore % 9) / 1000)
        return price * magnitude * direction
    }
}

private extension BaselineStockQuoteProvider {
    static func quote(for symbol: String) -> StockQuote? {
        quotes.first { $0.symbol == symbol.uppercased() }
    }
}

#Preview {
    NavigationStack {
        StockViewerScreen(symbol: "AAPL", companyName: "Apple Inc.", quote: BaselineStockQuoteProvider.quote(for: "AAPL"))
    }
}
