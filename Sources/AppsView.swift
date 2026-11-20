import SwiftUI
import UIKit

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
    /// 优先尝试的 App 深链（能打开就跳 App，打不开退回网页）
    var schemes: [String] = []
    var tag: String = "外部服务"
}

struct AppsView: View {
    @EnvironmentObject var m: AppModel

    private var base: String { NetmonAPI.hostBase }

    // MARK: 可打开的应用（与网页 APPS 一致 + /api/apps 自定义，按 URL/名称去重）

    private var openable: [OpenableApp] {
        var list: [OpenableApp] = [
            OpenableApp(id: "ha", name: "Home Assistant", desc: "智能家居 · 自动化",
                        url: base.hasSuffix(":8123") ? base : "\(base):8123",
                        symbol: "house", colors: [Theme.pink, Theme.red],
                        schemes: ["homeassistant://"]),
            OpenableApp(id: "ntopng", name: "ntopng", desc: "网络流量分析",
                        url: "\(base):3000", symbol: "waveform.path.ecg", colors: [Theme.green, Theme.cyan]),
            OpenableApp(id: "homebox", name: "homebox 测速", desc: "内网带宽测速",
                        url: "\(base):3300", symbol: "bolt", colors: [Theme.amber, Theme.orange]),
            OpenableApp(id: "adguard", name: "AdGuard Home", desc: "DNS 广告拦截",
                        url: "\(base):8081", symbol: "shield", colors: [Theme.purple, Theme.accent]),
            OpenableApp(id: "netmon", name: "网络监控", desc: "本监控系统 · 实时",
                        url: base, symbol: "dot.radiowaves.left.and.right",
                        colors: [Theme.cyan, Theme.accent], tag: "本系统")
        ]
        for a in m.storeApps {
            let nm = a.name
            let lower = nm.lowercased()
            var schemes: [String] = []
            if lower.contains("home assistant") || lower == "ha" { schemes = ["homeassistant://"] }
            if lower.contains("飞牛") || lower.contains("fnos") || lower.contains("feiniu") {
                schemes = ["fnos://", "feiniu://"]
            }
            let app = OpenableApp(id: a.id, name: nm,
                                  desc: (a.desc?.isEmpty == false ? a.desc! : "自定义入口"),
                                  url: a.url, symbol: "square.grid.2x2",
                                  colors: [Theme.amber, Theme.pink],
                                  schemes: schemes, tag: "自定义")
            if !isDuplicate(app, in: list) { list.append(app) }
        }
        return list
    }

    private func normKey(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    private func isDuplicate(_ app: OpenableApp, in list: [OpenableApp]) -> Bool {
        let uk = normKey(app.url)
        let nk = app.name.lowercased().replacingOccurrences(of: " ", with: "")
        return list.contains { exist in
            let euk = normKey(exist.url)
            let enk = exist.name.lowercased().replacingOccurrences(of: " ", with: "")
            return (!uk.isEmpty && uk == euk) || nk == enk
        }
    }

    // MARK: 后台服务（与网页 APPS 的 svc 定义一致：MySQL / Redis / dnsmasq / WireGuard）

    private struct SvcDef {
        let id: String
        let name: String
        let desc: String
        let port: String
    }

    private let svcDefs: [SvcDef] = [
        SvcDef(id: "mysql", name: "MySQL 5.7", desc: "关系型数据库", port: "3306"),
        SvcDef(id: "redis", name: "Redis 7", desc: "内存缓存", port: "6379"),
        SvcDef(id: "dnsmasq", name: "dnsmasq", desc: "局域网 DHCP", port: "67"),
        SvcDef(id: "wg", name: "WireGuard", desc: "外网 VPN · wg0", port: "")
    ]

    private struct SvcRow: Identifiable {
        let id: String
        let name: String
        let desc: String
        let running: Bool
        let cpu: String
        let mem: String
    }

    private var serviceRows: [SvcRow] {
        svcDefs.map { def in
            let live = m.services.first { $0.sid == def.id }
            let stat = m.apps?.data.services[def.id] ?? matchContainer(def.name)
            let p = def.port.isEmpty ? "" : " · \(def.port)"
            return SvcRow(id: def.id,
                          name: def.name,
                          desc: def.desc + p,
                          running: live?.running ?? false,
                          cpu: stat?.cpu ?? "—",
                          mem: stat?.mem_pct ?? "—")
        }
    }

    /// 网页 amFindCtr 的等价：先去符号比对容器名，再模糊包含
    private func matchContainer(_ name: String) -> AppStat? {
        let ctr = m.apps?.data.containers ?? [:]
        guard !ctr.isEmpty else { return nil }
        func norm(_ s: String) -> String {
            s.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let k = norm(name)
        var exact: String?
        var fuzzy: String?
        var fuzzyAny: String?
        for key in ctr.keys {
            let n = norm(key)
            let running = (ctr[key]?.state ?? "running") == "running"
            if n == k { if exact == nil { exact = key } }
            else if !n.isEmpty && !k.isEmpty && (n.contains(k) || k.contains(n)) {
                if running && fuzzy == nil { fuzzy = key } else if fuzzyAny == nil { fuzzyAny = key }
            }
        }
        if let key = exact ?? fuzzy ?? fuzzyAny { return ctr[key] }
        return nil
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(
                    title: "应用",
                    subtitle: "应用 \(openable.count) 个 · 服务 \(serviceRows.count) 个",
                    onRefresh: { Task { await m.refreshAll() } },
                    refreshing: m.isRefreshing
                )

                sectionTitle("可打开的应用", note: "点击进入")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(openable) { app in
                        Button { launch(app) } label: {
                            OpenAppCard(app: app)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                sectionTitle("后台服务", note: "仅显示运行状态")
                VStack(spacing: 0) {
                    ForEach(Array(serviceRows.enumerated()), id: \.element.id) { item in
                        serviceRow(item.element)
                        if item.offset < serviceRows.count - 1 {
                            Rectangle().fill(Theme.hair).frame(height: 1).padding(.leading, 14)
                        }
                    }
                }
                .glassPanel(radius: Theme.radius)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackground())
    }

    private func sectionTitle(_ text: String, note: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(note)
                .font(.system(size: 10.5))
                .foregroundColor(Theme.dim)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func serviceRow(_ row: SvcRow) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(row.running ? Theme.green : Theme.red)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(row.desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(row.running ? "运行中" : "已停止")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(row.running ? Theme.green : Theme.red)
            Text(row.cpu)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(Theme.sub)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
            Text(row.mem)
                .font(.system(size: 10.5))
                .foregroundColor(Theme.dim)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: 打开：先试 App 深链，失败退回网页

    private func launch(_ app: OpenableApp) {
        let schemeURLs = app.schemes.compactMap { URL(string: $0) }
        AppsView.tryOpen(schemeURLs, fallback: URL(string: app.url))
    }

    private static func tryOpen(_ links: [URL], fallback: URL?) {
        guard let first = links.first else {
            if let f = fallback { UIApplication.shared.open(f, options: [:], completionHandler: nil) }
            return
        }
        UIApplication.shared.open(first, options: [:]) { ok in
            if !ok { AppsView.tryOpen(Array(links.dropFirst()), fallback: fallback) }
        }
    }
}

// MARK: - 可打开的应用卡（图标 + 名称 + 描述 + 标签）

struct OpenAppCard: View {
    let app: OpenableApp

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: app.symbol)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(app.desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            PulseChip(text: app.tag, tint: Theme.accent)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: Theme.radius)
    }
}
