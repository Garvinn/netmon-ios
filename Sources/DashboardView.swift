import SwiftUI

// MARK: - 监控页：可拖动 / 可调宽度的卡片流 + 安全统计合并

enum DashCard: String, CaseIterable, Identifiable {
    case network, node, load, disk, dio, procs
    case abn, ipTotal, portTotal, ipRank, portRank, abnormal, blacklist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:   return "网络"
        case .node:      return "节点"
        case .load:      return "负载"
        case .disk:      return "存储"
        case .dio:       return "磁盘 IO"
        case .procs:     return "进程"
        case .abn:       return "拦截"
        case .ipTotal:   return "来源 IP"
        case .portTotal: return "扫描端口"
        case .ipRank:    return "来源 IP"
        case .portRank:  return "扫描端口"
        case .abnormal:  return "异常连接"
        case .blacklist: return "黑名单"
        }
    }

    var defaultSpan: Int {
        switch self {
        case .network, .abnormal: return 2
        default: return 1
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .network: return 208
        case .ipRank, .portRank, .abnormal, .blacklist: return 232
        default: return 126
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var m: AppModel

    @AppStorage("dashOrder") private var orderRaw = ""
    @AppStorage("dashSpans") private var spansRaw = ""
    @AppStorage("dashEdit") private var editMode = false

    @State private var showDevices = false

    private var order: [DashCard] {
        let saved = orderRaw.split(separator: ",").compactMap { DashCard(rawValue: String($0)) }
        let missing = DashCard.allCases.filter { !saved.contains($0) }
        return saved + missing
    }

    private func span(_ c: DashCard) -> Int {
        for kv in spansRaw.split(separator: "|") {
            let parts = kv.split(separator: ":")
            if parts.count == 2, String(parts[0]) == c.rawValue, let v = Int(parts[1]) {
                return max(1, min(v, 3))
            }
        }
        return c.defaultSpan
    }

    private func setSpan(_ c: DashCard, _ v: Int) {
        var dict: [String: Int] = [:]
        for kv in spansRaw.split(separator: "|") {
            let parts = kv.split(separator: ":")
            if parts.count == 2, let v2 = Int(parts[1]) { dict[String(parts[0])] = v2 }
        }
        dict[c.rawValue] = max(1, min(v, 3))
        spansRaw = dict.map { "\($0.key):\($0.value)" }.joined(separator: "|")
    }

    private func move(_ id: String, before target: String) {
        guard id != target, let from = DashCard(rawValue: id), let to = DashCard(rawValue: target) else { return }
        var list = order
        list.removeAll { $0 == from }
        if let idx = list.firstIndex(of: to) { list.insert(from, at: idx) } else { list.append(from) }
        withAnimation(.snappy(duration: 0.22)) {
            orderRaw = list.map(\.rawValue).joined(separator: ",")
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cols = geo.size.width >= 900 ? 4 : (geo.size.width >= 620 ? 3 : 2)
            let spacing: CGFloat = 10
            let cellW = (geo.size.width - 40 - spacing * CGFloat(cols - 1)) / CGFloat(cols)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    PageHeader(title: "网络监控",
                               subtitle: m.snap?.wan_ip.map { "外网 \($0)" } ?? "正在连接…",
                               onRefresh: { Task { await m.refreshAll() } },
                               refreshing: m.isRefreshing)

                    chipsRow
                    hostStrip

                    GlassRangeBar(options: [("1", "24 小时"), ("7", "7 天"), ("30", "30 天"), ("all", "1 年")],
                                   selection: Binding(get: { m.rankRange }, set: { _ in }),
                                   loading: m.rankLoading,
                                   onChange: { m.setRange($0) })

                    securityStrip
                        .opacity(m.rankLoading ? 0.45 : 1)
                        .overlay {
                            if m.rankLoading {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small).tint(Theme.accent)
                                    Text("正在统计所选时间范围…")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.sub)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .glassEffect(.regular, in: .capsule)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: m.rankLoading)

                    ForEach(Array(rows(cols: cols).enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(row, id: \.self) { c in
                                cell(c, cellW: cellW, cols: cols)
                                    .frame(width: cellW * CGFloat(min(span(c), cols)) + spacing * CGFloat(min(span(c), cols) - 1))
                                    .draggable(c.rawValue) {
                                        Text(c.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(10)
                                            .glassEffect(.regular, in: .rect(cornerRadius: 10))
                                    }
                                    .dropDestination(for: String.self) { items, _ in
                                        if let first = items.first { move(first, before: c.rawValue) }
                                        return true
                                    }
                            }
                        }
                    }

                    if editMode {
                        Text("拖动卡片可换位置，点卡片右上角图标可改宽度")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.dim)
                    }

                    if let err = m.lastError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.red)
                            .padding(.vertical, 6)
                    }

                    Text(m.updatedAt.map { "更新于 \(Fmt.clock($0))" } ?? " ")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppBackground())
        .sheet(isPresented: $showDevices) {
            DevicesView().environmentObject(m)
        }
        .onAppear { if m.abn == nil { Task { await m.loadRank() } } }
    }

    // MARK: 动态行打包（自动对齐）

    private func rows(cols: Int) -> [[DashCard]] {
        var result: [[DashCard]] = []
        var current: [DashCard] = []
        var used = 0
        for c in order {
            let sp = min(span(c), cols)
            if used + sp > cols, !current.isEmpty {
                result.append(current)
                current = []; used = 0
            }
            current.append(c)
            used += sp
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    // MARK: 顶部小药丸

    private var chipsRow: some View {
        HStack(spacing: 6) {
            if let s = m.snap {
                PulseChip(text: "\(s.online)/\(s.total) 在线", tint: Theme.green)
            }
            if let y = m.sys {
                PulseChip(text: "CPU \(Int(y.cpu_percent.rounded()))%", tint: Theme.accent)
                PulseChip(text: "MEM \(Int(y.mem_percent.rounded()))%", tint: Theme.purple)
            }
            Spacer(minLength: 0)
            if let ip = m.snap?.wan_ip {
                Text(ip)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }

    // MARK: 主机信息条

    private var hostStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hostLine1)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .textSelection(.enabled)
            Text(hostLine2)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: 12)
    }

    private var hostLine1: String {
        guard let h = m.host, let si = h.sysinfo else { return "HomeDebian · 读取主机信息…" }
        var parts: [String] = []
        if let hn = si.hostname, !hn.isEmpty { parts.append(hn) }
        if let cpu = si.cpu_model, !cpu.isEmpty {
            parts.append(si.cores.map { "\(cpu) (\(Int($0)) 核)" } ?? cpu)
        }
        if let d = si.distro, !d.isEmpty {
            parts.append(d.lowercased().contains("debian") ? d : "Debian \(d)")
        }
        if let k = si.kernel, !k.isEmpty { parts.append("内核 \(k)") }
        return parts.joined(separator: " · ")
    }

    private var hostLine2: String {
        guard let h = m.host else { return " " }
        var parts: [String] = []
        if let boot = h.uptime?.boot_at { parts.append("开机 \(boot)") }
        if let sec = h.uptime?.seconds { parts.append("已运行 \(uptimeText(sec))") }
        if let load = h.load, !load.isEmpty {
            parts.append("负载 " + load.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " / "))
        }
        return parts.joined(separator: " · ")
    }

    private func uptimeText(_ sec: Double) -> String {
        let s = Int(sec)
        let d = s / 86400, hh = (s % 86400) / 3600, mm = (s % 3600) / 60
        if d > 0 { return "\(d) 天 \(hh) 小时 \(mm) 分" }
        if hh > 0 { return "\(hh) 小时 \(mm) 分" }
        return "\(mm) 分"
    }

    // MARK: 安全三项

    private var securityStrip: some View {
        HStack(spacing: 10) {
            securityTile(title: "拦截", icon: "shield.lefthalf.filled", tint: Theme.orange,
                         value: Fmt.count(m.abn?.total ?? 0), unit: "次",
                         note: "\(Fmt.rangeLabel(m.rankRange)) · 累计拦截")
            securityTile(title: "来源 IP", icon: "globe.asia.australia.fill", tint: Theme.cyan,
                         value: Fmt.count(m.abn?.ipTotal ?? 0), unit: "个",
                         note: "所选时间内唯一 IP")
            securityTile(title: "扫描端口", icon: "network.badge.shield.half.filled", tint: Theme.green,
                         value: Fmt.count(m.abn?.portTotal ?? 0), unit: "个",
                         note: "所选时间内唯一端口")
        }
    }

    private func securityTile(title: String, icon: String, tint: Color,
                              value: String, unit: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(tint)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.sub)
            }
            Text(note)
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: 12)
    }

    // MARK: 卡片分发

    @ViewBuilder
    private func cell(_ c: DashCard, cellW: CGFloat, cols: Int) -> some View {
        let body = card(c)
            .frame(maxWidth: .infinity, minHeight: c.minHeight, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                if editMode {
                    HStack(spacing: 5) {
                        Button { setSpan(c, span(c) - 1) } label: {
                            Image(systemName: "minus").font(.system(size: 9, weight: .bold))
                        }
                        Button { setSpan(c, span(c) + 1) } label: {
                            Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .padding(6)
                }
            }
            .contextMenu {
                Button("宽 1 列") { setSpan(c, 1) }
                Button("宽 2 列") { setSpan(c, 2) }
                Button("宽 3 列") { setSpan(c, 3) }
                Divider()
                Button(editMode ? "退出布局编辑" : "编辑布局（拖动 / 改宽度）") {
                    withAnimation(.snappy) { editMode.toggle() }
                }
            }

        if c == .node {
            Button { showDevices = true } label: { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }

    @ViewBuilder
    private func card(_ c: DashCard) -> some View {
        switch c {
        case .network:   networkCard
        case .node:      nodeCard
        case .load:      loadCard
        case .disk:      diskCard
        case .dio:       dioCard
        case .procs:     procsCard
        case .abn:       abnCard
        case .ipTotal:   ipTotalCard
        case .portTotal: portTotalCard
        case .ipRank:    ipRankCard
        case .portRank:  portRankCard
        case .abnormal:  abnormalCard
        case .blacklist: blacklistCard
        }
    }

    // MARK: - 监控卡片

    private var networkCard: some View {
        PulseCard(icon: "wifi.router", title: "网络", accent: Theme.accent,
                  status: peakText, statusOK: true, padding: 14) {
            HStack(spacing: 10) {
                rateBox(title: "下载", arrow: "arrow.down", value: m.snap?.total_down ?? 0, tint: Theme.blue)
                rateBox(title: "上传", arrow: "arrow.up", value: m.snap?.total_up ?? 0, tint: Theme.purple)
            }
            TrendChart(points: m.snap?.history ?? [], height: 118)
            ChartLegend()
        }
    }

    private var peakText: String? {
        guard let h = m.snap?.history, !h.isEmpty else { return nil }
        let peak = h.map { max($0.down, $0.up) }.max() ?? 0
        return peak > 0 ? "峰值 \(Fmt.rate(peak))" : nil
    }

    private func rateBox(title: String, arrow: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: arrow)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Fmt.rateValue(value))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(tint)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(Fmt.rateUnit(value))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.sub)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.08)))
    }

    private var nodeCard: some View {
        PulseCard(icon: "point.3.connected.trianglepath.dotted", title: "节点",
                  accent: Theme.green,
                  status: (m.snap?.online ?? 0) > 0 ? "在线" : "离线",
                  statusOK: (m.snap?.online ?? 0) > 0) {
            PulseLabel(text: "在线设备", trailing: "点击查看")
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(m.snap?.online ?? 0)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Theme.text)
                    .monospacedDigit()
                Text("/ \(m.snap?.total ?? 0) 台")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.sub)
            }
            MiniProgress(value: Double(m.snap?.online ?? 0) / Double(max(m.snap?.total ?? 1, 1)),
                         tint: Theme.green, height: 4)
            Text("共发现 \(m.snap?.total ?? 0) 台")
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
        }
    }

    private var loadCard: some View {
        PulseCard(icon: "cpu", title: "负载", accent: Theme.accent,
                  status: loadStatus, statusOK: (m.sys?.cpu_percent ?? 0) < 80) {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    PulseLabel(text: "CPU")
                    PulseValue(value: "\(Int((m.sys?.cpu_percent ?? 0).rounded()))", unit: "%",
                               tint: Theme.text, size: 20, leading: true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    PulseLabel(text: "MEM")
                    PulseValue(value: "\(Int((m.sys?.mem_percent ?? 0).rounded()))", unit: "%",
                               tint: Theme.text, size: 20, leading: true)
                }
            }
            MiniProgress(value: (m.sys?.cpu_percent ?? 0) / 100, tint: Theme.accent, height: 3)
            MiniProgress(value: (m.sys?.mem_percent ?? 0) / 100, tint: Theme.purple, height: 3)
            Text(loadDetail)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var loadStatus: String? {
        guard let h = m.host, let t = h.temp else { return "正常" }
        return "\(Int(t.rounded()))℃"
    }

    private var loadDetail: String {
        let load = (m.host?.load ?? []).prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " ")
        let mem = m.host?.mem
        let used = mem?.used_mb ?? 0, total = mem?.total_mb ?? 0
        return "LOAD \(load) · \(Fmt.size(used * 1_048_576))/\(Fmt.size(total * 1_048_576))"
    }

    private var diskCard: some View {
        let d = m.host?.disks?.first
        return PulseCard(icon: "internaldrive", title: "存储", accent: Theme.purple,
                         status: "\(Int((d?.percent ?? 0).rounded()))%",
                         statusOK: (d?.percent ?? 0) < 80) {
            PulseLabel(text: d?.mount ?? "/", trailing: d.map { Fmt.size($0.total) })
            MiniProgress(value: (d?.percent ?? 0) / 100, tint: Theme.purple, height: 5)
            Text(d.map { "\(Fmt.size($0.used)) / \(Fmt.size($0.total))" } ?? "—")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
    }

    private var dioCard: some View {
        PulseCard(icon: "externaldrive", title: "磁盘 IO", accent: Theme.purple) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    PulseLabel(text: "读")
                    PulseValue(value: Fmt.rateValue(m.host?.dio?.read ?? 0),
                               unit: Fmt.rateUnit(m.host?.dio?.read ?? 0), size: 16, leading: true)
                }
                VStack(alignment: .leading, spacing: 1) {
                    PulseLabel(text: "写")
                    PulseValue(value: Fmt.rateValue(m.host?.dio?.write ?? 0),
                               unit: Fmt.rateUnit(m.host?.dio?.write ?? 0), size: 16, leading: true)
                }
            }
            Text("累计 " + Fmt.size(m.host?.dio?.read_total ?? 0) + " / " + Fmt.size(m.host?.dio?.write_total ?? 0))
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
    }

    private var procsCard: some View {
        let procs = Array((m.sys?.procs ?? []).sorted { $0.cpu > $1.cpu }.prefix(4))
        return PulseCard(icon: "list.bullet.rectangle", title: "进程", accent: Theme.green,
                         status: "LOAD", statusOK: true) {
            VStack(spacing: 2) {
                if procs.isEmpty {
                    Text("—").font(.system(size: 11)).foregroundColor(Theme.dim)
                }
                ForEach(Array(procs.enumerated()), id: \.offset) { _, p in
                    HStack(spacing: 6) {
                        Text(p.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(Int(p.cpu.rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.accent)
                        Text(Fmt.size(p.mem_mb * 1_048_576))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(Theme.dim)
                    }
                }
            }
        }
    }

    // MARK: - 安全卡片

    private var abnCard: some View {
        PulseCard(icon: "shield.lefthalf.filled", title: "拦截", accent: Theme.orange,
                  status: Fmt.rangeLabel(m.rankRange), statusOK: false) {
            PulseLabel(text: "拦截次数", trailing: "窗口 \(Fmt.rangeLabel(m.rankRange))")
            PulseValue(value: Fmt.count(m.abn?.total ?? 0), unit: "次", tint: Theme.orange, size: 22, leading: true)
            Text("按所选时间窗口统计，结果已缓存")
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
    }

    private var ipTotalCard: some View {
        PulseCard(icon: "globe.asia.australia.fill", title: "来源 IP", accent: Theme.cyan,
                  status: "唯一", statusOK: true) {
            PulseLabel(text: "来源 IP 数", trailing: Fmt.rangeLabel(m.rankRange))
            PulseValue(value: Fmt.count(m.abn?.ipTotal ?? 0), unit: "个", tint: Theme.cyan, size: 22, leading: true)
            Text("所选时间内去重后的来源 IP")
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
    }

    private var portTotalCard: some View {
        PulseCard(icon: "network.badge.shield.half.filled", title: "扫描端口", accent: Theme.green,
                  status: "唯一", statusOK: true) {
            PulseLabel(text: "扫描端口数", trailing: Fmt.rangeLabel(m.rankRange))
            PulseValue(value: Fmt.count(m.abn?.portTotal ?? 0), unit: "个", tint: Theme.green, size: 22, leading: true)
            Text("所选时间内去重后的目标端口")
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .lineLimit(1)
        }
    }

    private var ipRankCard: some View {
        let list = Array((m.abn?.ips ?? []).prefix(10))
        let top = max(list.first?.cnt ?? 1, 1)
        return PulseCard(icon: "list.number", title: "来源 IP 排行", accent: Theme.cyan,
                         status: m.rankRange == "1" ? "24 小时" : Fmt.rangeLabel(m.rankRange),
                         statusOK: false, padding: 10) {
            VStack(spacing: 0) {
                if list.isEmpty {
                    Text("暂无数据").font(.system(size: 11)).foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, it in
                    PulseRankRow(index: i, main: it.ip, sub: it.geo,
                                 right: Fmt.count(it.cnt), unit: "次", ratio: it.cnt / top)
                }
            }
        }
    }

    private var portRankCard: some View {
        let list = Array((m.abn?.ports ?? []).prefix(10))
        let top = max(list.first?.cnt ?? 1, 1)
        return PulseCard(icon: "number.circle", title: "扫描端口排行", accent: Theme.green,
                         status: Fmt.rangeLabel(m.rankRange), statusOK: false, padding: 10) {
            VStack(spacing: 0) {
                if list.isEmpty {
                    Text("暂无数据").font(.system(size: 11)).foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, it in
                    PulseRankRow(index: i, main: it.port,
                                 sub: [it.svc, it.srcs.map { "\(Int($0)) 源" }].compactMap { $0 }.joined(separator: " · "),
                                 right: Fmt.count(it.cnt), unit: "次", ratio: it.cnt / top)
                }
            }
        }
    }

    private var abnormalCard: some View {
        PulseCard(icon: "exclamationmark.triangle", title: "异常连接", accent: Theme.orange,
                  status: "\(m.abnLogs.count) 条", statusOK: false, padding: 10) {
            VStack(spacing: 0) {
                if m.abnLogs.isEmpty {
                    Text("暂无异常").font(.system(size: 11)).foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(Array(m.abnLogs.prefix(9).enumerated()), id: \.offset) { _, log in
                    HStack(spacing: 6) {
                        Text(Fmt.time(log.t))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(Theme.dim)
                            .frame(width: 52, alignment: .leading)
                        Text(log.src)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        PulseChip(text: shortType(log), tint: log.dir == "out" ? Theme.purple : Theme.orange)
                        Spacer(minLength: 2)
                        Text([log.geo, log.cc].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 9.5))
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 3.5)
                    .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
                }
            }
        }
    }

    private func shortType(_ log: AbnLog) -> String {
        switch log.type {
        case "fw_drop": return "外部连接阻断"
        case "ad": return "广告/跟踪"
        case "dns": return "DNS"
        default: return log.type ?? "异常"
        }
    }

    private var blacklistCard: some View {
        let list = Array(m.blacklist.prefix(9))
        return PulseCard(icon: "hand.raised.fill", title: "黑名单", accent: Theme.red,
                         status: "\(m.blacklist.count) 条", statusOK: false, padding: 10) {
            VStack(spacing: 0) {
                if list.isEmpty {
                    Text("暂无拉黑记录").font(.system(size: 11)).foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(Array(list.enumerated()), id: \.offset) { i, it in
                    PulseRankRow(index: i, main: it.ip,
                                 sub: [it.geo, it.cc].compactMap { $0 }.joined(separator: " · "))
                }
            }
        }
    }
}
