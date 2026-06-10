import SwiftUI

struct SearchScreen: View {
    @State private var searchText = ""
    @State private var results: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private let searchService: StockSearchServicing = YahooFinanceSearchService()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                searchField

                resultsContent

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationTitle("Search")
            .onChange(of: searchText) { _, newValue in
                scheduleSearch(for: newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Enter Ticker or Company Name", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageView(
                title: "Search results will show here",
                message: "Look up a ticker or company name to start researching stocks."
            )
        } else if isSearching {
            loadingView
        } else if let errorMessage {
            messageView(title: "Unable to search", message: errorMessage)
        } else if results.isEmpty {
            messageView(
                title: "No matches found",
                message: "Try another ticker, company name, or exchange symbol."
            )
        } else {
            resultsList
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Searching stocks...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results) { result in
                    NavigationLink {
                        StockViewerScreen(symbol: result.symbol, companyName: result.name, quote: BaselineStockQuoteProvider.quote(for: result.symbol))
                    } label: {
                        StockSearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func messageView(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil

        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                let searchResults = try await searchService.searchStocks(matching: trimmedQuery, limit: 12)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    results = searchResults
                    isSearching = false
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    results = []
                    errorMessage = "Check your connection and try again."
                    isSearching = false
                }
            }
        }
    }
}

private struct StockSearchResultRow: View {
    let result: StockSearchResult

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.symbol)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(result.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !result.subtitle.isEmpty {
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

#Preview {
    SearchScreen()
}
