import SwiftUI

struct NamedStat: Identifiable {
    var id: String { name }
    let name: String
    let stat: AppStat
}

struct OpenableApp: Identifiable {
    let id: String
    let name: String
    let desc: String
    let url: String
    let symbol: String
    let colors: [Color]
}

struct AppsView: View {
    @EnvironmentObject var m: AppModel
    @Environment(\.openURL) private var openURL

    private var base: String { NetmonAPI.hostBase }

    /// 可打开的应用（与网页 APPS 保持一致 + /api/apps 自定义入口）
    private var openable: [OpenableApp] {
        var list: [OpenableApp] = [
            OpenableApp(id: "ha", name: "Home Assistant", desc: "智能家居 · 自动化",
                        url: base.hasSuffix(":8123") ? base : "\(base):8123",
                        symbol: "house", colors: [Theme.pink, Theme.red]),
            OpenableApp(id: "ntopng", name: "ntopng", desc: "网络流量分析",
                        url: "\(base):3000", symbol: "waveform.path.ecg", colors: [Theme.green, Theme.cyan]),
            OpenableApp(id: "homebox", name: "homebox 测速", desc: "内网带宽测速",
                        url: "\(base):3300", symbol: "bolt", colors: [Theme.amber, Theme.orange]),
            OpenableApp(id: "adguard", name: "AdGuard Home", desc: "DNS 广告拦截",
                        url: "\(base):8081", symbol: "shield", colors: [Theme.purple, Theme.accent]),
            OpenableApp(id: "netmon", name: "网络监控", desc: "本监控系统 · 实时",
                        url: base, symbol: "dot.radiowaves.left.and.right", colors: [Theme.cyan, Theme.accent])
        ]
        for a in m.storeApps {
            list.append(OpenableApp(id: a.id, name: a.name,
                                    desc: (a.desc?.isEmpty == false ? a.desc! : "自定义入口"),
                                    url: a.url, symbol: "square.grid.2x2", colors: [Theme.amber, Theme.pink]))
        }
        return list
    }

    private var services: [NamedStat] {
        (m.apps?.data.services ?? [:])
            .map { NamedStat(name: $0.key, stat: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var containers: [NamedStat] {
        (m.apps?.data.containers ?? [:])
            .map { NamedStat(name: $0.key, stat: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    title: "应用",
                    subtitle: "应用 \(openable.count) 个 · 容器 \(containers.count) 个 · 服务 \(services.count) 个",
                    onRefresh: { Task { await m.refreshAll() } },
                    refreshing: m.isRefreshing
                )

                sectionTitle("可打开的应用", count: openable.count)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    ForEach(openable) { app in
                        Button {
                            if let u = URL(string: app.url) {
                                openURL(u)
                            }
                        } label: {
                            OpenAppCard(app: app)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if !services.isEmpty {
                    sectionTitle("系统服务", count: services.count)
                    serviceList
                }

                if !containers.isEmpty {
                    sectionTitle("容器", count: containers.count)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                        ForEach(containers) { item in
                            AppMetricCard(name: item.name, stat: item.stat, tag: "容器", tint: Theme.purple)
                        }
                    }
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

    private func sectionTitle(_ text: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
            Spacer()
        }
        .padding(.top, 2)
    }

    private var serviceList: some View {
        VStack(spacing: 0) {
            ForEach(Array(serviceRows.indices), id: \.self) { i in
                let row = serviceRows[i]
                if let urlStr = row.url, let url = URL(string: urlStr) {
                    Button { openURL(url) } label: {
                        serviceRow(row, clickable: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    serviceRow(row, clickable: false)
                }
                Rectangle().fill(Theme.hair).frame(height: 1)
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private struct ServiceRow {
        var id: String
        var name: String
        var desc: String
        var running: Bool
        var url: String?
        var cpu: String
        var mem: String
    }

    private var serviceRows: [ServiceRow] {
        m.services.map { s in
            let stat = m.apps?.data.services[s.sid]
            return ServiceRow(
                id: s.sid,
                name: s.name,
                desc: (s.desc ?? ""),
                running: s.running,
                url: webURL(port: s.port ?? "", type: s.type ?? ""),
                cpu: stat?.cpu ?? "—",
                mem: stat?.mem ?? "—"
            )
        }
    }

    /// 只把真正的 Web 端口当作可打开（数据库、UDP 端口不跳转）
    private func webURL(port: String, type: String) -> String? {
        let digits = port.filter { $0.isNumber }
        guard let p = Int(digits), p > 0, p < 10000 else { return nil }
        let blocked: Set<Int> = [3306, 6379, 5432, 27017, 67, 53, 22]
        if blocked.contains(p) { return nil }
        return "\(base):\(p)"
    }

    private func serviceRow(_ row: ServiceRow, clickable: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(row.running ? Theme.green : Theme.red)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if clickable {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                    }
                }
                Text(row.desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(row.cpu)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.sub)
                .monospacedDigit()
            Text(row.mem)
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
                .monospacedDigit()
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - 可打开的应用卡（图标 + 名称 + 描述 + 标签）

struct OpenAppCard: View {
    let app: OpenableApp

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: app.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(app.desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(Theme.dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - 容器指标卡

struct AppMetricCard: View {
    let name: String
    let stat: AppStat
    var tag: String = "容器"
    var tint: Color = Theme.purple

    private var memText: String {
        var parts: [String] = []
        if let p = stat.mem_pct, let v = Double(p), v > 0 {
            parts.append(String(format: "%.1f%%", v))
        }
        if let mem = stat.mem, let first = mem.split(separator: "/").first {
            let trimmed = first.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { parts.append(trimmed) }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private var storeText: String {
        if let store = stat.store, !store.isEmpty { return store }
        if let rw = stat.rw, !rw.isEmpty { return rw }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(stat.running ? Theme.green : Theme.red)
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Tag(text: tag, tint: tint)
            }

            Rectangle().fill(Theme.hair).frame(height: 1)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      alignment: .leading, spacing: 8) {
                metricCell("运行", stat.up_text ?? "—")
                metricCell("CPU", stat.cpu ?? "—")
                metricCell("内存", memText)
                metricCell("存储", storeText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    private func metricCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.dim)
                .tracking(0.4)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(value == "—" ? Theme.dim : Theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
