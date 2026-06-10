import SwiftUI

struct StockViewerScreen: View {
    let symbol: String
    let companyName: String
    let quote: StockQuote?

    @State private var selectedTimeframe: StockChartTimeframe = .oneDay
    @State private var selectedChartPoint: StockChartPoint?
    @State private var liveQuote: StockQuote?
    @State private var liveChartPointsByTimeframe: [StockChartTimeframe: [StockChartPoint]] = [:]
    @State private var isLoadingMarketData = false
    @State private var marketDataMessage = "Loading market data..."

    private let marketDataService = AlphaVantageService()

    private var displayQuote: StockQuote {
        if let liveQuote {
            return liveQuote
        }

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
        liveChartPointsByTimeframe[selectedTimeframe] ?? StockChartDataFactory.points(for: displayQuote, timeframe: selectedTimeframe)
    }

    private var displayedPrice: Double {
        selectedChartPoint?.price ?? displayQuote.price
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
        .task(id: displayQuote.symbol) {
            await loadInitialMarketData()
        }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayedPrice.formatted(.currency(code: "USD")))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: displayedPrice))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Text(selectedChartPoint == nil ? "Latest displayed price" : selectedTimeframe.title)

                if isLoadingMarketData {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(marketDataMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            timeframeChangeLabel

            StockLineChart(points: chartPoints, isPositive: timeframeChange.isPositive, selectedPoint: $selectedChartPoint)
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
                ForEach(StockChartTimeframe.allCases) { timeframe in
                    Button {
                        selectedTimeframe = timeframe
                        selectedChartPoint = nil
                        Task {
                            await loadChartData(for: timeframe)
                        }
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

    private func loadInitialMarketData() async {
        isLoadingMarketData = true
        marketDataMessage = "Loading Alpha Vantage quote..."

        async let quoteLoad: Void = loadQuoteData()
        async let chartLoad: Void = loadChartData(for: selectedTimeframe)
        _ = await (quoteLoad, chartLoad)

        isLoadingMarketData = false
    }

    private func loadQuoteData() async {
        do {
            let quotes = try await marketDataService.fetchQuotes(for: [symbol])

            await MainActor.run {
                if let quote = quotes.first {
                    liveQuote = quote
                    marketDataMessage = "Alpha Vantage quote loaded."
                }
            }
        } catch {
            await MainActor.run {
                marketDataMessage = "Using cached preview quote. Alpha Vantage did not return a quote."
            }
        }
    }

    private func loadChartData(for timeframe: StockChartTimeframe) async {
        if liveChartPointsByTimeframe[timeframe] != nil {
            return
        }

        await MainActor.run {
            isLoadingMarketData = true
            marketDataMessage = "Loading \(timeframe.title) Alpha Vantage chart..."
        }

        do {
            let pricePoints = try await marketDataService.fetchPriceHistory(for: symbol, timeframe: timeframe)
            let chartPoints = pricePoints.enumerated().map { index, point in
                StockChartPoint(index: index, price: point.price)
            }

            await MainActor.run {
                if chartPoints.count > 1 {
                    liveChartPointsByTimeframe[timeframe] = sampledChartPoints(chartPoints, maximumCount: timeframe.pointCount)
                    marketDataMessage = "Alpha Vantage \(timeframe.title) chart loaded."
                } else {
                    marketDataMessage = "Using generated \(timeframe.title) preview chart."
                }

                isLoadingMarketData = false
            }
        } catch {
            await MainActor.run {
                marketDataMessage = "Using generated \(timeframe.title) preview chart. Alpha Vantage is unavailable or rate-limited."
                isLoadingMarketData = false
            }
        }
    }

    private func sampledChartPoints(_ points: [StockChartPoint], maximumCount: Int) -> [StockChartPoint] {
        guard points.count > maximumCount, maximumCount > 1 else {
            return points.enumerated().map { index, point in
                StockChartPoint(index: index, price: point.price)
            }
        }

        let step = Double(points.count - 1) / Double(maximumCount - 1)

        return (0..<maximumCount).map { index in
            let sourceIndex = Int((Double(index) * step).rounded())
            let point = points[min(sourceIndex, points.count - 1)]
            return StockChartPoint(index: index, price: point.price)
        }
    }
}

private struct StockLineChart: View {
    let points: [StockChartPoint]
    let isPositive: Bool
    @Binding var selectedPoint: StockChartPoint?

    var body: some View {
        GeometryReader { proxy in
            let path = linePath(in: proxy.size)
            let fillPath = areaPath(in: proxy.size)
            let coordinates = coordinates(in: proxy.size)
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

                if let selectedPoint,
                   let selectedIndex = points.firstIndex(where: { $0.index == selectedPoint.index }),
                   coordinates.indices.contains(selectedIndex) {
                    let selectedCoordinate = coordinates[selectedIndex]

                    Path { path in
                        path.move(to: CGPoint(x: selectedCoordinate.x, y: 0))
                        path.addLine(to: CGPoint(x: selectedCoordinate.x, y: proxy.size.height))
                    }
                    .stroke(.primary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 4)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        .position(selectedCoordinate)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectedPoint = nearestPoint(to: value.location.x, in: proxy.size)
                    }
                    .onEnded { _ in
                        selectedPoint = nil
                    }
            )
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

    private func nearestPoint(to xPosition: CGFloat, in size: CGSize) -> StockChartPoint? {
        guard points.count > 1 else {
            return points.first
        }

        let clampedX = min(max(xPosition, 0), size.width)
        let horizontalStep = size.width / CGFloat(points.count - 1)
        let index = Int((clampedX / horizontalStep).rounded())
        let clampedIndex = min(max(index, 0), points.count - 1)
        return points[clampedIndex]
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

private struct StockChartPoint: Identifiable {
    let index: Int
    let price: Double

    var id: Int { index }
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
    static func points(for quote: StockQuote, timeframe: StockChartTimeframe) -> [StockChartPoint] {
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
            return StockChartPoint(index: index, price: max(trend + wave + smallerWave, 0.01))
        }
    }

    private static func fallbackChange(for symbol: String, price: Double) -> Double {
        let symbolScore = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let direction = symbolScore.isMultiple(of: 2) ? 1.0 : -1.0
        let magnitude = 0.006 + (Double(symbolScore % 9) / 1000)
        return price * magnitude * direction
    }
}

#Preview {
    NavigationStack {
        StockViewerScreen(symbol: "AAPL", companyName: "Apple Inc.", quote: BaselineStockQuoteProvider.quote(for: "AAPL"))
    }
}
