import SwiftUI

// MARK: - 监控模块定义（参考 Stats 的 Module 架构：每个指标是独立模块，可开关、可排序）

enum ModuleID: String, CaseIterable, Identifiable {
    case flow, abn, cpu, mem, trend, load, abnormal, blacklist, disk, dio, ips, ports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flow:     return "实时流量"
        case .abn:      return "异常拦截"
        case .cpu:      return "CPU"
        case .mem:      return "内存"
        case .trend:    return "流量趋势"
        case .load:     return "系统负载"
        case .abnormal: return "异常连接"
        case .blacklist:return "黑名单"
        case .disk:     return "磁盘"
        case .dio:      return "磁盘 IO"
        case .ips:      return "来源 IP 排行"
        case .ports:    return "扫描端口排行"
        }
    }

    var icon: String {
        switch self {
        case .flow:     return "arrow.up.arrow.down"
        case .abn:      return "shield.lefthalf.filled"
        case .cpu:      return "cpu"
        case .mem:      return "memorychip"
        case .trend:    return "chart.xyaxis.line"
        case .load:     return "list.bullet.rectangle"
        case .abnormal: return "exclamationmark.triangle"
        case .blacklist:return "hand.raised"
        case .disk:     return "internaldrive"
        case .dio:      return "externaldrive.connected.to.line.below"
        case .ips:      return "globe"
        case .ports:    return "network"
        }
    }

    var accent: Color {
        switch self {
        case .flow:     return Theme.blue
        case .abn:      return Theme.red
        case .cpu:      return Theme.amber
        case .mem:      return Theme.green
        case .trend:    return Theme.accent
        case .load:     return Theme.purple
        case .abnormal: return Theme.orange
        case .blacklist:return Theme.pink
        case .disk:     return Theme.cyan
        case .dio:      return Theme.accent2
        case .ips:      return Theme.orange
        case .ports:    return Theme.green
        }
    }

    /// 横向占位：full 独占一行，half 可两两并排
    var full: Bool {
        switch self {
        case .trend, .dio: return true
        default: return false
        }
    }
}

// MARK: - 模块存储（UserDefaults）

final class ModuleStore: ObservableObject {
    @Published private(set) var order: [ModuleID]
    @Published private(set) var hidden: Set<ModuleID>

    private let kOrder = "netmon.modules.order"
    private let kHidden = "netmon.modules.hidden"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: kOrder) ?? []
        var list: [ModuleID] = []
        for raw in saved {
            if let id = ModuleID(rawValue: raw), !list.contains(id) { list.append(id) }
        }
        for id in ModuleID.allCases where !list.contains(id) { list.append(id) }
        // 默认顺序：指标 → 趋势 → 列表 → 排行
        if saved.isEmpty {
            list = ModuleID.allCases
        }
        self.order = list
        self.hidden = Set((UserDefaults.standard.stringArray(forKey: kHidden) ?? []).compactMap { ModuleID(rawValue: $0) })
    }

    var visible: [ModuleID] { order.filter { !hidden.contains($0) } }

    func isOn(_ id: ModuleID) -> Bool { !hidden.contains(id) }

    func toggle(_ id: ModuleID) {
        if hidden.contains(id) { hidden.remove(id) } else { hidden.insert(id) }
        persist()
    }

    func isFull(_ id: ModuleID) -> Bool { hidden.contains(id) ? false : id.full }

    /// 上移一位
    func up(_ id: ModuleID) {
        guard let i = order.firstIndex(of: id), i > 0 else { return }
        order.swapAt(i, i - 1)
        persist()
    }

    /// 下移一位
    func down(_ id: ModuleID) {
        guard let i = order.firstIndex(of: id), i < order.count - 1 else { return }
        order.swapAt(i, i + 1)
        persist()
    }

    func reset() {
        order = ModuleID.allCases
        hidden = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(order.map { $0.rawValue }, forKey: kOrder)
        UserDefaults.standard.set(Array(hidden.map { $0.rawValue }), forKey: kHidden)
    }
}
