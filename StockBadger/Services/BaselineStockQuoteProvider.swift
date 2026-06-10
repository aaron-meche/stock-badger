import Foundation

enum BaselineStockQuoteProvider {
    static let quotes: [StockQuote] = [
        StockQuote(symbol: "AAPL", shortName: "Apple Inc.", price: 202.67, dailyChange: 2.18, dailyChangePercent: 1.09, marketCap: 3_020_000_000_000),
        StockQuote(symbol: "MSFT", shortName: "Microsoft Corporation", price: 470.92, dailyChange: -1.84, dailyChangePercent: -0.39, marketCap: 3_500_000_000_000),
        StockQuote(symbol: "NVDA", shortName: "NVIDIA Corporation", price: 144.12, dailyChange: 3.54, dailyChangePercent: 2.52, marketCap: 3_540_000_000_000),
        StockQuote(symbol: "GOOGL", shortName: "Alphabet Inc.", price: 176.42, dailyChange: -0.86, dailyChangePercent: -0.49, marketCap: 2_150_000_000_000),
        StockQuote(symbol: "AMZN", shortName: "Amazon.com, Inc.", price: 213.57, dailyChange: 1.92, dailyChangePercent: 0.91, marketCap: 2_240_000_000_000),
        StockQuote(symbol: "META", shortName: "Meta Platforms, Inc.", price: 632.30, dailyChange: 8.76, dailyChangePercent: 1.41, marketCap: 1_590_000_000_000),
        StockQuote(symbol: "BRK-B", shortName: "Berkshire Hathaway Inc.", price: 501.44, dailyChange: -2.61, dailyChangePercent: -0.52, marketCap: 1_080_000_000_000),
        StockQuote(symbol: "LLY", shortName: "Eli Lilly and Company", price: 775.19, dailyChange: 6.31, dailyChangePercent: 0.82, marketCap: 735_000_000_000),
        StockQuote(symbol: "AVGO", shortName: "Broadcom Inc.", price: 253.18, dailyChange: 4.11, dailyChangePercent: 1.65, marketCap: 1_180_000_000_000),
        StockQuote(symbol: "TSLA", shortName: "Tesla, Inc.", price: 318.45, dailyChange: -7.88, dailyChangePercent: -2.41, marketCap: 1_020_000_000_000),
        StockQuote(symbol: "JPM", shortName: "JPMorgan Chase & Co.", price: 266.54, dailyChange: 1.22, dailyChangePercent: 0.46, marketCap: 740_000_000_000),
        StockQuote(symbol: "WMT", shortName: "Walmart Inc.", price: 98.76, dailyChange: 0.38, dailyChangePercent: 0.39, marketCap: 790_000_000_000),
        StockQuote(symbol: "V", shortName: "Visa Inc.", price: 359.05, dailyChange: -1.37, dailyChangePercent: -0.38, marketCap: 695_000_000_000),
        StockQuote(symbol: "XOM", shortName: "Exxon Mobil Corporation", price: 109.44, dailyChange: -0.91, dailyChangePercent: -0.82, marketCap: 485_000_000_000),
        StockQuote(symbol: "MA", shortName: "Mastercard Incorporated", price: 561.28, dailyChange: 2.42, dailyChangePercent: 0.43, marketCap: 510_000_000_000),
        StockQuote(symbol: "UNH", shortName: "UnitedHealth Group Incorporated", price: 307.91, dailyChange: -5.63, dailyChangePercent: -1.80, marketCap: 280_000_000_000),
        StockQuote(symbol: "COST", shortName: "Costco Wholesale Corporation", price: 985.62, dailyChange: 7.44, dailyChangePercent: 0.76, marketCap: 437_000_000_000),
        StockQuote(symbol: "ORCL", shortName: "Oracle Corporation", price: 165.83, dailyChange: 1.56, dailyChangePercent: 0.95, marketCap: 463_000_000_000),
        StockQuote(symbol: "NFLX", shortName: "Netflix, Inc.", price: 1_185.39, dailyChange: -9.28, dailyChangePercent: -0.78, marketCap: 504_000_000_000),
        StockQuote(symbol: "PG", shortName: "The Procter & Gamble Company", price: 164.22, dailyChange: 0.77, dailyChangePercent: 0.47, marketCap: 385_000_000_000),
        StockQuote(symbol: "HD", shortName: "The Home Depot, Inc.", price: 365.80, dailyChange: -2.16, dailyChangePercent: -0.59, marketCap: 364_000_000_000),
        StockQuote(symbol: "JNJ", shortName: "Johnson & Johnson", price: 153.67, dailyChange: 0.42, dailyChangePercent: 0.27, marketCap: 370_000_000_000),
        StockQuote(symbol: "ABBV", shortName: "AbbVie Inc.", price: 186.35, dailyChange: 1.18, dailyChangePercent: 0.64, marketCap: 329_000_000_000),
        StockQuote(symbol: "BAC", shortName: "Bank of America Corporation", price: 45.41, dailyChange: -0.28, dailyChangePercent: -0.61, marketCap: 344_000_000_000)
    ]

    static func quote(for symbol: String) -> StockQuote? {
        quotes.first { $0.symbol == symbol.uppercased() }
    }
}
