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
                        stockGridSection("Largest", quotes: largeQuotes, columns: 2, style: .featured)
                        stockGridSection("Large Cap", quotes: mediumQuotes, columns: 3, style: .regular)
                        stockGridSection("Watchlist Size", quotes: smallQuotes, columns: 4, style: .dense)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(AppChrome.pageBackground)
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
                        FilterChip(title: category.title, isSelected: selectedCategory == category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func stockGridSection(_ title: String, quotes: [StockQuote], columns: Int, style: StockTickerCardStyle) -> some View {
        if !quotes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title, count: quotes.count)

                LazyVGrid(columns: gridColumns(count: columns), spacing: 10) {
                    ForEach(quotes) { quote in
                        NavigationLink {
                            StockViewerScreen(symbol: quote.symbol, companyName: quote.shortName)
                        } label: {
                            StockTickerCard(quote, style: style)
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

private struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isSelected ? Color.blue : AppChrome.pageBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? .clear : .secondary.opacity(0.24), lineWidth: 1)
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
