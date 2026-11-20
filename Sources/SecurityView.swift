import SwiftUI

struct SecurityView: View {
    @EnvironmentObject var m: AppModel

    private var abn: AbnTop? { m.abn }
    private var total: Double { abn?.total ?? 0 }

    private let ranges: [(key: String, label: String)] = [
        ("1", "24 小时"), ("7", "7 天"), ("30", "30 天"), ("all", "1 年")
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                PageHeader(
                    title: "安全",
                    subtitle: "外网扫描与异常拦截 · \(Fmt.rangeLabel(m.rankRange))",
                    onRefresh: { Task { await m.loadRank() } },
                    refreshing: m.rankLoading
                )

                rangeBar

                content
                    .opacity(m.rankLoading ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.25), value: m.rankLoading)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackground())
        .overlay {
            if m.rankLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)
                    Text("正在统计…")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Theme.sub)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassPanel(radius: 20)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: m.rankLoading)
    }

    // MARK: 统一时间切换

    private var rangeBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(ranges.enumerated()), id: \.offset) { item in
                let r = item.element
                let active = m.rankRange == r.key
                Button {
                    guard m.rankRange != r.key else { return }
                    m.setRange(r.key)
                } label: {
                    Text(r.label)
                        .font(.system(size: 11.5, weight: active ? .semibold : .regular))
                        .foregroundColor(active ? .white : Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(active ? Theme.accent : Color.clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .glassPanel(radius: 22)
    }

    // MARK: 内容

    private var content: some View {
        VStack(alignment: .leading, spacing: 9) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 152), spacing: 9)], spacing: 9) {
                totalCard
                sourceCard
                portCard
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 9)], spacing: 9) {
                ipRankCard
                portRankCard
            }

            abnormalCard
            blacklistCard
        }
    }

    private var totalCard: some View {
        PulseCard(icon: "shield.lefthalf.filled", title: "拦截",
                  accent: Theme.red, status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(alignment: .leading, spacing: 4) {
                PulseLabel(text: "拦截次数")
                PulseValue(value: Fmt.count(total), unit: "次", tint: Theme.red, size: 24, leading: true)
                Text(windowText)
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    private var windowText: String {
        guard let w = abn?.win, w > 0 else { return "统计窗口：\(Fmt.rangeLabel(m.rankRange))" }
        if w >= 86400 { return "统计窗口：\(Int(w / 86400)) 天" }
        return "统计窗口：\(Int(w / 3600)) 小时"
    }

    private var sourceCard: some View {
        PulseCard(icon: "globe.asia.australia.fill", title: "来源", accent: Theme.orange) {
            VStack(alignment: .leading, spacing: 4) {
                PulseLabel(text: "来源 IP")
                PulseValue(value: "\(abn?.ips.count ?? 0)", unit: "个", tint: Theme.orange, size: 24, leading: true)
                Text(topSourceText)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    private var topSourceText: String {
        guard let first = abn?.ips.first else { return "暂无记录" }
        return "最高 \(first.ip) · \(Fmt.count(first.cnt)) 次"
    }

    private var portCard: some View {
        PulseCard(icon: "network", title: "端口", accent: Theme.green) {
            VStack(alignment: .leading, spacing: 4) {
                PulseLabel(text: "扫描端口")
                PulseValue(value: "\(abn?.ports.count ?? 0)", unit: "个", tint: Theme.green, size: 24, leading: true)
                Text(topPortText)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    private var topPortText: String {
        guard let first = abn?.ports.first else { return "暂无记录" }
        return "最高 \(first.port) · \(Fmt.count(first.cnt)) 次"
    }

    // MARK: 排行

    private var ipRankCard: some View {
        PulseCard(icon: "globe.asia.australia.fill", title: "来源 IP",
                  accent: Theme.orange, status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            VStack(spacing: 1) {
                let ips = abn?.ips ?? []
                if ips.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ips.prefix(10).enumerated()), id: \.element.id) { item in
                        PulseRankRow(index: item.offset,
                                     main: item.element.ip,
                                     sub: geoText(item.element),
                                     count: Fmt.count(item.element.cnt),
                                     ratio: item.element.pct / 100)
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
                  accent: Theme.green, status: windowText, statusOK: false) {
            VStack(spacing: 1) {
                let ports = abn?.ports ?? []
                if ports.isEmpty {
                    emptyLine("暂无数据")
                } else {
                    ForEach(Array(ports.prefix(10).enumerated()), id: \.element.id) { item in
                        PulseRankRow(index: item.offset,
                                     main: item.element.port,
                                     sub: portSub(item.element),
                                     count: Fmt.count(item.element.cnt),
                                     ratio: item.element.pct / 100)
                    }
                }
            }
        }
    }

    private func portSub(_ p: TopPort) -> String {
        var parts: [String] = []
        if let s = p.svc, !s.isEmpty { parts.append(s) }
        if let srcs = p.srcs { parts.append("\(Int(srcs)) 源") }
        return parts.joined(separator: " · ")
    }

    // MARK: 异常连接 / 黑名单

    private var abnormalCard: some View {
        PulseCard(icon: "exclamationmark.triangle.fill", title: "异常连接",
                  accent: Theme.orange, status: "\(m.abnLogs.count) 条", statusOK: false) {
            VStack(spacing: 0) {
                if m.abnLogs.isEmpty {
                    emptyLine("暂无异常记录")
                } else {
                    ForEach(Array(m.abnLogs.prefix(12))) { log in
                        HStack(spacing: 6) {
                            Text(Fmt.time(log.t))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(Theme.dim)
                                .frame(width: 54, alignment: .leading)
                            Text(log.src)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.text)
                                .lineLimit(1)
                            if let kind = log.kind, !kind.isEmpty {
                                PulseChip(text: kind, tint: Theme.orange)
                            }
                            Spacer(minLength: 2)
                            Text(detailText(log))
                                .font(.system(size: 9.5))
                                .foregroundColor(Theme.dim)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 5)
                        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
                    }
                }
            }
        }
    }

    private func detailText(_ log: AbnLog) -> String {
        var parts: [String] = []
        if let g = log.geo, !g.isEmpty { parts.append(g) }
        if let d = log.dst, !d.isEmpty { parts.append(d) }
        return parts.joined(separator: " · ")
    }

    private var blacklistCard: some View {
        PulseCard(icon: "hand.raised.fill", title: "黑名单",
                  accent: Theme.pink, status: "\(m.blacklist.count) 个 IP") {
            VStack(spacing: 0) {
                if m.blacklist.isEmpty {
                    emptyLine("暂无黑名单")
                } else {
                    ForEach(Array(m.blacklist.prefix(14))) { b in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.pink.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(b.ip)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.text)
                                .lineLimit(1)
                            Spacer(minLength: 3)
                            Text([b.cc, b.geo].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 9.5))
                                .foregroundColor(Theme.dim)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 5)
                        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
                    }
                }
            }
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
}

// MARK: - 排行行

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
