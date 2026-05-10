import SwiftUI

struct TokenChartView: View {
    struct ProjectSeries {
        let data: [Int]
        let costData: [Double]
        let color: Color
    }

    let series: [ProjectSeries]

    @State private var hoverBucket: Int? = nil
    @State private var hoverX: CGFloat = 0

    private var maxValue: CGFloat {
        CGFloat(series.flatMap(\.data).max() ?? 1)
    }

    private var bucketCount: Int { series.first?.data.count ?? 168 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                dayTicks(size: geo.size)
                ForEach(series.indices, id: \.self) { i in
                    let pts = points(data: series[i].data, in: geo.size)
                    let color = series[i].color
                    linePath(pts: pts)
                        .stroke(color.opacity(0.30), lineWidth: 4)
                        .blur(radius: 3)
                    linePath(pts: pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
                if let bucket = hoverBucket {
                    hoverOverlay(bucket: bucket, size: geo.size)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    hoverX = loc.x
                    let idx = Int(loc.x / geo.size.width * CGFloat(bucketCount))
                    hoverBucket = min(max(0, idx), bucketCount - 1)
                case .ended:
                    hoverBucket = nil
                }
            }
        }
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private func hoverOverlay(bucket: Int, size: CGSize) -> some View {
        let totalTokens = series.reduce(0) { $0 + (bucket < $1.data.count ? $1.data[bucket] : 0) }
        let totalCost = series.reduce(0.0) { $0 + (bucket < $1.costData.count ? $1.costData[bucket] : 0) }

        if totalTokens > 0 || totalCost > 0 {
            let xPos = CGFloat(bucket) / CGFloat(max(bucketCount - 1, 1)) * size.width

            // Vertical cursor line
            Path { p in
                p.move(to: CGPoint(x: xPos, y: 0))
                p.addLine(to: CGPoint(x: xPos, y: size.height))
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            // Tooltip pill
            let label = totalCost > 0
                ? "\(totalTokens.formattedTokens)  \(totalCost.formattedCost)"
                : totalTokens.formattedTokens
            let pillWidth: CGFloat = totalCost > 0 ? 110 : 60
            let clampedX = min(max(xPos, pillWidth / 2 + 4), size.width - pillWidth / 2 - 4)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.75), in: Capsule())
                .position(x: clampedX, y: 12)
        }
    }

    // MARK: - Paths

    private func points(data: [Int], in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let pad: CGFloat = 6
        let h = size.height - pad * 2
        return data.enumerated().map { (i, v) in
            CGPoint(
                x: CGFloat(i) / CGFloat(data.count - 1) * size.width,
                y: size.height - pad - (maxValue > 0 ? CGFloat(v) / maxValue * h : 0)
            )
        }
    }

    private func linePath(pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for i in 1..<pts.count {
            let p = pts[i - 1], c = pts[i]
            let midX = (p.x + c.x) / 2
            path.addCurve(to: c, control1: CGPoint(x: midX, y: p.y), control2: CGPoint(x: midX, y: c.y))
        }
        return path
    }

    private var tickEvery: Int {
        switch bucketCount {
        case 24:  return 0
        case 168: return 24
        default:  return 7
        }
    }

    @ViewBuilder
    private func dayTicks(size: CGSize) -> some View {
        if tickEvery > 0 {
            Canvas { ctx, sz in
                let numTicks = (self.bucketCount / self.tickEvery) - 1
                guard numTicks > 0 else { return }
                for t in 1...numTicks {
                    let x = CGFloat(t * self.tickEvery) / CGFloat(self.bucketCount - 1) * sz.width
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: 0))
                    tick.addLine(to: CGPoint(x: x, y: sz.height))
                    ctx.stroke(tick, with: .color(.white.opacity(0.07)), lineWidth: 1)
                }
            }
        }
    }
}
