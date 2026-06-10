import Foundation

protocol StockQuoteFetching {
    func fetchQuotes(for symbols: [String]) async throws -> [StockQuote]
}
