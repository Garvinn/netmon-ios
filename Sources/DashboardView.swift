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

    private var online: Int { snap?.online ?? 0 }
    private var totalDev: Int { snap?.total ?? 0 }
    private var cpuPct: Double { host?.cpu ?? sys?.cpu_percent ?? 0 }
    private var memPct: Double { host?.mem?.percent ?? sys?.mem_percent ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 700
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    header

                    row(statusCard, loadCard, wide: wide)
                    networkCard
                    row(diskCard, dioCard, wide: wide)
                    row(abnCard, abnormalCard, wide: wide)
                    row(blacklistCard, procsCard, wide: wide)

                    sectionHeader
                    row(ipRankCard, portRankCard, wide: wide)

                    if let err = m.lastError {
                        errorBar(err)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
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
                subtitle: "外网 \(snap?.wan_ip ?? "--") · \(Fmt.time(snap?.time ?? 0))",
                onRefresh: { Task { await m.refreshAll() } },
                refreshing: m.isRefreshing
            )
            HStack(spacing: 8) {
                PulseChip(text: "\(online) / \(totalDev) 台在线", tint: Theme.green)
                PulseChip(text: "CPU \(String(format: "%.0f", cpuPct))%", tint: Theme.accent)
                PulseChip(text: "MEM \(String(format: "%.0f", memPct))%", tint: Theme.purple)
                Spacer(minLength: 4)
                Text(snap?.wan_ip ?? "")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: 节点状态

    private var statusCard: some View {
        PulseCard(icon: "bolt.horizontal.fill", title: "节点状态",
                  accent: Theme.blue, status: online > 0 ? "在线" : "离线",
                  statusOK: online > 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        PulseLabel(text: "在线设备")
                        PulseValue(value: "\(online)", unit: "台", size: 30, leading: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        PulseLabel(text: "已发现")
                        Text("\(totalDev) 台")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.text)
                    }
                }

                HStack(spacing: 8) {
                    infoCell("外网 IP", snap?.wan_ip ?? "--", Theme.blue)
                    infoCell("采样", Fmt.time(snap?.time ?? 0), Theme.purple)
                }
            }
        }
    }

    private func infoCell(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            PulseLabel(text: label)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fillSoft))
    }

    // MARK: 资源负载

    private var loadCard: some View {
        PulseCard(icon: "cpu", title: "资源负载",
                  accent: Theme.cyan,
                  status: cpuPct > 85 ? "负载偏高" : "负载正常",
                  statusOK: cpuPct <= 85) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        PulseLabel(text: "CPU")
                        PulseValue(value: String(format: "%.0f", cpuPct), unit: "%", size: 24, leading: true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        PulseLabel(text: "内存")
                        PulseValue(value: String(format: "%.0f", memPct), unit: "%", size: 24, leading: true)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        PulseLabel(text: "温度")
                        Text(tempText)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.text)
                    }
                }

                VStack(spacing: 6) {
                    MiniProgress(value: cpuPct / 100, tint: Theme.accent, height: 4)
                    MiniProgress(value: memPct / 100, tint: Theme.purple, height: 4)
                }

                HStack(spacing: 6) {
                    PulseLabel(text: "LOAD")
                    Text(loadNums.isEmpty ? "--" : loadNums)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.sub)
                    Spacer(minLength: 4)
                    Text(uptimeText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }
        }
    }

    private var tempText: String {
        guard let t = host?.temp, t > 0 else { return "--" }
        return String(format: "%.0f℃", t)
    }

    private var loadNums: String {
        let l = host?.load ?? sys?.load ?? []
        return l.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " ")
    }

    private var uptimeText: String {
        guard let sec = host?.uptime?.seconds, sec > 0 else { return "" }
        let d = Int(sec / 86400)
        let h = Int((sec.truncatingRemainder(dividingBy: 86400)) / 3600)
        return d > 0 ? "运行 \(d) 天 \(h) 小时" : "运行 \(h) 小时"
    }

    // MARK: 网络

    private var networkCard: some View {
        PulseCard(icon: "network", title: "网络",
                  accent: Theme.blue,
                  status: "峰值 " + Fmt.rate(peak)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    netTile(arrow: "arrow.down", label: "下载", tint: Theme.blue,
                            value: Fmt.rateValue(downBytes), unit: Fmt.rateUnit(downBytes))
                    netTile(arrow: "arrow.up", label: "上传", tint: Theme.purple,
                            value: Fmt.rateValue(upBytes), unit: Fmt.rateUnit(upBytes))
                }
                TrendChart(points: history, height: 150)
                HStack(spacing: 12) {
                    ChartLegend()
                    Spacer()
                    Text("近 2 小时 · 10 秒采样")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                }
            }
        }
        .onTapGesture { bigChart = true }
    }

    private func netTile(arrow: String, label: String, tint: Color, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: arrow)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(tint)
                PulseLabel(text: label, tint: tint)
            }
            PulseValue(value: value, unit: unit + "/s", tint: tint, size: 22, leading: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.07)))
    }

    // MARK: 磁盘

    private var diskCard: some View {
        PulseCard(icon: "internaldrive.fill", title: "存储",
                  accent: Theme.cyan,
                  status: diskSub.isEmpty ? nil : diskSub) {
            VStack(spacing: 10) {
                let disks = host?.disks ?? []
                if disks.isEmpty {
                    emptyLine("暂无磁盘数据")
                } else {
                    ForEach(Array(disks.prefix(3))) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(d.mount)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                if let fs = d.fs, !fs.isEmpty {
                                    PulseChip(text: fs, tint: Theme.cyan)
                                }
                                Spacer(minLength: 4)
                                Text(String(format: "%.0f%%", d.percent))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(d.percent > 85 ? Theme.red : Theme.text)
                            }
                            MiniProgress(value: d.percent / 100,
                                         tint: d.percent > 85 ? Theme.red : Theme.accent,
                                         height: 4)
                            PulseLabel(text: Fmt.size(d.used) + " / " + Fmt.size(d.total))
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
        PulseCard(icon: "externaldrive.badge.timemachine", title: "磁盘 IO", accent: Theme.purple) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ioCell("读", Fmt.rate(host?.dio?.read ?? 0), Theme.blue)
                    ioCell("写", Fmt.rate(host?.dio?.write ?? 0), Theme.purple)
                }
                HStack(spacing: 8) {
                    ioCell("累计读", Fmt.size(host?.dio?.read_total ?? 0), Theme.sub)
                    ioCell("累计写", Fmt.size(host?.dio?.write_total ?? 0), Theme.sub)
                }
            }
        }
    }

    private func ioCell(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            PulseLabel(text: label)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fillSoft))
    }

    // MARK: 异常拦截

    private var abnCard: some View {
        PulseCard(icon: "shield.lefthalf.filled", title: "异常拦截",
                  accent: Theme.red,
                  status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(alignment: .leading, spacing: 10) {
                PulseValue(value: Fmt.count(abnTotal), unit: "次", tint: Theme.red, size: 26, leading: true)
                HStack(spacing: 8) {
                    PulseChip(text: "来源 \(m.abn?.ips.count ?? 0)", tint: Theme.orange)
                    PulseChip(text: "端口 \(m.abn?.ports.count ?? 0)", tint: Theme.red)
                }
                Sparkline(values: history.map { $0.abn ?? 0 }, tint: Theme.red, height: 36)
            }
        }
    }

    // MARK: 异常连接

    private var abnormalCard: some View {
        PulseCard(icon: "exclamationmark.triangle.fill", title: "异常连接",
                  accent: Theme.orange, status: "近 24 小时", statusOK: false) {
            VStack(spacing: 0) {
                if m.abnLogs.isEmpty {
                    emptyLine("暂无异常记录")
                } else {
                    ForEach(Array(m.abnLogs.prefix(5))) { log in
                        listRow(title: log.src, sub: abnSub(log), right: Fmt.time(log.t), rightColor: Theme.dim)
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
        PulseCard(icon: "hand.raised.fill", title: "黑名单",
                  accent: Theme.pink, status: "\(m.blacklist.count) 个 IP") {
            VStack(spacing: 0) {
                if m.blacklist.isEmpty {
                    emptyLine("暂无黑名单")
                } else {
                    ForEach(Array(m.blacklist.prefix(5))) { b in
                        listRow(title: b.ip, sub: nil, right: b.geo ?? b.cc ?? "", rightColor: Theme.dim)
                    }
                }
            }
        }
    }

    // MARK: 系统负载

    private var procsCard: some View {
        PulseCard(icon: "list.bullet.rectangle", title: "系统负载",
                  accent: Theme.green, status: loadNums.isEmpty ? nil : "LOAD " + loadNums) {
            VStack(spacing: 0) {
                let procs = sys?.procs ?? []
                if procs.isEmpty {
                    emptyLine("暂无进程数据")
                } else {
                    ForEach(Array(procs.prefix(5))) { p in
                        listRow(title: p.name,
                                sub: nil,
                                right: String(format: "%.1f%% · %.1f MB", p.cpu, p.mem_mb),
                                rightColor: p.cpu > 50 ? Theme.red : Theme.sub)
                    }
                }
            }
        }
    }

    // MARK: 排行

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("外网访问与扫描")
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.sub)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            }
        }
        .padding(.top, 6)
    }

    private var ipRankCard: some View {
        PulseCard(icon: "globe.asia.australia.fill", title: "来源 IP",
                  accent: Theme.orange, status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(spacing: 2) {
                let ips = m.abn?.ips ?? []
                if ips.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ips.prefix(8).indices), id: \.self) { i in
                        let ip = ips[i]
                        PulseRankRow(index: i, main: ip.ip, sub: geoText(ip),
                                     count: Fmt.count(ip.cnt), ratio: ip.pct / 100)
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
        PulseCard(icon: "network", title: "扫描端口",
                  accent: Theme.green, status: abnWindowText, statusOK: false) {
            VStack(spacing: 2) {
                let ports = m.abn?.ports ?? []
                if ports.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ports.prefix(8).indices), id: \.self) { i in
                        let p = ports[i]
                        PulseRankRow(index: i, main: p.port, sub: portSub(p),
                                     count: Fmt.count(p.cnt), ratio: p.pct / 100)
                    }
                }
            }
        }
    }

    private var abnWindowText: String {
        guard let w = m.abn?.win else { return "" }
        return "\(Int(w / 3600)) 小时"
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
                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(rightColor)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.orange)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.orange.opacity(0.10)))
    }
}

// MARK: - 排行行（浅色版）

struct PulseRankRow: View {
    let index: Int
    let main: String
    let sub: String?
    let count: String
    let ratio: Double

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: max(4, geo.size.width * CGFloat(min(max(ratio, 0), 1))))
            }
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(index < 3 ? Theme.accent : Theme.dim)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(main)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if let sub = sub, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Text(count)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.text)
                    .monospacedDigit()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .frame(height: 36)
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
