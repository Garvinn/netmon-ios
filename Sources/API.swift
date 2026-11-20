import Foundation

enum APIError: LocalizedError {
    case badURL
    case status(Int)
    case decode(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "服务器地址无效"
        case .status(let c): return "服务端返回 \(c)"
        case .decode(let m): return "数据解析失败：\(m)"
        case .network(let m): return m
        }
    }
}

/// 与 netmon.py 的 HTTP 接口对接（后端一行不用改）
struct NetmonAPI {
    static let defaultServer = "http://192.168.31.1/"

    static var baseURL: URL {
        let raw = UserDefaults.standard.string(forKey: "serverURL") ?? defaultServer
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u = URL(string: trimmed), u.scheme != nil { return u }
        return URL(string: defaultServer)!
    }

    private static func request(_ path: String) -> URLRequest {
        let url = URL(string: path, relativeTo: baseURL) ?? baseURL
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.cachePolicy = .reloadIgnoringLocalCacheData
        return req
    }

    static func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(for: request(path))
        guard let http = resp as? HTTPURLResponse else { throw APIError.network("无响应") }
        guard (200..<300).contains(http.statusCode) else { throw APIError.status(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decode(String(describing: error))
        }
    }

    @discardableResult
    static func post(_ path: String, _ body: [String: Any]) async throws -> APIResp {
        var req = request(path)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.network("无响应") }
        guard (200..<300).contains(http.statusCode) else { throw APIError.status(http.statusCode) }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return APIResp(obj)
    }

    // MARK: 具体接口

    static func snapshot() async throws -> Snapshot { try await get("api/snapshot", as: Snapshot.self) }
    static func sysstat() async throws -> SysStat { try await get("api/sysstat", as: SysStat.self) }
    static func abnTop(range: String) async throws -> AbnTop {
        let q = range == "all" ? "api/abn_top?all=1" : "api/abn_top?range=\(range)"
        return try await get(q, as: AbnTop.self)
    }
    static func appStats() async throws -> AppStats { try await get("api/appstats", as: AppStats.self) }
    static func natmap() async throws -> NatMap { try await get("api/natmap", as: NatMap.self) }
    static func notify() async throws -> NotifyCfg { try await get("api/notify", as: NotifyCfg.self) }
    static func pppoe() async throws -> PPPoE { try await get("api/pppoe", as: PPPoE.self) }
}
