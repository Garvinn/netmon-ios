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

    private let tight = [GridItem(.adaptive(minimum: 152), spacing: 9)]

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    header
                    networkCard

                    LazyVGrid(columns: tight, spacing: 9) {
                        statusCard
                        loadCard
                        diskCard
                        dioCard
                        abnCard
                        abnormalCard
                        blacklistCard
                        procsCard
                    }

                    sectionHeader
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 9)], spacing: 9) {
                        ipRankCard
                        portRankCard
                    }

                    if let err = m.lastError {
                        errorBar(err)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 26)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
        }
        .sheet(isPresented: $bigChart) {
            BigChartSheet(points: history)
        }
    }

    // MARK: 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeader(
                title: "网络监控",
                subtitle: "外网 \(snap?.wan_ip ?? "--") · \(Fmt.time(snap?.time ?? 0))",
                onRefresh: { Task { await m.refreshAll() } },
                refreshing: m.isRefreshing
            )
            HStack(spacing: 6) {
                PulseChip(text: "\(online)/\(totalDev) 在线", tint: Theme.green)
                PulseChip(text: "CPU \(String(format: "%.0f", cpuPct))%", tint: Theme.accent)
                PulseChip(text: "MEM \(String(format: "%.0f", memPct))%", tint: Theme.purple)
                Spacer(minLength: 2)
                Text(snap?.wan_ip ?? "")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    // MARK: 网络（整行）

    private var networkCard: some View {
        PulseCard(icon: "network", title: "网络",
                  accent: Theme.blue,
                  status: "峰值 " + Fmt.rate(peak)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    netTile(arrow: "arrow.down", label: "下载", tint: Theme.blue,
                            value: Fmt.rateValue(downBytes), unit: Fmt.rateUnit(downBytes))
                    netTile(arrow: "arrow.up", label: "上传", tint: Theme.purple,
                            value: Fmt.rateValue(upBytes), unit: Fmt.rateUnit(upBytes))
                }
                TrendChart(points: history, height: 118)
                HStack(spacing: 10) {
                    ChartLegend()
                    Spacer()
                    Text("近 2 小时 · 10 秒采样")
                        .font(.system(size: 9.5))
                        .foregroundColor(Theme.dim)
                }
            }
        }
        .onTapGesture { bigChart = true }
    }

    private func netTile(arrow: String, label: String, tint: Color, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: arrow)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(tint)
                PulseLabel(text: label, tint: tint)
            }
            PulseValue(value: value, unit: unit, tint: tint, size: 19, leading: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.08)))
    }

    // MARK: 节点状态

    private var statusCard: some View {
        PulseCard(icon: "bolt.horizontal.fill", title: "节点",
                  accent: Theme.blue, status: online > 0 ? "在线" : "离线",
                  statusOK: online > 0) {
            VStack(alignment: .leading, spacing: 4) {
                PulseLabel(text: "在线设备")
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    PulseValue(value: "\(online)", unit: "台", size: 22, leading: true)
                    Spacer(minLength: 0)
                    Text("\(totalDev)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.dim)
                }
                Text("共发现 \(totalDev) 台")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    // MARK: 资源负载

    private var loadCard: some View {
        PulseCard(icon: "cpu", title: "负载",
                  accent: Theme.cyan,
                  status: cpuPct > 85 ? "偏高" : "正常",
                  statusOK: cpuPct <= 85) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        PulseLabel(text: "CPU")
                        PulseValue(value: String(format: "%.0f", cpuPct), unit: "%", size: 19, leading: true)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        PulseLabel(text: "MEM")
                        PulseValue(value: String(format: "%.0f", memPct), unit: "%", tint: Theme.purple, size: 19, leading: true)
                    }
                    Spacer(minLength: 0)
                }
                VStack(spacing: 4) {
                    MiniProgress(value: cpuPct / 100, tint: Theme.accent, height: 3)
                    MiniProgress(value: memPct / 100, tint: Theme.purple, height: 3)
                }
                HStack(spacing: 4) {
                    Text(loadNums.isEmpty ? "LOAD --" : "LOAD " + loadNums)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.sub)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(tempText)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(Theme.dim)
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

    // MARK: 存储

    private var diskCard: some View {
        PulseCard(icon: "internaldrive.fill", title: "存储",
                  accent: Theme.cyan,
                  status: diskSub.isEmpty ? nil : diskSub) {
            VStack(spacing: 7) {
                let disks = host?.disks ?? []
                if disks.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(disks.prefix(3))) { d in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(d.mount)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Text(String(format: "%.0f%%", d.percent))
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(d.percent > 85 ? Theme.red : Theme.text)
                            }
                            MiniProgress(value: d.percent / 100,
                                         tint: d.percent > 85 ? Theme.red : Theme.accent,
                                         height: 3)
                            Text(Fmt.size(d.used) + " / " + Fmt.size(d.total))
                                .font(.system(size: 9))
                                .foregroundColor(Theme.dim)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var diskSub: String {
        let total = (host?.disks ?? []).reduce(0.0) { $0 + $1.total }
        return total > 0 ? Fmt.size(total) : ""
    }

    // MARK: 磁盘 IO

    private var dioCard: some View {
        PulseCard(icon: "externaldrive.badge.timemachine", title: "磁盘 IO", accent: Theme.purple) {
            VStack(spacing: 5) {
                ioCell("读", Fmt.rate(host?.dio?.read ?? 0), Theme.blue)
                ioCell("写", Fmt.rate(host?.dio?.write ?? 0), Theme.purple)
                HStack(spacing: 4) {
                    Text("累计 " + Fmt.size(host?.dio?.read_total ?? 0))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                    Text(" / " + Fmt.size(host?.dio?.write_total ?? 0))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }
        }
    }

    private func ioCell(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(Theme.dim)
                .frame(width: 12, alignment: .leading)
            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fillSoft.opacity(0.7)))
    }

    // MARK: 异常拦截

    private var abnCard: some View {
        PulseCard(icon: "shield.lefthalf.filled", title: "拦截",
                  accent: Theme.red,
                  status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(alignment: .leading, spacing: 5) {
                PulseValue(value: Fmt.count(abnTotal), unit: "次", tint: Theme.red, size: 20, leading: true)
                HStack(spacing: 4) {
                    PulseChip(text: "IP \(m.abn?.ips.count ?? 0)", tint: Theme.orange)
                    PulseChip(text: "端口 \(m.abn?.ports.count ?? 0)", tint: Theme.red)
                }
                Sparkline(values: history.map { $0.abn ?? 0 }, tint: Theme.red, height: 26)
            }
        }
    }

    // MARK: 异常连接

    private var abnormalCard: some View {
        PulseCard(icon: "exclamationmark.triangle.fill", title: "异常连接",
                  accent: Theme.orange, status: "24H", statusOK: false) {
            VStack(spacing: 0) {
                if m.abnLogs.isEmpty {
                    emptyLine("暂无记录")
                } else {
                    ForEach(Array(m.abnLogs.prefix(3))) { log in
                        miniRow(title: log.src, right: Fmt.time(log.t))
                    }
                }
            }
        }
    }

    // MARK: 黑名单

    private var blacklistCard: some View {
        PulseCard(icon: "hand.raised.fill", title: "黑名单",
                  accent: Theme.pink, status: "\(m.blacklist.count)") {
            VStack(spacing: 0) {
                if m.blacklist.isEmpty {
                    emptyLine("暂无")
                } else {
                    ForEach(Array(m.blacklist.prefix(3))) { b in
                        miniRow(title: b.ip, right: b.cc ?? b.geo ?? "")
                    }
                }
            }
        }
    }

    // MARK: 系统负载

    private var procsCard: some View {
        PulseCard(icon: "list.bullet.rectangle", title: "进程",
                  accent: Theme.green, status: loadNums.isEmpty ? nil : "LOAD") {
            VStack(spacing: 0) {
                let procs = sys?.procs ?? []
                if procs.isEmpty {
                    emptyLine("暂无")
                } else {
                    ForEach(Array(procs.prefix(3))) { p in
                        miniRow(title: p.name,
                                right: String(format: "%.0f%%/%.0fM", p.cpu, p.mem_mb))
                    }
                }
            }
        }
    }

    // MARK: 通用小行

    private func miniRow(title: String, right: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 3)
            Text(right)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    // MARK: 排行

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("外网访问与扫描")
                .font(.system(size: 11.5, weight: .semibold))
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
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Theme.sub)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            }
        }
        .padding(.top, 4)
    }

    private var ipRankCard: some View {
        PulseCard(icon: "globe.asia.australia.fill", title: "来源 IP",
                  accent: Theme.orange, status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(spacing: 1) {
                let ips = m.abn?.ips ?? []
                if ips.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ips.prefix(6))) { ip in
                        PulseRankRow(index: ips.firstIndex(where: { $0.id == ip.id }) ?? 0,
                                     main: ip.ip, sub: geoText(ip),
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
            VStack(spacing: 1) {
                let ports = m.abn?.ports ?? []
                if ports.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ports.prefix(6).enumerated()), id: \.element.id) { item in
                        PulseRankRow(index: item.offset, main: item.element.port, sub: portSub(item.element),
                                     count: Fmt.count(item.element.cnt), ratio: item.element.pct / 100)
                    }
                }
            }
        }
    }

    private var abnWindowText: String {
        guard let w = m.abn?.win else { return "" }
        return "\(Int(w / 3600))h"
    }

    private func portSub(_ p: TopPort) -> String {
        var parts: [String] = []
        if let s = p.svc, !s.isEmpty { parts.append(s) }
        if let srcs = p.srcs { parts.append("\(Int(srcs)) 源") }
        return parts.joined(separator: " · ")
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.orange)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Theme.sub)
                .lineLimit(2)
            Spacer()
        }
        .padding(8)
        .glassPanel(radius: 10)
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
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: max(3, geo.size.width * CGFloat(min(max(ratio, 0), 1))))
            }
            HStack(spacing: 6) {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(index < 3 ? Theme.accent : Theme.dim)
                    .frame(width: 13)
                VStack(alignment: .leading, spacing: 0) {
                    Text(main)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if let sub = sub, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(count)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Theme.text)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
        .frame(height: 29)
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
