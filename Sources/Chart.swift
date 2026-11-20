import SwiftUI

/// 近 2 小时上下行趋势（原生 Canvas 绘制，不依赖第三方图表库）
struct TrendChart: View {
    let points: [HistPoint]

    private var maxValue: Double {
        let m = points.map { max($0.down, $0.up) }.max() ?? 0
        return max(m, 1024) * 1.15
    }

    var body: some View {
        VStack(spacing: 6) {
            Canvas { ctx, size in
                guard points.count > 1, size.width > 10 else { return }
                let stepX = size.width / CGFloat(max(points.count - 1, 1))

                func path(_ keyPath: KeyPath<HistPoint, Double>) -> Path {
                    var p = Path()
                    for (i, pt) in points.enumerated() {
                        let x = CGFloat(i) * stepX
                        let v = pt[keyPath: keyPath]
                        let y = size.height - CGFloat(min(v / maxValue, 1)) * size.height
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    return p
                }

                // 网格线
                for i in 0...4 {
                    let y = size.height * CGFloat(i) / 4
                    var g = Path()
                    g.move(to: CGPoint(x: 0, y: y))
                    g.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(g, with: .color(Color.white.opacity(0.05)), lineWidth: 0.6)
                }

                // 下行填充
                let downLine = path(\.down)
                var downArea = downLine
                downArea.addLine(to: CGPoint(x: size.width, y: size.height))
                downArea.addLine(to: CGPoint(x: 0, y: size.height))
                downArea.closeSubpath()
                ctx.fill(downArea, with: .linearGradient(
                    Gradient(colors: [Theme.cyan.opacity(0.42), Theme.cyan.opacity(0.03)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                ctx.stroke(downLine, with: .color(Theme.cyan.opacity(0.9)), lineWidth: 1.4)

                // 上行线
                let upLine = path(\.up)
                ctx.stroke(upLine, with: .color(Theme.purple.opacity(0.85)), lineWidth: 1.2)
            }
            .frame(height: 108)

            HStack {
                Text(timeLabel(points.first?.t, offset: -1))
                Spacer()
                Text(timeLabel(points.last?.t, offset: 0))
            }
            .font(.system(size: 9.5))
            .foregroundColor(Theme.dim)

            HStack(spacing: 14) {
                legend(color: Theme.cyan, text: "下行")
                legend(color: Theme.purple, text: "上行")
                Spacer()
                Text("峰值 \(Fmt.rate(maxValue))")
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.dim)
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 10, height: 3)
            Text(text).font(.system(size: 10)).foregroundColor(Theme.sub)
        }
    }

    private func timeLabel(_ t: Double?, offset: Int) -> String {
        guard let t else { return "" }
        if offset < 0 { return "-2h" }
        _ = t
        return "现在"
    }
}

/// 单值横向条（排行用）
struct RankRow: View {
    let title: String
    let subtitle: String?
    let valueText: String
    let fraction: Double
    let tint: Color
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(valueText)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
            }
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            MiniProgress(value: fraction, tint: tint, height: 3.5)
        }
    }
}
