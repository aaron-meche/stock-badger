import SwiftUI

enum AppTab: Hashable {
    case home
    case treemap
    case analyst
    case lists
    case search

    var title: String {
        switch self {
        case .home:
            "Home"
        case .treemap:
            "Treemap"
        case .analyst:
            "Analyst"
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
        case .treemap:
            "square.grid.3x3"
        case .analyst:
            "sparkles"
        case .lists:
            "list.bullet.rectangle"
        case .search:
            "magnifyingglass"
        }
    }
}
