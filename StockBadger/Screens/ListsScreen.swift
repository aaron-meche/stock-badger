import SwiftUI

struct ListsScreen: View {
    private let lists = StockList.sampleLists

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    LazyVStack(spacing: 12) {
                        ForEach(lists) { list in
                            StockListCard(list: list)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(AppChrome.pageBackground)
            .navigationTitle("Lists")
        }
    }

    private var headerCard: some View {
        InfoRow(
            icon: "list.bullet.rectangle.portrait",
            title: "Research Boards",
            value: "Starter lists for fast market scanning. Custom saved lists can build on this later."
        )
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StockListCard: View {
    let list: StockList

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            listHeader

            LazyVGrid(columns: threeColumnGrid, spacing: 8) {
                ForEach(list.quotes) { quote in
                    NavigationLink {
                        StockViewerScreen(symbol: quote.symbol, companyName: quote.shortName)
                    } label: {
                        StockTickerCard(quote, style: .compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var listHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: list.icon)
                .font(.headline)
                .foregroundStyle(list.color)
                .frame(width: 36, height: 36)
                .background(list.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            SectionHeader(list.title, subtitle: list.subtitle)

            Spacer(minLength: 0)
        }
    }

    private var threeColumnGrid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }
}

private struct StockList: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let quotes: [StockQuote]

    static let sampleLists: [StockList] = [
        StockList(
            id: "mega-cap-ai",
            title: "AI & Mega Cap",
            subtitle: "Dominant platform companies driving market returns.",
            icon: "sparkles",
            color: .blue,
            quotes: quotes(for: ["NVDA", "MSFT", "AAPL", "GOOGL", "META", "AVGO"])
        ),
        StockList(
            id: "compounders",
            title: "Quality Compounders",
            subtitle: "Large businesses with durable brands and cash generation.",
            icon: "chart.line.uptrend.xyaxis",
            color: .green,
            quotes: quotes(for: ["COST", "V", "MA", "WMT", "PG", "HD"])
        ),
        StockList(
            id: "defensive-watch",
            title: "Defensive Watch",
            subtitle: "Healthcare, defense, and lower-cyclicality names.",
            icon: "shield.lefthalf.filled",
            color: .orange,
            quotes: quotes(for: ["LLY", "UNH", "JNJ", "ABBV", "RTX", "LMT"])
        )
    ]

    private static func quotes(for symbols: [String]) -> [StockQuote] {
        symbols.compactMap { symbol in
            BaselineStockQuoteProvider.quotes.first { $0.symbol == symbol }
        }
    }
}

#Preview {
    ListsScreen()
}
