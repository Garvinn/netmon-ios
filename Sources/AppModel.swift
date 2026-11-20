import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snap: Snapshot?
    @Published var sys: SysStat?
    @Published var abn: AbnTop?
    @Published var apps: AppStats?
    @Published var nat: NatMap?
    @Published var notify: NotifyCfg?
    @Published var pppoe: PPPoE?
    @Published var host: HostInfo?
    @Published var services: [ServiceInfo] = []
    @Published var blacklist: [BlackIP] = []
    @Published var abnLogs: [AbnLog] = []
    @Published var storeApps: [StoreApp] = []

    @Published var lastError: String?
    @Published var updatedAt: Date?
    @Published var rankRange: String = "1"
    @Published var isRefreshing = false

    private var fastLoop: Task<Void, Never>?
    private var slowLoop: Task<Void, Never>?

    // MARK: 轮询

    func startPolling() {
        guard fastLoop == nil else { return }
        fastLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshFast()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        slowLoop = Task { [weak self] in
            await self?.refreshSlow()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await self?.refreshSlow()
            }
        }
    }

    func stopPolling() {
        fastLoop?.cancel(); fastLoop = nil
        slowLoop?.cancel(); slowLoop = nil
    }

    func refreshFast() async {
        do {
            async let s = NetmonAPI.snapshot()
            async let y = NetmonAPI.sysstat()
            let (snapValue, sysValue) = try await (s, y)
            snap = snapValue
            sys = sysValue
            lastError = nil
            updatedAt = Date()
        } catch {
            if snap == nil { lastError = error.localizedDescription }
        }
    }

    func refreshSlow() async {
        if let v = try? await NetmonAPI.appStats() { apps = v }
        if let v = try? await NetmonAPI.natmap() { nat = v }
        if let v = try? await NetmonAPI.notify() { notify = v }
        if let v = try? await NetmonAPI.pppoe() { pppoe = v }
        if let v = try? await NetmonAPI.host() { host = v }
        if let v = try? await NetmonAPI.services() { services = v.services }
        if let v = try? await NetmonAPI.blacklist() { blacklist = v.ips }
        if let v = try? await NetmonAPI.abnormal(range: "1", page: 1, size: 8) { abnLogs = v.logs }
        if let v = try? await NetmonAPI.apps() { storeApps = v.apps }
    }

    func refreshAll() async {
        isRefreshing = true
        await refreshFast()
        await refreshSlow()
        await loadRank()
        isRefreshing = false
    }

    func loadRank() async {
        if let v = try? await NetmonAPI.abnTop(range: rankRange) { abn = v }
    }

    func setRange(_ r: String) {
        rankRange = r
        Task { await loadRank() }
    }

    func reloadApps() {
        Task { if let v = try? await NetmonAPI.appStats() { apps = v } }
    }

    func reloadNat() {
        Task { if let v = try? await NetmonAPI.natmap() { nat = v } }
    }

    func reloadPPPoE() {
        Task { if let v = try? await NetmonAPI.pppoe() { pppoe = v } }
    }
}
