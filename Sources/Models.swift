import Foundation

// MARK: - /api/snapshot

struct Snapshot: Decodable {
    let time: Double
    let total_down: Double
    let total_up: Double
    let online: Int
    let total: Int
    let sample_ms: Int?
    let history: [HistPoint]
    let devices: [Device]
    let wan_ip: String?
}

struct HistPoint: Decodable, Identifiable {
    var id: Double { t }
    let t: Double
    let down: Double
    let up: Double
    let cpu: Double?
    let mem: Double?
    let abn: Double?
}

struct Device: Decodable, Identifiable {
    var id: String { mac.isEmpty ? raw : mac }
    let name: String
    let raw: String
    let ip: String
    let mac: String
    let conn_type: String?
    let conn: String?
    let down: Double
    let up: Double
    let total_in: Double
    let total_out: Double
    let online: Bool
    let last: Double?
    let limit: Double?
    let blocked: Bool?
}

// MARK: - /api/sysstat

struct SysStat: Decodable {
    let mem_total_mb: Double
    let mem_used_mb: Double
    let mem_percent: Double
    let cpu_percent: Double
    let load: [Double]
    let procs: [ProcStat]?
    let time: Double
}

struct ProcStat: Decodable, Identifiable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let cpu: Double
    let mem_mb: Double
}

// MARK: - /api/abn_top

struct AbnTop: Decodable {
    let win: Double
    let total: Double
    let ips: [TopIP]
    let ports: [TopPort]
    let time: Double
}

struct TopIP: Decodable, Identifiable {
    var id: String { ip }
    let ip: String
    let geo: String?
    let cc: String?
    let cnt: Double
    let pct: Double
}

struct TopPort: Decodable, Identifiable {
    var id: String { port }
    let port: String
    let svc: String?
    let cnt: Double
    let srcs: Double?
    let pct: Double
}

// MARK: - /api/appstats

struct AppStats: Decodable {
    let data: AppStatsData
}

struct AppStatsData: Decodable {
    let containers: [String: AppStat]
    let services: [String: AppStat]
}

struct AppStat: Decodable {
    let state: String?
    let up_sec: Double?
    let up_text: String?
    let cpu: String?
    let mem: String?
    let mem_pct: String?
    let rw: String?
    let rootfs: String?
    let store: String?
    let store_det: String?

    var cpuValue: Double {
        Double((cpu ?? "0").replacingOccurrences(of: "%", with: "")) ?? 0
    }
    var memPercent: Double {
        Double((mem_pct ?? "0").replacingOccurrences(of: "%", with: "")) ?? 0
    }
    var running: Bool { (state ?? "running") == "running" }
}

// MARK: - /api/natmap

struct NatMap: Decodable {
    let ok: Bool
    let slots: [NatSlot]
    let ips: [NatIP]
}

struct NatSlot: Decodable, Identifiable {
    var id: Int { port }
    let port: Int
    let ip: String
    let iport: Int
    let on: Bool
    let active: Bool
    let valid: Bool
}

struct NatIP: Decodable, Identifiable {
    var id: String { ip }
    let ip: String
    let host: String?
}

// MARK: - /api/notify

struct NotifyCfg: Decodable {
    let webhook: String
    let enabled: Bool
    let daily_on: Bool
    let scan_on: Bool
}

// MARK: - /api/pppoe

struct PPPoE: Decodable {
    let account: String?
    let has_password: Bool?
    let online: Bool?
    let ip: String?
    let peers_file: String?
}

// MARK: - /api/host（主机：磁盘 / 磁盘 IO / 温度 / 负载）

struct HostInfo: Decodable {
    let cpu: Double?
    let load: [Double]?
    let temp: Double?
    let mem: HostMem?
    let dio: DirIO?
    let uptime: HostUptime?
    let disks: [DiskInfo]?
}

struct HostMem: Decodable {
    let total_mb: Double?
    let used_mb: Double?
    let avail_mb: Double?
    let percent: Double?
    let cache_mb: Double?
    let swap_total_mb: Double?
    let swap_used_mb: Double?
    let swap_percent: Double?
}

struct DirIO: Decodable {
    let read: Double?
    let write: Double?
    let read_total: Double?
    let write_total: Double?
}

struct HostUptime: Decodable {
    let seconds: Double?
    let boot_at: String?
}

struct DiskInfo: Decodable, Identifiable {
    var id: String { mount }
    let mount: String
    let dev: String?
    let fs: String?
    let total: Double
    let used: Double
    let free: Double?
    let percent: Double
    let inode_percent: Double?
}

// MARK: - /api/abnormal（异常连接日志）

struct AbnLogResp: Decodable {
    let logs: [AbnLog]
    let total: Double?
}

struct AbnLog: Decodable, Identifiable {
    var id: Double { t }
    let t: Double
    let dir: String?
    let type: String?
    let kind: String?
    let src: String
    let proto: String?
    let dst: String?
    let detail: String?
    let geo: String?
    let cc: String?
    let count: Double?
}

// MARK: - /api/blacklist

struct BlacklistResp: Decodable {
    let ips: [BlackIP]
}

struct BlackIP: Decodable, Identifiable {
    var id: String { ip }
    let ip: String
    let cc: String?
    let geo: String?
}

// MARK: - /api/services（后台服务）

struct ServicesResp: Decodable {
    let services: [ServiceInfo]
}

struct ServiceInfo: Decodable, Identifiable {
    var id: String { sid }
    let sid: String
    let name: String
    let desc: String?
    let port: String?
    let type: String?
    let state: String?
    let running: Bool
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case sid = "id"
        case name, desc, port, type, state, running, detail
    }
}

// MARK: - /api/apps（自定义快捷入口）

struct AppsResp: Decodable {
    let apps: [StoreApp]
}

struct StoreApp: Decodable, Identifiable {
    let id: String
    let name: String
    let url: String
    let desc: String?
    let grad: String?
}

// MARK: - 通用 POST 返回
struct APIResp {
    let ok: Bool
    let msg: String?
    let error: String?

    init(_ dict: [String: Any]) {
        ok = (dict["ok"] as? Bool) ?? false
        msg = dict["msg"] as? String
        error = dict["error"] as? String
    }

    var text: String {
        if ok { return msg ?? "已保存" }
        return error ?? msg ?? "操作失败"
    }
}
