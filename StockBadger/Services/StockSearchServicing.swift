import Foundation

protocol StockSearchServicing {
    func searchStocks(matching query: String, limit: Int) async throws -> [StockSearchResult]
}
