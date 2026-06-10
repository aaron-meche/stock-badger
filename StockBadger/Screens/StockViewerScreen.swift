import SwiftUI

struct StockViewerScreen: View {
    let symbol: String
    let companyName: String

    @State private var quote: StockQuote?
    @State private var selectedTimeframe: StockChartTimeframe = .oneDay
    @State private var selectedChartPoint: StockChartPoint?
    @State private var chartPointsByTimeframe: [StockChartTimeframe: [StockChartPoint]] = [:]
    @State private var isLoadingQuote = false
    @State private var isLoadingChart = false
    @State private var quoteMessage: String?
    @State private var chartMessage: String?

    private let marketDataService = AlphaVantageService()

    private var chartPoints: [StockChartPoint] {
        chartPointsByTimeframe[selectedTimeframe] ?? []
    }

    private var displayedPrice: Double? {
        selectedChartPoint?.price ?? quote?.price
    }

    private var titleSymbol: String {
        quote?.symbol ?? symbol.uppercased()
    }

    private var titleCompanyName: String {
        companyName
    }

    private var timeframeChange: StockTimeframeChange? {
        guard chartPoints.count > 1 else { return nil }
        return StockTimeframeChange(points: chartPoints)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                priceHeader
                chartSection
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
                    Text(titleSymbol)
                        .font(.headline.weight(.semibold))

                    Text(titleCompanyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .task(id: symbol) {
            await loadInitialMarketData()
        }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let displayedPrice {
                Text(displayedPrice.formatted(.currency(code: "USD")))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: displayedPrice))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(selectedChartPoint == nil ? "Latest price" : selectedTimeframe.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isLoadingQuote {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading price...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let quoteMessage {
                Text(quoteMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let timeframeChange {
                timeframeChangeLabel(timeframeChange)
            }

            chartContent

            timeframePicker
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if chartPoints.count > 1, let timeframeChange {
            StockLineChart(points: chartPoints, isPositive: timeframeChange.isPositive, selectedPoint: $selectedChartPoint)
                .frame(height: 260)
                .padding(.top, 4)
        } else if isLoadingChart {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading chart...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
            Text(chartMessage ?? "No chart data available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        }
    }

    private func timeframeChangeLabel(_ change: StockTimeframeChange) -> some View {
        HStack(spacing: 7) {
            Image(systemName: change.isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline.weight(.bold))

            Text(change.formattedText)
                .font(.headline.weight(.semibold))
        }
        .foregroundStyle(change.isPositive ? .green : .red)
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

    private func loadInitialMarketData() async {
        quote = nil
        selectedChartPoint = nil
        chartPointsByTimeframe = [:]
        quoteMessage = nil
        chartMessage = nil

        async let quoteLoad: Void = loadQuoteData()
        async let chartLoad: Void = loadChartData(for: selectedTimeframe)
        _ = await (quoteLoad, chartLoad)
    }

    private func loadQuoteData() async {
        isLoadingQuote = true
        quoteMessage = nil

        do {
            let quotes = try await marketDataService.fetchQuotes(for: [symbol])
            quote = quotes.first
            quoteMessage = quote == nil ? "No price data available." : nil
        } catch {
            quote = nil
            quoteMessage = "No price data available."
        }

        isLoadingQuote = false
    }

    private func loadChartData(for timeframe: StockChartTimeframe) async {
        if chartPointsByTimeframe[timeframe] != nil {
            return
        }

        isLoadingChart = true
        chartMessage = nil

        do {
            let pricePoints = try await marketDataService.fetchPriceHistory(for: symbol, timeframe: timeframe)
            let sampledPoints = sampledPricePoints(pricePoints, maximumCount: timeframe.pointCount)
            let chartPoints = sampledPoints.enumerated().map { index, point in
                StockChartPoint(index: index, price: point.price)
            }

            chartPointsByTimeframe[timeframe] = chartPoints.count > 1 ? chartPoints : nil
            chartMessage = chartPoints.count > 1 ? nil : "No chart data available."
        } catch {
            chartPointsByTimeframe[timeframe] = nil
            chartMessage = "No chart data available."
        }

        isLoadingChart = false
    }

    private func sampledPricePoints(_ points: [StockPricePoint], maximumCount: Int) -> [StockPricePoint] {
        guard points.count > maximumCount, maximumCount > 1 else {
            return points
        }

        let step = Double(points.count - 1) / Double(maximumCount - 1)

        return (0..<maximumCount).map { index in
            let sourceIndex = Int((Double(index) * step).rounded())
            return points[min(sourceIndex, points.count - 1)]
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

#Preview {
    NavigationStack {
        StockViewerScreen(symbol: "AAPL", companyName: "Apple Inc.")
    }
}
