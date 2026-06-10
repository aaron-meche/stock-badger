import Foundation

struct YahooFinanceSearchService: StockSearchServicing {
    private let baseURL = URL(string: "https://query2.finance.yahoo.com/v1/finance/search")!
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func searchStocks(matching query: String, limit: Int = 12) async throws -> [StockSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return []
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmedQuery),
            URLQueryItem(name: "quotesCount", value: String(limit)),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "listsCount", value: "0")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let searchResponse = try JSONDecoder().decode(YahooFinanceSearchResponse.self, from: data)

        return searchResponse.quotes
            .prefix(limit)
            .compactMap(StockSearchResult.init(yahooQuote:))
    }
}

private struct YahooFinanceSearchResponse: Decodable {
    let quotes: [YahooFinanceQuote]
}

private struct YahooFinanceQuote: Decodable {
    let symbol: String?
    let shortname: String?
    let longname: String?
    let exchDisp: String?
    let exchange: String?
    let typeDisp: String?
    let quoteType: String?
}

private extension StockSearchResult {
    init?(yahooQuote: YahooFinanceQuote) {
        guard let symbol = yahooQuote.symbol, !symbol.isEmpty else {
            return nil
        }

        let name = yahooQuote.longname ?? yahooQuote.shortname ?? symbol
        let exchange = yahooQuote.exchDisp ?? yahooQuote.exchange
        let type = yahooQuote.typeDisp ?? yahooQuote.quoteType

        self.init(symbol: symbol, name: name, exchange: exchange, type: type)
    }
}
