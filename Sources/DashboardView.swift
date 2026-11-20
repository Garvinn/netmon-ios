import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var m: AppModel
    @State private var bigChart = false

    private var snap: Snapshot? { m.snap }
    private var sys: SysStat? { m.sys }
    private var host: HostInfo? { m.host }

    private var history: [HistPoint] { snap?.history ?? [] }
    private var downBytes: Double { snap?.total_down ?? 0 }
    private var upBytes: Double { snap?.total_up ?? 0 }
    private var abnTotal: Double { m.abn?.total ?? 0 }
    private var peak: Double { history.map { max($0.down, $0.up) }.max() ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 700
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    header

                    row(flowCard, abnCard, wide: wide)
                    row(cpuCard, memCard, wide: wide)
                    trendCard
                    row(loadCard, abnormalCard, wide: wide)
                    row(blacklistCard, diskCard, wide: wide)
                    dioCard

                    sectionHeader
                    row(ipRankCard, portRankCard, wide: wide)

                    if let err = m.lastError {
                        errorBar(err)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
        }
        .sheet(isPresented: $bigChart) {
            BigChartSheet(points: history)
        }
    }

    /// 两两并排，窄窗自动上下堆叠
    @ViewBuilder
    private func row<A: View, B: View>(_ a: A, _ b: B, wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 10) {
                a.frame(maxWidth: .infinity)
                b.frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 10) {
                a
                b
            }
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
                Text("负载 " + loadNums)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: 实时流量

    private var flowCard: some View {
        StatsCard(padding: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    speedTile(Fmt.rateValue(downBytes), Fmt.rateUnit(downBytes) + "/s", "下载", Theme.blue)
                    speedTile(Fmt.rateValue(upBytes), Fmt.rateUnit(upBytes) + "/s", "上传", Theme.orange)
                }
                Sparkline(values: history.map { $0.down }, tint: Theme.accent, height: 52)
            }
        }
        .onTapGesture { bigChart = true }
    }

    private func speedTile(_ value: String, _ unit: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            StatsValue(value: value, unit: unit, tint: tint, size: 24)
            StatsCaption(text: label, color: tint)
        }
    }

    // MARK: 异常拦截

    private var abnCard: some View {
        StatsCard(padding: 16) {
            VStack(spacing: 10) {
                StatsValue(value: Fmt.count(abnTotal), unit: "次", tint: Theme.red, size: 24)
                StatsCaption(text: "异常拦截",
                             color: Theme.red,
                             trailing: "来源 \(m.abn?.ips.count ?? 0) · 端口 \(m.abn?.ports.count ?? 0)")
                Sparkline(values: history.map { $0.abn ?? 0 }, tint: Theme.red, height: 40)
            }
        }
    }

    // MARK: CPU / 内存

    private var cpuCard: some View {
        StatsCard(padding: 16) {
            VStack(spacing: 8) {
                StatsValue(value: String(format: "%.1f", host?.cpu ?? sys?.cpu_percent ?? 0), unit: "%", size: 24)
                StatsCaption(text: "CPU", color: Theme.amber, trailing: loadText)
                MiniProgress(value: (host?.cpu ?? sys?.cpu_percent ?? 0) / 100, tint: Theme.amber, height: 3)
            }
        }
    }

    private var loadNums: String {
        let l = host?.load ?? sys?.load ?? []
        return l.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    private var loadText: String {
        let n = loadNums
        return n.isEmpty ? "--" : n
    }

    private var memCard: some View {
        StatsCard(padding: 16) {
            VStack(spacing: 8) {
                StatsValue(value: String(format: "%.0f", host?.mem?.percent ?? sys?.mem_percent ?? 0), unit: "%", size: 24)
                StatsCaption(text: "内存",
                             color: Theme.green,
                             trailing: Fmt.size(((host?.mem?.used_mb ?? sys?.mem_used_mb ?? 0)) * 1_048_576)
                                + " / " + Fmt.size(((host?.mem?.total_mb ?? sys?.mem_total_mb ?? 0)) * 1_048_576))
                MiniProgress(value: (host?.mem?.percent ?? sys?.mem_percent ?? 0) / 100, tint: Theme.green, height: 3)
            }
        }
    }

    // MARK: 趋势

    private var trendCard: some View {
        StatsCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                StatsCaption(text: "近 2 小时趋势", trailing: "峰值 " + Fmt.rate(peak))
                TrendChart(points: history, height: 190)
                HStack(spacing: 12) {
                    ChartLegend()
                    Spacer()
                    Text("10 秒采样")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                }
            }
        }
        .onTapGesture { bigChart = true }
    }

    // MARK: 系统负载

    private var loadCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "系统负载", trailing: loadText)
                VStack(spacing: 0) {
                    let procs = sys?.procs ?? []
                    if procs.isEmpty {
                        emptyLine("暂无进程数据")
                    } else {
                        ForEach(Array(procs.prefix(6))) { p in
                            listRow(title: p.name,
                                    sub: nil,
                                    right: String(format: "%.1f%%  %.1f MB", p.cpu, p.mem_mb),
                                    rightColor: p.cpu > 50 ? Theme.red : Theme.sub)
                        }
                    }
                }
            }
        }
    }

    // MARK: 异常连接

    private var abnormalCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "异常连接", trailing: "近 24 小时")
                VStack(spacing: 0) {
                    if m.abnLogs.isEmpty {
                        emptyLine("暂无异常记录")
                    } else {
                        ForEach(Array(m.abnLogs.prefix(6))) { log in
                            listRow(title: log.src, sub: abnSub(log), right: Fmt.time(log.t), rightColor: Theme.sub)
                        }
                    }
                }
            }
        }
    }

    private func abnSub(_ log: AbnLog) -> String {
        var parts: [String] = []
        if let kind = log.kind, !kind.isEmpty { parts.append(kind) }
        if let geo = log.geo, !geo.isEmpty { parts.append(geo) }
        if let dst = log.dst, !dst.isEmpty { parts.append(dst) }
        return parts.joined(separator: " · ")
    }

    // MARK: 黑名单

    private var blacklistCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "黑名单", trailing: "\(m.blacklist.count) 个 IP")
                VStack(spacing: 0) {
                    if m.blacklist.isEmpty {
                        emptyLine("暂无黑名单")
                    } else {
                        ForEach(Array(m.blacklist.prefix(6))) { b in
                            listRow(title: b.ip, sub: nil, right: b.geo ?? b.cc ?? "", rightColor: Theme.dim)
                        }
                    }
                }
            }
        }
    }

    // MARK: 磁盘

    private var diskCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "磁盘", trailing: diskSub)
                VStack(spacing: 9) {
                    let disks = host?.disks ?? []
                    if disks.isEmpty {
                        emptyLine("暂无磁盘数据")
                    } else {
                        ForEach(Array(disks.prefix(3))) { d in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(d.mount)
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.text)
                                    Text(d.fs ?? "")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.dim)
                                    Spacer(minLength: 4)
                                    Text(Fmt.size(d.used) + " / " + Fmt.size(d.total))
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.sub)
                                    Text(String(format: "%.0f%%", d.percent))
                                        .font(.system(size: 11))
                                        .foregroundColor(d.percent > 85 ? Theme.red : Theme.sub)
                                }
                                MiniProgress(value: d.percent / 100,
                                             tint: d.percent > 85 ? Theme.red : Theme.accent2,
                                             height: 3)
                            }
                        }
                    }
                }
            }
        }
    }

    private var diskSub: String {
        let total = (host?.disks ?? []).reduce(0.0) { $0 + $1.total }
        return total > 0 ? "合计 " + Fmt.size(total) : ""
    }

    // MARK: 磁盘 IO

    private var dioCard: some View {
        StatsCard(padding: 16) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ioCell("读", Fmt.rate(host?.dio?.read ?? 0))
                    ioCell("写", Fmt.rate(host?.dio?.write ?? 0))
                    ioCell("累计读", Fmt.size(host?.dio?.read_total ?? 0))
                    ioCell("累计写", Fmt.size(host?.dio?.write_total ?? 0))
                }
            }
        }
    }

    private func ioCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            StatsValue(value: value, unit: "", size: 17, leading: false)
            StatsCaption(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 排行

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("外网访问与扫描")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.sub)
            Spacer()
            Menu {
                Button("24 小时") { m.setRange("1") }
                Button("7 天") { m.setRange("7") }
                Button("30 天") { m.setRange("30") }
                Button("1 年") { m.setRange("all") }
            } label: {
                HStack(spacing: 4) {
                    Text(Fmt.rangeLabel(m.rankRange))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.top, 6)
    }

    private var ipRankCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "外网来源 IP", trailing: Fmt.rangeLabel(m.rankRange))
                VStack(spacing: 2) {
                    let ips = m.abn?.ips ?? []
                    if ips.isEmpty {
                        emptyLine("暂无数据")
                    } else {
                        ForEach(Array(ips.prefix(8).indices), id: \.self) { i in
                            let ip = ips[i]
                            RankRow(index: i,
                                    main: ip.ip,
                                    sub: geoText(ip),
                                    count: Fmt.count(ip.cnt),
                                    unitText: "次",
                                    ratio: ip.pct / 100.0)
                        }
                    }
                }
            }
        }
    }

    private func geoText(_ ip: TopIP) -> String {
        var parts: [String] = []
        if let g = ip.geo, !g.isEmpty { parts.append(g) }
        if let c = ip.cc, !c.isEmpty { parts.append(c) }
        return parts.joined(separator: " · ")
    }

    private var portRankCard: some View {
        StatsCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StatsCaption(text: "被扫描端口", trailing: abnWindowText)
                VStack(spacing: 2) {
                    let ports = m.abn?.ports ?? []
                    if ports.isEmpty {
                        emptyLine("暂无数据")
                    } else {
                        ForEach(Array(ports.prefix(8).indices), id: \.self) { i in
                            let p = ports[i]
                            RankRow(index: i,
                                    main: p.port,
                                    sub: portSub(p),
                                    count: Fmt.count(p.cnt),
                                    unitText: "次",
                                    ratio: p.pct / 100.0)
                        }
                    }
                }
            }
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

    // MARK: 通用行

    private func listRow(title: String, sub: String?, right: String, rightColor: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Theme.text)
                .lineLimit(1)
            if let sub = sub, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(right)
                .font(.system(size: 11))
                .foregroundColor(rightColor)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1), alignment: .bottom)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.amber)
            Text(text).font(.system(size: 11)).foregroundColor(Theme.sub).lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.10)))
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
