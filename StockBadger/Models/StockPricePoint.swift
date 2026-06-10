import Foundation

struct StockPricePoint: Identifiable, Hashable {
    let date: Date
    let price: Double

    var id: Date { date }
}
