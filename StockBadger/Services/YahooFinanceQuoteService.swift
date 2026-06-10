import Foundation

struct YahooFinanceQuoteService: StockQuoteFetching {
    private let baseURL = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote")!
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        let joinedSymbols = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        guard !joinedSymbols.isEmpty else {
            return []
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "symbols", value: joinedSymbols),
            URLQueryItem(name: "fields", value: "symbol,shortName,regularMarketPrice,regularMarketChange,regularMarketChangePercent,marketCap")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let quoteResponse = try JSONDecoder().decode(YahooFinanceQuoteResponse.self, from: data)

        return quoteResponse.quoteResponse.result.compactMap(StockQuote.init(yahooQuote:))
    }
}

private struct YahooFinanceQuoteResponse: Decodable {
    let quoteResponse: QuoteResponse

    struct QuoteResponse: Decodable {
        let result: [YahooQuote]
    }
}

private struct YahooQuote: Decodable {
    let symbol: String?
    let shortName: String?
    let regularMarketPrice: Double?
    let regularMarketChange: Double?
    let regularMarketChangePercent: Double?
    let marketCap: Double?
}

private extension StockQuote {
    init?(yahooQuote: YahooQuote) {
        guard let symbol = yahooQuote.symbol,
              let price = yahooQuote.regularMarketPrice else {
            return nil
        }

        self.init(
            symbol: symbol,
            shortName: yahooQuote.shortName ?? symbol,
            price: price,
            dailyChange: yahooQuote.regularMarketChange ?? 0,
            dailyChangePercent: yahooQuote.regularMarketChangePercent ?? 0,
            marketCap: yahooQuote.marketCap ?? 1
        )
    }
}
