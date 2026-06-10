import SwiftUI

struct StockLineChart: View {
    let points: [StockChartPoint]
    let isPositive: Bool
    @Binding var selectedPoint: StockChartPoint?

    var body: some View {
        GeometryReader { proxy in
            let path = linePath(in: proxy.size)
            let fillPath = areaPath(in: proxy.size)
            let coordinates = coordinates(in: proxy.size)
            let color = isPositive ? Color.green : Color.red

            ZStack {
                ChartGridBackground()
                    .stroke(.quaternary, lineWidth: 1)

                fillPath.fill(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                path.stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                if let selectedCoordinate = selectedCoordinate(in: coordinates) {
                    selectionMarker(at: selectedCoordinate, color: color, height: proxy.size.height)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: proxy.size))
        }
        .accessibilityLabel("Stock price chart")
    }

    private func selectionMarker(at point: CGPoint, color: Color, height: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: height))
            }
            .stroke(.primary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle().stroke(Color.white, lineWidth: 4)
                }
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                .position(point)
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedPoint = nearestPoint(to: value.location.x, in: size)
            }
            .onEnded { _ in
                selectedPoint = nil
            }
    }

    private func selectedCoordinate(in coordinates: [CGPoint]) -> CGPoint? {
        guard let selectedPoint,
              let selectedIndex = points.firstIndex(where: { $0.index == selectedPoint.index }),
              coordinates.indices.contains(selectedIndex) else {
            return nil
        }

        return coordinates[selectedIndex]
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)
            guard let first = coordinates.first else { return }

            path.move(to: first)
            coordinates.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            let coordinates = coordinates(in: size)
            guard let first = coordinates.first, let last = coordinates.last else { return }

            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            coordinates.dropFirst().forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func coordinates(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }

        let values = points.map(\.price)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let valueRange = max(maxValue - minValue, 0.01)
        let horizontalStep = size.width / CGFloat(points.count - 1)

        return points.enumerated().map { index, point in
            let x = CGFloat(index) * horizontalStep
            let normalizedY = (point.price - minValue) / valueRange
            let y = size.height - (CGFloat(normalizedY) * size.height)
            return CGPoint(x: x, y: y)
        }
    }

    private func nearestPoint(to xPosition: CGFloat, in size: CGSize) -> StockChartPoint? {
        guard points.count > 1 else {
            return points.first
        }

        let clampedX = min(max(xPosition, 0), size.width)
        let horizontalStep = size.width / CGFloat(points.count - 1)
        let index = Int((clampedX / horizontalStep).rounded())
        let clampedIndex = min(max(index, 0), points.count - 1)
        return points[clampedIndex]
    }
}

struct StockChartPoint: Identifiable {
    let index: Int
    let price: Double

    var id: Int { index }
}

struct StockTimeframeChange {
    let priceChange: Double
    let percentChange: Double

    init(points: [StockChartPoint]) {
        guard let first = points.first?.price, let last = points.last?.price, first != 0 else {
            priceChange = 0
            percentChange = 0
            return
        }

        priceChange = last - first
        percentChange = (priceChange / first) * 100
    }

    var isPositive: Bool {
        priceChange >= 0
    }

    var formattedText: String {
        let price = abs(priceChange).formatted(.currency(code: "USD"))
        let percent = abs(percentChange).formatted(.number.precision(.fractionLength(2)))
        return "\(price) (\(percent)%)"
    }
}

private struct ChartGridBackground: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0...3 {
                let y = rect.height * CGFloat(index) / 3
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}
