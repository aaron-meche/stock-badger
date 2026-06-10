import Foundation

struct StockQuote: Identifiable, Hashable {
    let symbol: String
    let shortName: String
    let price: Double
    let dailyChange: Double
    let dailyChangePercent: Double
    let marketCap: Double

    var id: String { symbol }

    var isUp: Bool {
        dailyChange >= 0
    }
}
