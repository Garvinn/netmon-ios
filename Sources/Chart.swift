import SwiftUI

// MARK: - 趋势图（对应网页 ECharts 面积图：下行蓝色面积 + 上行橙色线）

struct TrendChart: View {
    let points: [HistPoint]
    var height: CGFloat = 200
    var showGrid: Bool = true

    private var maxValue: Double {
        let m = points.map { max($0.down, $0.up) }.max() ?? 0
        return max(m, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                if showGrid {
                    ForEach(0..<4) { i in
                        let y = h * CGFloat(i) / 3
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Theme.fillSoft, lineWidth: 0.8)
                    }
                }

                areaPath(w: w, h: h)
                    .fill(LinearGradient(colors: [Theme.blue.opacity(0.26), Theme.blue.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                linePath(w: w, h: h, down: true)
                    .stroke(Theme.blue, lineWidth: 1.6)
                linePath(w: w, h: h, down: false)
                    .stroke(Theme.purple, lineWidth: 1.4)
            }
        }
        .frame(height: height)
    }

    private func point(_ i: Int, w: CGFloat, h: CGFloat, down: Bool) -> CGPoint {
        let p = points[i]
        let v = down ? p.down : p.up
        let x = w * CGFloat(i) / CGFloat(max(points.count - 1, 1))
        let y = h - h * CGFloat(min(max(v / maxValue, 0), 1)) * 0.94
        return CGPoint(x: x, y: y)
    }

    private func linePath(w: CGFloat, h: CGFloat, down: Bool) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: point(0, w: w, h: h, down: down))
        for i in 1..<points.count {
            path.addLine(to: point(i, w: w, h: h, down: down))
        }
        return path
    }

    private func areaPath(w: CGFloat, h: CGFloat) -> Path {
        var path = linePath(w: w, h: h, down: true)
        guard points.count > 1 else { return path }
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - 迷你走势（对应网页 .top-chart）

struct Sparkline: View {
    let values: [Double]
    var tint: Color = Theme.blue
    var showFill: Bool = true
    var height: CGFloat = 44

    private var maxValue: Double { max(values.max() ?? 0, 1) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                if showFill { areaPath(w: w, h: h).fill(tint.opacity(0.18)) }
                linePath(w: w, h: h).stroke(tint, lineWidth: 1.3)
            }
        }
        .frame(height: height)
    }

    private func pt(_ i: Int, w: CGFloat, h: CGFloat) -> CGPoint {
        let x = w * CGFloat(i) / CGFloat(max(values.count - 1, 1))
        let y = h - h * CGFloat(min(max(values[i] / maxValue, 0), 1)) * 0.9
        return CGPoint(x: x, y: y)
    }

    private func linePath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        p.move(to: pt(0, w: w, h: h))
        for i in 1..<values.count { p.addLine(to: pt(i, w: w, h: h)) }
        return p
    }

    private func areaPath(w: CGFloat, h: CGFloat) -> Path {
        var p = linePath(w: w, h: h)
        guard values.count > 1 else { return p }
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - 图例

struct ChartLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(Theme.blue, "下行")
            legendItem(Theme.purple, "上行")
        }
    }

    private func legendItem(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5).fill(c).frame(width: 11, height: 3)
            Text(t).font(.system(size: 11)).foregroundColor(Theme.dim)
        }
    }
}
