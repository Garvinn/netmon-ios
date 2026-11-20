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
    /// 用于匹配容器 / 系统服务的名字
    var matchKey: String = ""
}

struct AppsView: View {
    @EnvironmentObject var m: AppModel

    private var base: String { NetmonAPI.hostBase }

    // MARK: 可打开的应用

    private var openable: [OpenableApp] {
        var list: [OpenableApp] = [
            OpenableApp(id: "ha", name: "Home Assistant", desc: "智能家居 · 自动化",
                        url: base.hasSuffix(":8123") ? base : "\(base):8123",
                        symbol: "house.fill", colors: [Theme.pink, Theme.red],
                        schemes: ["homeassistant://"], matchKey: "homeassistant"),
            OpenableApp(id: "ntopng", name: "ntopng", desc: "网络流量分析",
                        url: "\(base):3000", symbol: "waveform.path.ecg",
                        colors: [Theme.green, Theme.cyan], matchKey: "ntopng"),
            OpenableApp(id: "homebox", name: "homebox 测速", desc: "内网带宽测速",
                        url: "\(base):3300", symbol: "bolt.fill",
                        colors: [Theme.amber, Theme.orange], matchKey: "homebox"),
            OpenableApp(id: "adguard", name: "AdGuard Home", desc: "DNS 广告拦截",
                        url: "\(base):8081", symbol: "shield.fill",
                        colors: [Theme.purple, Theme.accent], matchKey: "adguard"),
            OpenableApp(id: "netmon", name: "网络监控", desc: "本监控系统 · 实时",
                        url: base, symbol: "dot.radiowaves.left.and.right",
                        colors: [Theme.cyan, Theme.accent], tag: "本系统", matchKey: "netmon")
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
                                  url: a.url, symbol: "square.grid.2x2.fill",
                                  colors: [Theme.amber, Theme.pink],
                                  schemes: schemes, tag: "自定义", matchKey: nm)
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

    // MARK: 后台服务

    private struct SvcDef {
        let id: String
        let name: String
        let desc: String
        let port: String
        let symbol: String
    }

    private let svcDefs: [SvcDef] = [
        SvcDef(id: "mysql", name: "MySQL 5.7", desc: "关系型数据库", port: "3306", symbol: "cylinder.split.1x2"),
        SvcDef(id: "redis", name: "Redis 7", desc: "内存缓存", port: "6379", symbol: "bolt.horizontal.circle"),
        SvcDef(id: "dnsmasq", name: "dnsmasq", desc: "局域网 DHCP / DNS", port: "67", symbol: "network"),
        SvcDef(id: "wg", name: "WireGuard", desc: "外网 VPN · wg0", port: "", symbol: "lock.shield")
    ]

    private func serviceStat(_ def: SvcDef) -> AppStat? {
        m.apps?.data.services[def.id] ?? matchContainer(def.name)
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

    private func appStat(_ app: OpenableApp) -> AppStat? {
        if let st = m.apps?.data.services[app.matchKey] { return st }
        return matchContainer(app.matchKey.isEmpty ? app.name : app.matchKey)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(
                    title: "应用",
                    subtitle: "应用 \(openable.count) 个 · 服务 \(svcDefs.count) 个",
                    onRefresh: { Task { await m.refreshAll() } },
                    refreshing: m.isRefreshing
                )

                sectionTitle("可打开的应用", note: "点击进入")
                VStack(spacing: 0) {
                    ForEach(Array(openable.enumerated()), id: \.element.id) { item in
                        let app = item.element
                        let st = appStat(app)
                        Button { launch(app) } label: {
                            AppRow(icon: app.symbol, colors: app.colors, name: app.name, desc: app.desc,
                                   running: isRunning(st), upText: st?.up_text, cpu: st?.cpu,
                                   storage: storageText(st), mem: st?.mem, tag: app.tag, canOpen: true)
                        }
                        .buttonStyle(.plain)
                        if item.offset < openable.count - 1 {
                            Rectangle().fill(Theme.hair).frame(height: 1).padding(.leading, 62)
                        }
                    }
                }
                .glassPanel(radius: Theme.radius)

                sectionTitle("后台服务", note: "运行状态 · 时长 · 存储 · 内存")
                VStack(spacing: 0) {
                    ForEach(Array(svcDefs.enumerated()), id: \.element.id) { item in
                        let def = item.element
                        let st = serviceStat(def)
                        let live = m.services.first { $0.sid == def.id }
                        AppRow(icon: def.symbol, colors: [Theme.sub, Theme.dim],
                               name: def.name,
                               desc: def.desc + (def.port.isEmpty ? "" : " · 端口 \(def.port)"),
                               running: live?.running ?? isRunning(st),
                               upText: st?.up_text, cpu: st?.cpu,
                               storage: storageText(st), mem: st?.mem,
                               tag: "服务", canOpen: false)
                        if item.offset < svcDefs.count - 1 {
                            Rectangle().fill(Theme.hair).frame(height: 1).padding(.leading, 62)
                        }
                    }
                }
                .glassPanel(radius: Theme.radius)

                Text("数据来自 /api/appstats 与 /api/services，15 秒刷新一次")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.dim)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackground())
    }

    private func isRunning(_ st: AppStat?) -> Bool {
        guard let state = st?.state, !state.isEmpty else { return false }
        return state.lowercased().hasPrefix("running") || state.lowercased() == "active"
    }

    private func storageText(_ st: AppStat?) -> String? {
        let v = st?.rootfs ?? st?.rw
        guard let v = v, !v.isEmpty, v != "—" else { return nil }
        return v
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

// MARK: - 竖排应用行（图标 + 名称描述 + 状态/时长/存储/内存）

struct AppRow: View {
    let icon: String
    let colors: [Color]
    let name: String
    let desc: String
    var running: Bool = false
    var upText: String? = nil
    var cpu: String? = nil
    var storage: String? = nil
    var mem: String? = nil
    var tag: String = ""
    var canOpen: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if !tag.isEmpty {
                        PulseChip(text: tag, tint: canOpen ? Theme.accent : Theme.sub)
                    }
                }
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            metric("状态", value: running ? "运行中" : "已停止",
                   tint: running ? Theme.green : Theme.red, dot: true)
            metric("时长", value: upText ?? "—")
            metric("存储", value: storage ?? "—")
            metric("内存", value: mem ?? "—")
            metric("CPU", value: cpu ?? "—")

            if canOpen {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func metric(_ label: String, value: String, tint: Color = Theme.sub, dot: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.dim)
            HStack(spacing: 4) {
                if dot {
                    Circle().fill(tint).frame(width: 5, height: 5)
                }
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(dot ? tint : Theme.text)
                    .lineLimit(1)
            }
        }
        .frame(width: 64, alignment: .trailing)
    }
}
