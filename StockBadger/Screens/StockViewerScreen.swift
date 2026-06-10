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
                analystPromptCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(Color.gray.opacity(0.08))
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

            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    AnalystScreen(initialPrompt: analystPrompt)
                } label: {
                    Image(systemName: "sparkles")
                }
                .accessibilityLabel("Ask Analyst")
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

    private var analystPromptCard: some View {
        NavigationLink {
            AnalystScreen(initialPrompt: analystPrompt)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask the Analyst")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Get a buy, hold, or sell view with fair value context.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var analystPrompt: String {
        let priceText = quote?.formattedPrice ?? "Unavailable"
        let changeText = quote?.formattedChange ?? "Unavailable"

        if isIndexLikeInstrument {
            return """
            Provide a professional market analyst breakdown for \(titleSymbol) (\(titleCompanyName)). Current app price: \(priceText). Daily change: \(changeText). Explain market context, trend, major risks, breadth, and what investors should watch next. Do not include a stock-specific Final Summary block.
            """
        }

        return """
        Provide a professional equity analyst breakdown for \(titleSymbol) (\(titleCompanyName)). Current app price: \(priceText). Daily change: \(changeText). Assess business quality, valuation, major risks, likely catalysts, a reasonable fair price estimate, and whether the stock looks like a BUY, HOLD, or SELL. End with the required Final Summary block.
        """
    }

    private var isIndexLikeInstrument: Bool {
        let normalizedSymbol = titleSymbol.uppercased()
        let normalizedName = titleCompanyName.lowercased()
        let indexSymbols: Set<String> = ["SPY", "QQQ", "VOO", "IVV", "DIA", "IWM"]

        return indexSymbols.contains(normalizedSymbol)
            || normalizedName.contains("s&p")
            || normalizedName.contains("index")
            || normalizedName.contains("etf")
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
                                selectedTimeframe == timeframe ? Color.accentColor : Color.gray.opacity(0.08),
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


#Preview {
    NavigationStack {
        StockViewerScreen(symbol: "AAPL", companyName: "Apple Inc.")
    }
}
