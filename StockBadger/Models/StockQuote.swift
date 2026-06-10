import Foundation

struct StockQuote: Identifiable, Hashable, Codable {
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

    var formattedPrice: String {
        price.formatted(.currency(code: "USD"))
    }

    var formattedChange: String {
        let arrow = isUp ? "↑" : "↓"
        let change = abs(dailyChange).formatted(.currency(code: "USD"))
        let percent = abs(dailyChangePercent).formatted(.number.precision(.fractionLength(2)))
        return "\(arrow) \(change) (\(percent)%)"
    }
}
