import Foundation

struct StockPricePoint: Identifiable, Hashable, Codable {
    let date: Date
    let price: Double

    var id: Date { date }
}
