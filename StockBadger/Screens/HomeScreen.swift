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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .task {
                await loadMarketOverview()
            }
            .refreshable {
                await loadMarketOverview()
            }
        }
    }

    private var marketOverviewCard: some View {
        NavigationLink {
            StockViewerScreen(symbol: marketSymbol, companyName: "S&P 500 ETF")
        } label: {
            VStack(alignment: .leading, spacing: 12) {
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

                if marketPoints.count > 1 {
                    HomeMiniLineChart(points: marketPoints, isPositive: isMarketChartPositive)
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

    private var topCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Largest Companies", subtitle: "Top names by market cap")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(topCompanies) { quote in
                    NavigationLink {
                        StockViewerScreen(symbol: quote.symbol, companyName: quote.shortName)
                    } label: {
                        HomeCompanyTile(quote: quote)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var marketNotesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Market Notes", subtitle: "Quick places to start")

            VStack(spacing: 10) {
                HomeNoteRow(icon: "chart.line.uptrend.xyaxis", title: "Browse the map", value: "Open the treemap to scan broad market movement.")
                HomeNoteRow(icon: "magnifyingglass", title: "Research a ticker", value: "Search by company name or symbol to open a stock viewer.")
                HomeNoteRow(icon: "list.bullet.rectangle", title: "Build lists", value: "Saved lists will become your custom research boards.")
            }
        }
    }

    private var isMarketChartPositive: Bool {
        guard let first = marketPoints.first?.price, let last = marketPoints.last?.price else {
            return true
        }

        return last >= first
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

private struct HomeCompanyTile: View {
    let quote: StockQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(quote.symbol)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.bold())
                    .foregroundStyle(quote.isUp ? .green : .red)
            }

            Text(quote.shortName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(minHeight: 32, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 4) {
                Text(quote.formattedPrice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(quote.formattedChange)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(quote.isUp ? .green : .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct HomeNoteRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct HomeMiniLineChart: View {
    let points: [StockPricePoint]
    let isPositive: Bool

    var body: some View {
        GeometryReader { proxy in
            let line = linePath(in: proxy.size)
            let area = areaPath(in: proxy.size)
            let color = isPositive ? Color.green : Color.red

            ZStack {
                area
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                line
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)

            guard let first = coordinates.first else { return }
            path.move(to: first)

            for point in coordinates.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)

            guard let first = coordinates.first, let last = coordinates.last else { return }

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
