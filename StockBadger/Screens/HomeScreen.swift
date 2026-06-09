import SwiftUI

struct HomeScreen: View {
    var body: some View {
        NavigationStack {
            Text("Home Screen")
                .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeScreen()
}
