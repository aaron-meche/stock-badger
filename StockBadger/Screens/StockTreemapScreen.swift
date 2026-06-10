import SwiftUI

struct StockTreemapScreen: View {
    @State private var quotes: [StockQuote] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let quoteService: StockQuoteFetching = YahooFinanceQuoteService()
    private let featuredSymbols = [
        "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "META", "BRK-B", "LLY",
        "AVGO", "TSLA", "JPM", "WMT", "V", "XOM", "MA", "UNH",
        "COST", "ORCL", "NFLX", "PG", "HD", "JNJ", "ABBV", "BAC"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerView

                    contentView
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Treemap")
            .task {
                await loadQuotes()
            }
            .refreshable {
                await loadQuotes()
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Market Map")
                .font(.title2.bold())

            HStack(spacing: 8) {
                marketSummaryPill(title: "Tracked", value: "\(quotes.count)")
                marketSummaryPill(title: "Advancers", value: "\(quotes.filter(\.isUp).count)")
                marketSummaryPill(title: "Decliners", value: "\(quotes.filter { !$0.isUp }.count)")
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading && quotes.isEmpty {
            loadingView
        } else if let errorMessage, quotes.isEmpty {
            errorView(errorMessage)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                StockTreemapView(quotes: sortedQuotes)
                    .frame(height: 760)

                moversView
            }
        }
    }

    private var sortedQuotes: [StockQuote] {
        quotes.sorted { $0.marketCap > $1.marketCap }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Loading market map...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unable to load treemap")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var moversView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Movers")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(sortedQuotes.prefix(8)) { quote in
                    StockMoverRow(quote: quote)
                }
            }
        }
    }

    private func marketSummaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadQuotes() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedQuotes = try await quoteService.fetchQuotes(for: featuredSymbols)

            await MainActor.run {
                quotes = fetchedQuotes
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Check your connection and pull to refresh."
                isLoading = false
            }
        }
    }
}

private struct StockTreemapView: View {
    let quotes: [StockQuote]

    var body: some View {
        GeometryReader { proxy in
            let rects = TreemapCalculator.rects(
                for: quotes,
                in: CGRect(origin: .zero, size: proxy.size),
                spacing: 4
            )

            ZStack(alignment: .topLeading) {
                ForEach(rects) { rect in
                    StockTreemapTile(quote: rect.quote)
                        .frame(width: rect.frame.width, height: rect.frame.height)
                        .position(x: rect.frame.midX, y: rect.frame.midY)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

private struct StockTreemapTile: View {
    let quote: StockQuote

    var body: some View {
        let isCompact = quote.marketCap < 600_000_000_000

        VStack(alignment: .leading, spacing: isCompact ? 3 : 7) {
            Text(quote.symbol)
                .font(isCompact ? .headline : .title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(priceText)
                .font(isCompact ? .caption : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(changeText)
                .font(isCompact ? .caption2 : .caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(isCompact ? 8 : 12)
        .background(tileColor)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                .font(isCompact ? .caption.bold() : .headline.bold())
                .foregroundStyle(.white.opacity(0.55))
                .padding(isCompact ? 7 : 10)
        }
    }

    private var tileColor: Color {
        let intensity = min(abs(quote.dailyChangePercent) / 5, 1)
        let opacity = 0.55 + (intensity * 0.35)
        return quote.isUp ? Color.green.opacity(opacity) : Color.red.opacity(opacity)
    }

    private var priceText: String {
        quote.price.formatted(.currency(code: "USD"))
    }

    private var changeText: String {
        let direction = quote.isUp ? "up" : "down"
        let change = abs(quote.dailyChange).formatted(.currency(code: "USD"))
        let percent = abs(quote.dailyChangePercent).formatted(.number.precision(.fractionLength(2)))
        return "(\(direction)) \(change) (\(percent)%)"
    }
}

private struct StockMoverRow: View {
    let quote: StockQuote

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(quote.isUp ? Color.green : Color.red)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(quote.symbol)
                    .font(.headline)

                Text(quote.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(quote.price.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))

                Text(changeText)
                    .font(.caption)
                    .foregroundStyle(quote.isUp ? .green : .red)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var changeText: String {
        let direction = quote.isUp ? "up" : "down"
        let change = abs(quote.dailyChange).formatted(.currency(code: "USD"))
        let percent = abs(quote.dailyChangePercent).formatted(.number.precision(.fractionLength(2)))
        return "(\(direction)) \(change) (\(percent)%)"
    }
}

private struct TreemapRect: Identifiable {
    let id: String
    let quote: StockQuote
    let frame: CGRect
}

private enum TreemapCalculator {
    static func rects(for quotes: [StockQuote], in frame: CGRect, spacing: CGFloat) -> [TreemapRect] {
        split(quotes, in: frame, spacing: spacing)
    }

    private static func split(_ quotes: [StockQuote], in frame: CGRect, spacing: CGFloat) -> [TreemapRect] {
        guard let firstQuote = quotes.first else {
            return []
        }

        if quotes.count == 1 {
            return [TreemapRect(id: firstQuote.id, quote: firstQuote, frame: frame.insetBy(dx: spacing / 2, dy: spacing / 2))]
        }

        let totalWeight = quotes.reduce(0) { $0 + max($1.marketCap, 1) }
        let splitIndex = balancedSplitIndex(for: quotes, totalWeight: totalWeight)
        let leadingQuotes = Array(quotes[..<splitIndex])
        let trailingQuotes = Array(quotes[splitIndex...])
        let leadingWeight = leadingQuotes.reduce(0) { $0 + max($1.marketCap, 1) }
        let ratio = leadingWeight / totalWeight

        if frame.width >= frame.height {
            let leadingWidth = frame.width * ratio
            let leadingFrame = CGRect(x: frame.minX, y: frame.minY, width: leadingWidth, height: frame.height)
            let trailingFrame = CGRect(x: frame.minX + leadingWidth, y: frame.minY, width: frame.width - leadingWidth, height: frame.height)
            return split(leadingQuotes, in: leadingFrame, spacing: spacing) + split(trailingQuotes, in: trailingFrame, spacing: spacing)
        } else {
            let leadingHeight = frame.height * ratio
            let leadingFrame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: leadingHeight)
            let trailingFrame = CGRect(x: frame.minX, y: frame.minY + leadingHeight, width: frame.width, height: frame.height - leadingHeight)
            return split(leadingQuotes, in: leadingFrame, spacing: spacing) + split(trailingQuotes, in: trailingFrame, spacing: spacing)
        }
    }

    private static func balancedSplitIndex(for quotes: [StockQuote], totalWeight: Double) -> Int {
        var runningWeight = 0.0
        var bestIndex = 1
        var bestDifference = Double.greatestFiniteMagnitude

        for index in 1..<quotes.count {
            runningWeight += max(quotes[index - 1].marketCap, 1)
            let difference = abs((totalWeight / 2) - runningWeight)

            if difference < bestDifference {
                bestDifference = difference
                bestIndex = index
            }
        }

        return bestIndex
    }
}

#Preview {
    StockTreemapScreen()
}
