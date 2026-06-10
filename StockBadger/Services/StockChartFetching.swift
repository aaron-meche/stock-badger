import Foundation

protocol StockChartFetching {
    func fetchPriceHistory(for symbol: String, timeframe: StockChartTimeframe) async throws -> [StockPricePoint]
}
