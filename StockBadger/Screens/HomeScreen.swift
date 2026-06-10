import SwiftUI

struct HomeScreen: View {
    @State private var marketQuote: StockQuote?
    @State private var marketPoints: [StockPricePoint] = []
    @State private var isLoadingMarketOverview = false
    @State private var marketOverviewMessage: String?

    private let marketDataService = AlphaVantageService()
    private let marketSymbol = "SPY"

    private var topCompanies: [StockQuote] {
        Array(BaselineStockQuoteProvider.quotes.sorted { $0.marketCap > $1.marketCap }.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    marketOverviewCard
                    topCompaniesSection
                    marketNotesSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(AppChrome.pageBackground)
            .navigationTitle("Home")
            .task { await loadMarketOverview() }
            .refreshable { await loadMarketOverview() }
        }
    }

    private var marketOverviewCard: some View {
        NavigationLink {
            StockViewerScreen(symbol: marketSymbol, companyName: "S&P 500 ETF")
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                marketOverviewHeader
                marketOverviewPrice

                if marketPoints.count > 1 {
                    MiniLineChart(points: marketPoints, isPositive: isMarketChartPositive)
                        .frame(height: 92)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var marketOverviewHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("S&P 500")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("Market overview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoadingMarketOverview {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var marketOverviewPrice: some View {
        if let marketQuote {
            HStack(alignment: .bottom, spacing: 12) {
                Text(marketQuote.formattedPrice)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(marketQuote.formattedChange)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(marketQuote.isUp ? .green : .red)
                    .padding(.bottom, 5)
            }
        } else if let marketOverviewMessage {
            Text(marketOverviewMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var topCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Largest Companies", subtitle: "Top names by market cap")

            LazyVGrid(columns: twoColumnGrid, spacing: 12) {
                ForEach(topCompanies) { quote in
                    NavigationLink {
                        StockViewerScreen(symbol: quote.symbol, companyName: quote.shortName)
                    } label: {
                        StockTickerCard(quote, style: .featured)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var marketNotesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Market Notes", subtitle: "Quick places to start")

            VStack(spacing: 10) {
                InfoRow(icon: "chart.line.uptrend.xyaxis", title: "Browse the map", value: "Open the treemap to scan broad market movement.")
                InfoRow(icon: "sparkles", title: "Ask the analyst", value: "Open any stock and request an AI fair-value breakdown.")
                InfoRow(icon: "magnifyingglass", title: "Research a ticker", value: "Search by company name or symbol to open a stock viewer.")
            }
        }
    }

    private var twoColumnGrid: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var isMarketChartPositive: Bool {
        guard let first = marketPoints.first?.price, let last = marketPoints.last?.price else {
            return true
        }

        return last >= first
    }

    private func loadMarketOverview() async {
        isLoadingMarketOverview = true
        marketOverviewMessage = nil

        async let quoteLoad = loadMarketQuote()
        async let chartLoad = loadMarketChart()
        _ = await (quoteLoad, chartLoad)

        isLoadingMarketOverview = false
    }

    private func loadMarketQuote() async {
        do {
            let quotes = try await marketDataService.fetchQuotes(for: [marketSymbol])
            marketQuote = quotes.first
            marketOverviewMessage = marketQuote == nil ? "Market overview unavailable." : nil
        } catch {
            marketQuote = nil
            marketOverviewMessage = "Market overview unavailable."
        }
    }

    private func loadMarketChart() async {
        do {
            let points = try await marketDataService.fetchPriceHistory(for: marketSymbol, timeframe: .oneWeek)
            marketPoints = sampledPricePoints(points, maximumCount: 36)
        } catch {
            marketPoints = []
        }
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

private struct MiniLineChart: View {
    let points: [StockPricePoint]
    let isPositive: Bool

    var body: some View {
        GeometryReader { proxy in
            let line = linePath(in: proxy.size)
            let area = areaPath(in: proxy.size)
            let color = isPositive ? Color.green : Color.red

            ZStack {
                area.fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                line.stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)
            guard let first = coordinates.first else { return }

            path.move(to: first)
            coordinates.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)
            guard let first = coordinates.first, let last = coordinates.last else { return }

            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            coordinates.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func coordinates(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }

        let prices = points.map(\.price)
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 1
        let range = max(maxPrice - minPrice, 0.01)
        let step = size.width / CGFloat(points.count - 1)

        return points.enumerated().map { index, point in
            let x = CGFloat(index) * step
            let normalizedY = (point.price - minPrice) / range
            let y = size.height - (CGFloat(normalizedY) * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    HomeScreen()
}
