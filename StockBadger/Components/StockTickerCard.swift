import SwiftUI

struct StockTickerCard: View {
    let quote: StockQuote
    let style: StockTickerCardStyle

    init(_ quote: StockQuote, style: StockTickerCardStyle = .regular) {
        self.quote = quote
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            HStack(alignment: .top, spacing: 6) {
                Text(quote.symbol)
                    .font(style.symbolFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 0)

                if style.showsArrow {
                    Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(style.arrowFont)
                        .foregroundStyle(statusColor)
                }
            }

            if style.showsName {
                Text(quote.shortName)
                    .font(style.nameFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(style.nameLineLimit)
                    .frame(minHeight: style.nameMinHeight, alignment: .topLeading)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                if style.showsPrice {
                    Text(quote.formattedPrice)
                        .font(style.priceFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(quote.formattedChange)
                    .font(style.changeFont)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .padding(style.padding)
        .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(statusColor.opacity(style.borderOpacity), lineWidth: style.borderWidth)
        }
        .shadow(color: statusColor.opacity(style.shadowOpacity), radius: style.shadowRadius, y: style.shadowY)
    }

    private var statusColor: Color {
        quote.isUp ? .green : .red
    }
}

enum StockTickerCardStyle {
    case featured
    case regular
    case dense
    case compact

    var minHeight: CGFloat {
        switch self {
        case .featured: 150
        case .regular: 126
        case .dense: 98
        case .compact: 48
        }
    }

    var padding: CGFloat {
        switch self {
        case .featured: 14
        case .regular: 12
        case .dense: 9
        case .compact: 9
        }
    }

    var spacing: CGFloat {
        switch self {
        case .featured: 10
        case .regular: 8
        case .dense: 6
        case .compact: 3
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 12
        default: 16
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .featured: 1.4
        case .regular: 1.2
        default: 1
        }
    }

    var borderOpacity: Double {
        switch self {
        case .compact: 0.45
        default: 0.72
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .featured: 0.08
        default: 0.04
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .featured: 10
        default: 5
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .featured: 5
        default: 2
        }
    }

    var showsName: Bool {
        self == .featured || self == .regular
    }

    var showsPrice: Bool {
        self != .compact
    }

    var showsArrow: Bool {
        self != .compact
    }

    var nameLineLimit: Int {
        self == .featured ? 2 : 1
    }

    var nameMinHeight: CGFloat {
        switch self {
        case .featured: 32
        case .regular: 18
        default: 0
        }
    }

    var symbolFont: Font {
        switch self {
        case .featured: .headline.bold()
        case .regular: .subheadline.bold()
        case .dense, .compact: .caption.weight(.bold)
        }
    }

    var arrowFont: Font {
        switch self {
        case .featured: .caption.bold()
        default: .caption2.bold()
        }
    }

    var nameFont: Font {
        switch self {
        case .featured: .caption
        default: .caption2
        }
    }

    var priceFont: Font {
        switch self {
        case .featured: .subheadline.weight(.semibold)
        case .regular: .caption.weight(.semibold)
        default: .caption2.weight(.semibold)
        }
    }

    var changeFont: Font {
        switch self {
        case .featured, .regular: .caption2.weight(.semibold)
        case .dense, .compact: .system(size: 9, weight: .semibold)
        }
    }
}
