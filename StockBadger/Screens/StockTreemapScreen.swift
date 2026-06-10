import SwiftUI

struct StockTreemapScreen: View {
    @State private var selectedCategory: MarketCategory = .entireMarket

    private let quotes = BaselineStockQuoteProvider.quotes

    private var filteredQuotes: [StockQuote] {
        selectedCategory.filter(quotes).sorted { $0.marketCap > $1.marketCap }
    }

    private var largeQuotes: [StockQuote] {
        filteredQuotes.filter { $0.marketCap >= 1_000_000_000_000 }
    }

    private var mediumQuotes: [StockQuote] {
        filteredQuotes.filter { $0.marketCap < 1_000_000_000_000 && $0.marketCap >= 350_000_000_000 }
    }

    private var smallQuotes: [StockQuote] {
        filteredQuotes.filter { $0.marketCap < 350_000_000_000 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryFilters

                    if filteredQuotes.isEmpty {
                        emptyState
                    } else {
                        stockGridSection(title: "Largest", quotes: largeQuotes, columns: 2, tileSize: .large)
                        stockGridSection(title: "Large Cap", quotes: mediumQuotes, columns: 3, tileSize: .medium)
                        stockGridSection(title: "Watchlist Size", quotes: smallQuotes, columns: 4, tileSize: .small)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Treemap")
        }
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MarketCategory.allCases) { category in
                    Button {
                        withAnimation(.snappy) {
                            selectedCategory = category
                        }
                    } label: {
                        MarketCategoryChip(
                            title: category.title,
                            isSelected: selectedCategory == category
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func stockGridSection(title: String, quotes: [StockQuote], columns: Int, tileSize: StockMapTileSize) -> some View {
        if !quotes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)

                    Text("\(quotes.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: gridColumns(count: columns), spacing: 10) {
                    ForEach(quotes) { quote in
                        NavigationLink {
                            StockViewerScreen(symbol: quote.symbol, companyName: quote.shortName)
                        } label: {
                            StockMapTickerTile(quote: quote, size: tileSize)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "chart.rectangular")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No tickers in this category yet")
                .font(.headline)

            Text("Add more baseline symbols to expand this view.")
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

    private func gridColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }
}

private struct MarketCategoryChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var backgroundColor: Color {
        isSelected ? .blue : Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        isSelected ? .clear : .secondary.opacity(0.24)
    }
}

private struct StockMapTickerTile: View {
    let quote: StockQuote
    let size: StockMapTileSize

    var body: some View {
        VStack(alignment: .leading, spacing: size.verticalSpacing) {
            HStack(alignment: .top, spacing: 6) {
                Text(quote.symbol)
                    .font(size.symbolFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 0)

                Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(size.arrowFont)
                    .foregroundStyle(statusColor)
            }

            if size != .small {
                Text(quote.shortName)
                    .font(size.nameFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(size == .large ? 2 : 1)
                    .frame(minHeight: size.nameMinHeight, alignment: .topLeading)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(quote.formattedPrice)
                    .font(size.priceFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(quote.formattedChange)
                    .font(size.changeFont)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, minHeight: size.minHeight, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusColor.opacity(0.72), lineWidth: size.borderWidth)
        }
    }

    private var statusColor: Color {
        quote.isUp ? .green : .red
    }
}

private enum StockMapTileSize {
    case large
    case medium
    case small

    var minHeight: CGFloat {
        switch self {
        case .large: 150
        case .medium: 126
        case .small: 98
        }
    }

    var padding: CGFloat {
        switch self {
        case .large: 14
        case .medium: 12
        case .small: 9
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .large: 10
        case .medium: 8
        case .small: 6
        }
    }

    var nameMinHeight: CGFloat {
        switch self {
        case .large: 32
        case .medium: 18
        case .small: 0
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .large: 1.4
        case .medium: 1.2
        case .small: 1
        }
    }

    var symbolFont: Font {
        switch self {
        case .large: .headline.bold()
        case .medium: .subheadline.bold()
        case .small: .caption.weight(.bold)
        }
    }

    var arrowFont: Font {
        switch self {
        case .large: .caption.bold()
        case .medium: .caption2.bold()
        case .small: .caption2.bold()
        }
    }

    var nameFont: Font {
        switch self {
        case .large: .caption
        case .medium: .caption2
        case .small: .caption2
        }
    }

    var priceFont: Font {
        switch self {
        case .large: .subheadline.weight(.semibold)
        case .medium: .caption.weight(.semibold)
        case .small: .caption2.weight(.semibold)
        }
    }

    var changeFont: Font {
        switch self {
        case .large: .caption2.weight(.semibold)
        case .medium: .caption2.weight(.semibold)
        case .small: .system(size: 9, weight: .semibold)
        }
    }
}

private enum MarketCategory: String, CaseIterable, Identifiable {
    case entireMarket
    case technology
    case banking
    case defense
    case healthcare
    case consumer
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entireMarket: "Entire Market"
        case .technology: "Technology"
        case .banking: "Banking"
        case .defense: "Defense"
        case .healthcare: "Healthcare"
        case .consumer: "Consumer"
        case .energy: "Energy"
        }
    }

    func filter(_ quotes: [StockQuote]) -> [StockQuote] {
        guard self != .entireMarket else {
            return quotes
        }

        return quotes.filter { symbols.contains($0.symbol) }
    }

    private var symbols: Set<String> {
        switch self {
        case .entireMarket:
            []
        case .technology:
            ["AAPL", "MSFT", "NVDA", "GOOGL", "META", "AVGO", "ORCL"]
        case .banking:
            ["BRK-B", "JPM", "BAC", "V", "MA"]
        case .defense:
            ["LMT", "RTX", "NOC", "GD"]
        case .healthcare:
            ["LLY", "UNH", "JNJ", "ABBV"]
        case .consumer:
            ["AMZN", "TSLA", "WMT", "COST", "PG", "HD", "NFLX"]
        case .energy:
            ["XOM"]
        }
    }
}

#Preview {
    StockTreemapScreen()
}
