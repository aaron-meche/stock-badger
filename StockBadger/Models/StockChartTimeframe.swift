import Foundation

enum StockChartTimeframe: String, CaseIterable, Identifiable {
    case oneDay
    case oneWeek
    case oneMonth
    case threeMonths
    case yearToDate
    case oneYear
    case fiveYears
    case max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneDay: "1D"
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .yearToDate: "YTD"
        case .oneYear: "1Y"
        case .fiveYears: "5Y"
        case .max: "MAX"
        }
    }

    var pointCount: Int {
        switch self {
        case .oneDay: 32
        case .oneWeek: 35
        case .oneMonth: 42
        case .threeMonths: 54
        case .yearToDate: 58
        case .oneYear: 64
        case .fiveYears: 72
        case .max: 82
        }
    }

    var targetMoveMultiplier: Double {
        switch self {
        case .oneDay: 1
        case .oneWeek: 2.4
        case .oneMonth: 4.1
        case .threeMonths: 7.2
        case .yearToDate: 9.4
        case .oneYear: 12.6
        case .fiveYears: 34
        case .max: 58
        }
    }

    var earliestDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .oneDay:
            return calendar.date(byAdding: .day, value: -1, to: now)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .yearToDate:
            let year = calendar.component(.year, from: now)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: now)
        case .max:
            return nil
        }
    }
}
