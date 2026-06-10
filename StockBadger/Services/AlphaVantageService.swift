import Foundation

enum AlphaVantageError: LocalizedError {
    case missingAPIKey
    case invalidResponse(String)
    case rateLimited(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Missing Alpha Vantage API key."
        case .invalidResponse(let message):
            message
        case .rateLimited(let message):
            message
        }
    }
}

struct AlphaVantageService: StockQuoteFetching, StockChartFetching {
    private let baseURL = URL(string: "https://www.alphavantage.co/query")!
    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String = AlphaVantageService.apiKeyFromBundle(), urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote] {
        guard !apiKey.isEmpty, !apiKey.contains("$(") else {
            throw AlphaVantageError.missingAPIKey
        }

        var quotes: [StockQuote] = []

        for symbol in symbols.map(normalizedSymbol).filter({ !$0.isEmpty }) {
            let quote = try await fetchQuote(for: symbol)
            quotes.append(quote)
        }

        return quotes
    }

    func fetchPriceHistory(for symbol: String, timeframe: StockChartTimeframe) async throws -> [StockPricePoint] {
        guard !apiKey.isEmpty, !apiKey.contains("$(") else {
            throw AlphaVantageError.missingAPIKey
        }

        let normalizedSymbol = normalizedSymbol(symbol)

        guard !normalizedSymbol.isEmpty else {
            return []
        }

        if timeframe == .oneDay {
            return try await fetchIntradayHistory(for: normalizedSymbol)
        }

        return try await fetchDailyHistory(for: normalizedSymbol, timeframe: timeframe)
    }

    private func fetchQuote(for symbol: String) async throws -> StockQuote {
        let response: GlobalQuoteResponse = try await request(queryItems: [
            URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey)
        ])

        guard let globalQuote = response.globalQuote,
              let price = Double(globalQuote.price),
              let change = Double(globalQuote.change),
              let changePercent = Double(globalQuote.changePercent.replacingOccurrences(of: "%", with: "")) else {
            throw AlphaVantageError.invalidResponse("Alpha Vantage returned no quote for \(symbol).")
        }

        let baselineQuote = BaselineStockQuoteProvider.quote(for: symbol)

        return StockQuote(
            symbol: symbol,
            shortName: baselineQuote?.shortName ?? symbol,
            price: price,
            dailyChange: change,
            dailyChangePercent: changePercent,
            marketCap: baselineQuote?.marketCap ?? 1
        )
    }

    private func fetchIntradayHistory(for symbol: String) async throws -> [StockPricePoint] {
        let response: IntradayResponse = try await request(queryItems: [
            URLQueryItem(name: "function", value: "TIME_SERIES_INTRADAY"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "interval", value: "5min"),
            URLQueryItem(name: "outputsize", value: "compact"),
            URLQueryItem(name: "apikey", value: apiKey)
        ])

        return response.timeSeries
            .map { StockPricePoint(date: $0.key, price: $0.value.close) }
            .sorted { $0.date < $1.date }
    }

    private func fetchDailyHistory(for symbol: String, timeframe: StockChartTimeframe) async throws -> [StockPricePoint] {
        let outputSize = timeframe == .max || timeframe == .fiveYears ? "full" : "compact"
        let response: DailyResponse = try await request(queryItems: [
            URLQueryItem(name: "function", value: "TIME_SERIES_DAILY"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "outputsize", value: outputSize),
            URLQueryItem(name: "apikey", value: apiKey)
        ])

        let earliestDate = timeframe.earliestDate

        return response.timeSeries
            .map { StockPricePoint(date: $0.key, price: $0.value.close) }
            .filter { point in
                guard let earliestDate else { return true }
                return point.date >= earliestDate
            }
            .sorted { $0.date < $1.date }
    }

    private func request<Response: Decodable>(queryItems: [URLQueryItem]) async throws -> Response {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let apiMessage = try JSONDecoder().decode(AlphaVantageAPIMessage.self, from: data)

        if let note = apiMessage.note {
            throw AlphaVantageError.rateLimited(note)
        }

        if let information = apiMessage.information {
            throw AlphaVantageError.rateLimited(information)
        }

        if let errorMessage = apiMessage.errorMessage {
            throw AlphaVantageError.invalidResponse(errorMessage)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func normalizedSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func apiKeyFromBundle() -> String {
        Bundle.main.object(forInfoDictionaryKey: "ApiKey") as? String ?? ""
    }
}

private struct AlphaVantageAPIMessage: Decodable {
    let note: String?
    let information: String?
    let errorMessage: String?

    private enum CodingKeys: String, CodingKey {
        case note = "Note"
        case information = "Information"
        case errorMessage = "Error Message"
    }
}

private struct GlobalQuoteResponse: Decodable {
    let globalQuote: GlobalQuote?

    private enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

private struct GlobalQuote: Decodable {
    let price: String
    let change: String
    let changePercent: String

    private enum CodingKeys: String, CodingKey {
        case price = "05. price"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

private struct IntradayResponse: Decodable {
    let timeSeries: [Date: AlphaVantagePriceBar]

    private enum CodingKeys: String, CodingKey {
        case timeSeries = "Time Series (5min)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSeries = try container.decode([String: AlphaVantagePriceBar].self, forKey: .timeSeries)
        let formatter = DateFormatter.alphaVantageDateTime
        timeSeries = Dictionary(uniqueKeysWithValues: rawSeries.compactMap { key, value in
            guard let date = formatter.date(from: key) else { return nil }
            return (date, value)
        })
    }
}

private struct DailyResponse: Decodable {
    let timeSeries: [Date: AlphaVantagePriceBar]

    private enum CodingKeys: String, CodingKey {
        case timeSeries = "Time Series (Daily)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSeries = try container.decode([String: AlphaVantagePriceBar].self, forKey: .timeSeries)
        let formatter = DateFormatter.alphaVantageDate
        timeSeries = Dictionary(uniqueKeysWithValues: rawSeries.compactMap { key, value in
            guard let date = formatter.date(from: key) else { return nil }
            return (date, value)
        })
    }
}

private struct AlphaVantagePriceBar: Decodable {
    let close: Double

    private enum CodingKeys: String, CodingKey {
        case close = "4. close"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let closeString = try container.decode(String.self, forKey: .close)
        close = Double(closeString) ?? 0
    }
}

private extension DateFormatter {
    static let alphaVantageDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let alphaVantageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
