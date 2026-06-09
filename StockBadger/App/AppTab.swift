import SwiftUI

enum AppTab: Hashable {
    case home
    case explore
    case treemap
    case lists
    case search

    var title: String {
        switch self {
        case .home:
            "Home"
        case .explore:
            "Explore"
        case .treemap:
            "Treemap"
        case .lists:
            "Lists"
        case .search:
            "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .explore:
            "chart.line.uptrend.xyaxis"
        case .treemap:
            "square.grid.3x3"
        case .lists:
            "list.bullet.rectangle"
        case .search:
            "magnifyingglass"
        }
    }
}
