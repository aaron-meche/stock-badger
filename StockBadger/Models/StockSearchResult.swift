import Foundation

struct StockSearchResult: Identifiable, Hashable {
    let symbol: String
    let name: String
    let exchange: String?
    let type: String?

    var id: String { symbol }

    var subtitle: String {
        [exchange, type]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }
}
