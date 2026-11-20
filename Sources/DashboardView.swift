import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var m: AppModel
    @State private var bigChart = false

    private var snap: Snapshot? { m.snap }
    private var sys: SysStat? { m.sys }

    private var downBytes: Double { snap?.total_down ?? 0 }
    private var upBytes: Double { snap?.total_up ?? 0 }
    private var history: [HistPoint] { snap?.history ?? [] }
    private var abnTotal: Double { m.abn?.total ?? 0 }
    private var abnSeries: [Double] { history.map { $0.abn ?? 0 } }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 16)], spacing: 16) {
                    Button { bigChart = true } label: { flowStat }
                        .buttonStyle(PlainButtonStyle())
                    abnStat
                    cpuStat
                    memStat
                }

                trendCard

                if let procs = sys?.procs, !procs.isEmpty {
                    procsCard(procs)
                }

                sectionTitle

                AutoGrid(minWidth: 360) {
                    ipRankCard
                    portRankCard
                }

                if let err = m.lastError {
                    errorBar(err)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(
            AppBackground()
        )
        .sheet(isPresented: $bigChart) {
            BigChartSheet(points: history)
        }
    }

    // MARK: 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeader(
                title: "网络监控",
                subtitle: "外网 \(snap?.wan_ip ?? "--") · 采样 \(snap.map { Fmt.time($0.time) } ?? "--")",
                onRefresh: { Task { await m.refreshAll() } },
                refreshing: m.isRefreshing
            )

            HStack(spacing: 8) {
                Pill(text: "外网 \(snap?.wan_ip ?? "--")", tint: Theme.sub, dotColor: Theme.cyan)
                Pill(text: "共 \(snap?.total ?? 0) 台", tint: Theme.sub)
                Pill(text: "\(snap?.online ?? 0) 在线", tint: Theme.green, on: true)
                Spacer(minLength: 4)
                if let load = sys?.load.first {
                    Text(String(format: "负载 %.2f", load))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
            }
        }
    }

    // MARK: 指标

    private var flowStat: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(LinearGradient(colors: [Theme.blue, Theme.orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 8, height: 8)
                Text("实时流量")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.dim)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("↓").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.blue)
                        Text(Fmt.rateValue(downBytes))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.blue)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(Fmt.rateUnit(downBytes))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.blue.opacity(0.9))
                    }
                    Text(Fmt.bps(downBytes))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("↑").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.orange)
                        Text(Fmt.rateValue(upBytes))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.orange)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(Fmt.rateUnit(upBytes))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.orange.opacity(0.9))
                    }
                    Text(Fmt.bps(upBytes))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }

            Sparkline(values: history.map { $0.down }, tint: Theme.blue, height: 58)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
    }

    private var abnStat: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(Theme.red).frame(width: 8, height: 8)
                Text("异常拦截")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text(Fmt.rangeLabel(m.rankRange))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Fmt.count(abnTotal))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.red)
                    .monospacedDigit()
                Text("次")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.red.opacity(0.9))
            }
            Text("来源 \(m.abn?.ips.count ?? 0) 个 · 端口 \(m.abn?.ports.count ?? 0) 个")
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
            Sparkline(values: abnSeries, tint: Theme.red, height: 58)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
    }

    private var cpuStat: some View {
        StatCard(
            label: "CPU",
            dotColor: Theme.amber,
            value: String(format: "%.1f", sys?.cpu_percent ?? 0),
            unit: "%",
            note: loadText,
            tint: Theme.text
        )
    }

    private var loadText: String {
        let l = sys?.load ?? []
        guard !l.isEmpty else { return "负载 --" }
        let parts = l.prefix(3).map { String(format: "%.2f", $0) }
        return "负载 " + parts.joined(separator: " / ")
    }

    private var memStat: some View {
        StatCard(
            label: "内存",
            dotColor: Theme.green,
            value: String(format: "%.0f", sys?.mem_percent ?? 0),
            unit: "%",
            note: "已用 " + Fmt.size((sys?.mem_used_mb ?? 0) * 1_048_576) + " / " + Fmt.size((sys?.mem_total_mb ?? 0) * 1_048_576),
            tint: Theme.text
        )
    }

    // MARK: 趋势

    private var peak: Double { history.map { max($0.down, $0.up) }.max() ?? 0 }

    private var trendCard: some View {
        Button { bigChart = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text("近 2 小时趋势")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Text("10 秒采样")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.dim)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)

                VStack(alignment: .leading, spacing: 8) {
                    TrendChart(points: history, height: 210)
                    HStack {
                        Text("-2h").font(.system(size: 10)).foregroundColor(Theme.dim)
                        Spacer()
                        Text("现在").font(.system(size: 10)).foregroundColor(Theme.dim)
                    }
                    HStack(spacing: 14) {
                        ChartLegend()
                        Spacer()
                        Text("峰值 " + Fmt.rate(peak))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.dim)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusBig, style: .continuous).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusBig, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: 系统负载

    private func procsCard(_ procs: [ProcStat]) -> some View {
        PanelCard(title: "系统负载", sub: loadText) {
            VStack(spacing: 0) {
                ForEach(Array(procs.prefix(5))) { p in
                    MiniItemRow(
                        name: p.name,
                        sub: nil,
                        right: String(format: "%.1f%%   %.1f MB", p.cpu, p.mem_mb),
                        rightColor: p.cpu > 50 ? Theme.red : Theme.sub,
                        dotOn: true
                    )
                }
            }
            .padding(.horizontal, -6)
        }
    }

    // MARK: 排行

    private var sectionTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.sub)
            Text("外网访问与扫描")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
            Spacer()
            Menu {
                Button("24 小时") { m.setRange("1") }
                Button("7 天") { m.setRange("7") }
                Button("30 天") { m.setRange("30") }
                Button("1 年") { m.setRange("all") }
            } label: {
                HStack(spacing: 5) {
                    Text(Fmt.rangeLabel(m.rankRange))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
        }
        .padding(.top, 2)
    }

    private var ipRankCard: some View {
        PanelCard(title: "外网来源 IP 排行", sub: "共 \(Fmt.count(abnTotal)) 次") {
            VStack(spacing: 2) {
                let ips = m.abn?.ips ?? []
                if ips.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    ForEach(Array(ips.prefix(8).indices), id: \.self) { i in
                        let ip = ips[i]
                        RankRow(
                            index: i,
                            main: ip.ip,
                            sub: geoText(ip),
                            count: Fmt.count(ip.cnt),
                            unitText: "次",
                            ratio: ip.pct / 100.0
                        )
                    }
                }
            }
            .padding(.horizontal, -8)
        }
    }

    private func geoText(_ ip: TopIP) -> String {
        var parts: [String] = []
        if let g = ip.geo, !g.isEmpty { parts.append(g) }
        if let c = ip.cc, !c.isEmpty { parts.append(c) }
        return parts.joined(separator: " · ")
    }

    private var portRankCard: some View {
        PanelCard(title: "被扫描端口排行", sub: abnWindowText) {
            VStack(spacing: 2) {
                let ports = m.abn?.ports ?? []
                if ports.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    ForEach(Array(ports.prefix(8).indices), id: \.self) { i in
                        let p = ports[i]
                        RankRow(
                            index: i,
                            main: p.port,
                            sub: portSub(p),
                            count: Fmt.count(p.cnt),
                            unitText: "次",
                            ratio: p.pct / 100.0
                        )
                    }
                }
            }
            .padding(.horizontal, -8)
        }
    }

    private var abnWindowText: String {
        guard let w = m.abn?.win else { return "" }
        return "窗口 \(Int(w / 3600)) 小时"
    }

    private func portSub(_ p: TopPort) -> String {
        var parts: [String] = []
        if let s = p.svc, !s.isEmpty { parts.append(s) }
        if let srcs = p.srcs { parts.append("\(Int(srcs)) 个来源") }
        return parts.joined(separator: " · ")
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
            Text(text).font(.system(size: 12)).foregroundColor(Theme.sub).lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.amber.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.amber.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - 大图

struct BigChartSheet: View {
    let points: [HistPoint]
    @Environment(\.dismiss) private var dismiss

    private var peak: Double { points.map { max($0.down, $0.up) }.max() ?? 0 }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                TrendChart(points: points, height: 260)
                HStack {
                    ChartLegend()
                    Spacer()
                    Text("峰值 " + Fmt.rate(peak))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
                Text("每 10 秒采样 · 最近 2 小时")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                Spacer()
            }
            .padding(18)
            .background(AppBackground())
            .navigationTitle("实时流量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
