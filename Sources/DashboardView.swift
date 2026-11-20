import SwiftUI

// MARK: - 通用页头

struct PageHeader: View {
    let title: String
    var subtitle: String? = nil
    var refreshing: Bool = false
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let onRefresh {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.sub)
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: refreshing)
                        .padding(9)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                        .overlay(Circle().stroke(Theme.stroke, lineWidth: 0.6))
                }
            }
        }
        .padding(.top, 6)
    }
}

struct DashboardView: View {
    @EnvironmentObject var m: AppModel

    private var subtitle: String {
        var parts: [String] = []
        if let ip = m.snap?.wan_ip, !ip.isEmpty { parts.append("外网 \(ip)") }
        if let t = m.snap?.time { parts.append("采样 \(Fmt.time(t))") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    PageHeader(title: "网络监控", subtitle: subtitle, refreshing: m.isRefreshing) {
                        Task { await m.refreshAll() }
                    }

                    statusStrip

                    HStack(spacing: 10) {
                        StatTile(title: "下行", value: Fmt.rateValue(m.snap?.total_down ?? 0),
                                 unit: Fmt.rateUnit(m.snap?.total_down ?? 0), tint: Theme.cyan, icon: "arrow.down")
                        StatTile(title: "上行", value: Fmt.rateValue(m.snap?.total_up ?? 0),
                                 unit: Fmt.rateUnit(m.snap?.total_up ?? 0), tint: Theme.purple, icon: "arrow.up")
                    }

                    HStack(spacing: 10) {
                        StatTile(title: "CPU", value: String(format: "%.1f", m.sys?.cpu_percent ?? 0),
                                 unit: "%", tint: Theme.amber, icon: "cpu")
                        StatTile(title: "内存", value: String(format: "%.0f", m.sys?.mem_percent ?? 0),
                                 unit: "%", tint: Theme.green, icon: "memorychip")
                    }

                    trendCard
                    rankCard
                    footer
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
            }
        }
    }

    // 在线 / 设备 / 负载
    private var statusStrip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Dot(on: true)
                Text("\(m.snap?.online ?? 0) 在线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.green)
            }
            Text("·").foregroundColor(Theme.dim).font(.system(size: 11))
            Text("共 \(m.snap?.total ?? 0) 台设备")
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
            Spacer()
            if let load = m.sys?.load.first {
                Text("负载 \(String(format: "%.2f", load))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Theme.dim)
            }
            if let up = m.updatedAt {
                Text(Fmt.time(up.timeIntervalSince1970 * 1000))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke.opacity(0.6), lineWidth: 0.5))
    }

    private var trendCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                CardTitle(text: "近 2 小时趋势", icon: "chart.bar")
                if let hist = m.snap?.history, hist.count > 1 {
                    TrendChart(points: hist)
                } else {
                    Text("正在采集数据…")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 108)
                }
            }
        }
    }

    private var rankCard: some View {
        VStack(spacing: 12) {
            HStack {
                CardTitle(text: "外网访问与扫描", icon: "shield")
                Picker("", selection: Binding(
                    get: { m.rankRange },
                    set: { m.setRange($0) }
                )) {
                    Text("24 小时").tag("1")
                    Text("7 天").tag("7")
                    Text("30 天").tag("30")
                    Text("全部").tag("all")
                }
                .pickerStyle(.menu)
                .accentColor(Theme.accent)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("来源 IP 排名")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.sub)
                        Spacer()
                        Text("共 \(Fmt.count(m.abn?.total ?? 0)) 次")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.dim)
                    }
                    if let ips = m.abn?.ips, !ips.isEmpty {
                        let maxPct = max(ips.map { $0.pct }.max() ?? 1, 0.1)
                        ForEach(ips.prefix(6)) { ip in
                            RankRow(
                                title: ip.ip,
                                subtitle: [ip.geo, ip.cc].compactMap { $0 }.joined(separator: " · "),
                                valueText: "\(Fmt.count(ip.cnt)) 次",
                                fraction: ip.pct / maxPct,
                                tint: Theme.red,
                                trailing: Fmt.pct(ip.pct)
                            )
                        }
                    } else {
                        Text("暂无数据").font(.system(size: 12)).foregroundColor(Theme.dim)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("被扫描端口排名")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.sub)
                    if let ports = m.abn?.ports, !ports.isEmpty {
                        let maxPct = max(ports.map { $0.pct }.max() ?? 1, 0.1)
                        ForEach(ports.prefix(6)) { p in
                            RankRow(
                                title: "\(p.port)\(p.svc.map { $0.isEmpty ? "" : "  \($0)" } ?? "")",
                                subtitle: p.srcs.map { "\(Int($0)) 个来源 IP" },
                                valueText: "\(Fmt.count(p.cnt)) 次",
                                fraction: p.pct / maxPct,
                                tint: Theme.amber
                            )
                        }
                    } else {
                        Text("暂无数据").font(.system(size: 12)).foregroundColor(Theme.dim)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let err = m.lastError {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.amber)
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.amber)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.10)))
        }
    }
}
