import SwiftUI

struct AppLayoutView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                HomeScreen()
            }

            Tab(AppTab.treemap.title, systemImage: AppTab.treemap.systemImage, value: AppTab.treemap) {
                StockTreemapScreen()
            }

            Tab(AppTab.analyst.title, systemImage: AppTab.analyst.systemImage, value: AppTab.analyst) {
                AnalystScreen()
            }

            Tab(AppTab.lists.title, systemImage: AppTab.lists.systemImage, value: AppTab.lists) {
                ListsScreen()
            }

            Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: AppTab.search) {
                SearchScreen()
            }
        }
        .tabViewStyle(.tabBarOnly)
    }
}

#Preview {
    AppLayoutView()
}
