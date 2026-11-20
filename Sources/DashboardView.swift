import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var m: AppModel
    @EnvironmentObject var modules: ModuleStore
    @State private var bigChart = false

    private var snap: Snapshot? { m.snap }
    private var sys: SysStat? { m.sys }
    private var host: HostInfo? { m.host }

    private var history: [HistPoint] { snap?.history ?? [] }
    private var downBytes: Double { snap?.total_down ?? 0 }
    private var upBytes: Double { snap?.total_up ?? 0 }
    private var abnTotal: Double { m.abn?.total ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 720
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header

                    ForEach(rows(wide: wide), id: \.self) { row in
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(row) { id in
                                moduleView(id)
                            }
                        }
                    }

                    if modules.visible.isEmpty {
                        emptyHint
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
            .background(AppBackground())
        }
        .sheet(isPresented: $bigChart) {
            BigChartSheet(points: history)
        }
    }

    /// 按模块声明的占位拼行：full 独占，half 两两并排；窄屏一律单列
    private func rows(wide: Bool) -> [[ModuleID]] {
        var out: [[ModuleID]] = []
        var pending: [ModuleID] = []
        for id in modules.visible {
            if !wide || id.full {
                if !pending.isEmpty { out.append(pending); pending = [] }
                out.append([id])
            } else {
                pending.append(id)
                if pending.count == 2 { out.append(pending); pending = [] }
            }
        }
        if !pending.isEmpty { out.append(pending) }
        return out
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

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22))
                .foregroundColor(Theme.dim)
            Text("所有模块都已在设置里关闭")
                .font(.system(size: 12))
                .foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }

    // MARK: 模块分发

    @ViewBuilder
    private func moduleView(_ id: ModuleID) -> some View {
        switch id {
        case .flow:      flowCard
        case .abn:       abnCard
        case .cpu:       cpuCard
        case .mem:       memCard
        case .trend:     trendCard
        case .load:      loadCard
        case .abnormal:  abnormalCard
        case .blacklist: blacklistCard
        case .disk:      diskCard
        case .dio:       dioCard
        case .ips:       ipRankCard
        case .ports:     portRankCard
        }
    }

    // MARK: 实时流量

    private var flowCard: some View {
        ModuleCard(title: ModuleID.flow.title, icon: ModuleID.flow.icon, accent: Theme.blue,
                   sub: Fmt.bps(downBytes) + " / " + Fmt.bps(upBytes)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("下载")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.dim)
                        BigValue(value: Fmt.rateValue(downBytes), unit: Fmt.rateUnit(downBytes) + "/s", tint: Theme.blue)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("上传")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.dim)
                        BigValue(value: Fmt.rateValue(upBytes), unit: Fmt.rateUnit(upBytes) + "/s", tint: Theme.orange)
                    }
                }
                Sparkline(values: history.map { $0.down }, tint: Theme.accent, height: 56)
            }
        }
        .onTapGesture { bigChart = true }
    }

    // MARK: 异常拦截

    private var abnCard: some View {
        ModuleCard(title: ModuleID.abn.title, icon: ModuleID.abn.icon, accent: Theme.red,
                   sub: Fmt.rangeLabel(m.rankRange)) {
            VStack(alignment: .leading, spacing: 10) {
                BigValue(value: Fmt.count(abnTotal), unit: "次", tint: Theme.red,
                         note: "来源 \(m.abn?.ips.count ?? 0) 个 · 端口 \(m.abn?.ports.count ?? 0) 个",
                         size: 24)
                Sparkline(values: history.map { $0.abn ?? 0 }, tint: Theme.red, height: 44)
            }
        }
    }

    // MARK: CPU / 内存

    private var cpuCard: some View {
        ModuleCard(title: ModuleID.cpu.title, icon: ModuleID.cpu.icon, accent: Theme.amber,
                   sub: loadText) {
            VStack(alignment: .leading, spacing: 8) {
                BigValue(value: String(format: "%.1f", host?.cpu ?? sys?.cpu_percent ?? 0),
                         unit: "%", tint: Theme.text, size: 24)
                MiniProgress(value: (host?.cpu ?? sys?.cpu_percent ?? 0) / 100, tint: Theme.amber, height: 4)
            }
        }
    }

    private var loadText: String {
        let l = host?.load ?? sys?.load ?? []
        guard !l.isEmpty else { return "负载 --" }
        return "负载 " + l.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    private var memCard: some View {
        ModuleCard(title: ModuleID.mem.title, icon: ModuleID.mem.icon, accent: Theme.green,
                   sub: Fmt.size(((host?.mem?.used_mb ?? sys?.mem_used_mb ?? 0)) * 1_048_576)) {
            VStack(alignment: .leading, spacing: 8) {
                BigValue(value: String(format: "%.0f", host?.mem?.percent ?? sys?.mem_percent ?? 0),
                         unit: "%", tint: Theme.text,
                         note: "共 " + Fmt.size(((host?.mem?.total_mb ?? sys?.mem_total_mb ?? 0)) * 1_048_576),
                         size: 24)
                MiniProgress(value: (host?.mem?.percent ?? sys?.mem_percent ?? 0) / 100, tint: Theme.green, height: 4)
            }
        }
    }

    // MARK: 趋势

    private var peak: Double { history.map { max($0.down, $0.up) }.max() ?? 0 }

    private var trendCard: some View {
        ModuleCard(title: ModuleID.trend.title, icon: ModuleID.trend.icon, accent: Theme.accent,
                   sub: "10 秒采样 · 近 2 小时", corner: Theme.radiusBig) {
            VStack(alignment: .leading, spacing: 8) {
                TrendChart(points: history, height: 200)
                HStack {
                    ChartLegend()
                    Spacer()
                    Text("峰值 " + Fmt.rate(peak))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                }
            }
        }
        .onTapGesture { bigChart = true }
    }

    // MARK: 系统负载

    private var loadCard: some View {
        ModuleCard(title: ModuleID.load.title, icon: ModuleID.load.icon, accent: Theme.purple, sub: loadText) {
            VStack(spacing: 0) {
                let procs = sys?.procs ?? []
                if procs.isEmpty {
                    emptyLine("暂无进程数据")
                } else {
                    ForEach(Array(procs.prefix(6))) { p in
                        MiniItemRow(
                            name: p.name,
                            sub: nil,
                            right: String(format: "%.1f%%   %.1f MB", p.cpu, p.mem_mb),
                            rightColor: p.cpu > 50 ? Theme.red : Theme.sub,
                            dotOn: true
                        )
                    }
                }
            }
            .padding(.horizontal, -10)
        }
    }

    // MARK: 异常连接

    private var abnormalCard: some View {
        ModuleCard(title: ModuleID.abnormal.title, icon: ModuleID.abnormal.icon, accent: Theme.orange,
                   sub: "近 24 小时") {
            VStack(spacing: 0) {
                if m.abnLogs.isEmpty {
                    emptyLine("暂无异常记录")
                } else {
                    ForEach(Array(m.abnLogs.prefix(6))) { log in
                        HStack(spacing: 8) {
                            Circle().fill(Theme.red.opacity(0.8)).frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(log.src)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                Text(abnSub(log))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Theme.dim)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text(Fmt.time(log.t))
                                .font(.system(size: 11))
                                .foregroundColor(Theme.sub)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
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
        ModuleCard(title: ModuleID.blacklist.title, icon: ModuleID.blacklist.icon, accent: Theme.pink,
                   sub: "\(m.blacklist.count) 个 IP") {
            VStack(spacing: 0) {
                if m.blacklist.isEmpty {
                    emptyLine("暂无黑名单")
                } else {
                    ForEach(Array(m.blacklist.prefix(6))) { b in
                        HStack(spacing: 8) {
                            Circle().fill(Theme.red).frame(width: 6, height: 6)
                            Text(b.ip)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.text)
                                .monospacedDigit()
                            Spacer(minLength: 4)
                            Text(b.geo ?? b.cc ?? "")
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.dim)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 7)
                        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
                    }
                }
            }
        }
    }

    // MARK: 磁盘

    private var diskCard: some View {
        ModuleCard(title: ModuleID.disk.title, icon: ModuleID.disk.icon, accent: Theme.cyan, sub: diskSub) {
            VStack(spacing: 10) {
                let disks = host?.disks ?? []
                if disks.isEmpty {
                    emptyLine("暂无磁盘数据")
                } else {
                    ForEach(Array(disks.prefix(3))) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(d.mount)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                    .monospacedDigit()
                                Text(d.fs ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.dim)
                                Spacer()
                                Text(Fmt.size(d.used) + " / " + Fmt.size(d.total))
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.sub)
                                    .monospacedDigit()
                                Text(String(format: "%.0f%%", d.percent))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(d.percent > 85 ? Theme.red : Theme.green)
                                    .monospacedDigit()
                            }
                            MiniProgress(value: d.percent / 100, tint: d.percent > 85 ? Theme.red : Theme.accent2, height: 4)
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
        ModuleCard(title: ModuleID.dio.title, icon: ModuleID.dio.icon, accent: Theme.accent2, sub: "实时读写") {
            HStack(spacing: 12) {
                ioCell("读", Fmt.rate(host?.dio?.read ?? 0), Theme.cyan)
                ioCell("写", Fmt.rate(host?.dio?.write ?? 0), Theme.orange)
                ioCell("累计读", Fmt.size(host?.dio?.read_total ?? 0), Theme.sub)
                ioCell("累计写", Fmt.size(host?.dio?.write_total ?? 0), Theme.sub)
            }
        }
    }

    private func ioCell(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.dim)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 排行

    private var ipRankCard: some View {
        ModuleCard(title: ModuleID.ips.title, icon: ModuleID.ips.icon, accent: Theme.orange,
                   sub: Fmt.rangeLabel(m.rankRange)) {
            VStack(spacing: 2) {
                let ips = m.abn?.ips ?? []
                if ips.isEmpty {
                    emptyLine("暂无数据")
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
        }
    }

    private func geoText(_ ip: TopIP) -> String {
        var parts: [String] = []
        if let g = ip.geo, !g.isEmpty { parts.append(g) }
        if let c = ip.cc, !c.isEmpty { parts.append(c) }
        return parts.joined(separator: " · ")
    }

    private var portRankCard: some View {
        ModuleCard(title: ModuleID.ports.title, icon: ModuleID.ports.icon, accent: Theme.green, sub: abnWindowText) {
            VStack(spacing: 2) {
                let ports = m.abn?.ports ?? []
                if ports.isEmpty {
                    emptyLine("暂无数据")
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

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Theme.sub)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
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
