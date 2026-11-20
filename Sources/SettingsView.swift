import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var m: AppModel
    @EnvironmentObject var modules: ModuleStore

    @AppStorage("serverURL") private var serverURL: String = NetmonAPI.defaultServer

    @State private var webhook = ""
    @State private var dailyOn = true
    @State private var scanOn = false
    @State private var account = ""
    @State private var password = ""
    @State private var toast: String?
    @State private var toastOK = true
    @State private var busy = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    PageHeader(title: "设置", subtitle: "改动即时写入，刷新后仍保留")

                    serverCard

                    modulesCard

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            CardTitle(text: "飞书通知", icon: "bell.badge")
                            Text("每日统计日报每天 00:00 推送昨日汇总；外网扫描告警按来源 IP 聚合推送。两个开关互相独立。")
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.dim)
                                .lineSpacing(2)

                            inputRow(label: "Webhook") {
                                TextField("https://open.feishu.cn/open-apis/bot/v2/hook/…", text: $webhook)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.text)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .keyboardType(.URL)
                            }

                            Toggle("每日统计日报", isOn: $dailyOn)
                                .font(.system(size: 12))
                                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                            Toggle("外网扫描告警", isOn: $scanOn)
                                .font(.system(size: 12))
                                .toggleStyle(SwitchToggleStyle(tint: Theme.accent))

                            HStack(spacing: 8) {
                                actionButton("保存配置", filled: true) { saveNotify() }
                                actionButton("发送测试通知") { testNotify() }
                            }
                            Text("日报：\(dailyOn ? "开" : "关") · 扫描告警：\(scanOn ? "开" : "关")")
                                .font(.system(size: 9.5))
                                .foregroundColor(Theme.dim)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            CardTitle(text: "宽带拨号（PPPoE）", icon: "network")
                            Text("账号密码保存在 /etc/ppp，密码不回显；留空表示只改账号。保存后需点「立即重拨」才生效。")
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.dim)
                                .lineSpacing(2)

                            inputRow(label: "宽带账号") {
                                TextField("宽带账号", text: $account)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.text)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .keyboardType(.numberPad)
                            }
                            inputRow(label: "宽带密码") {
                                TextField(m.pppoe?.has_password == true ? "已设置（留空不改）" : "未设置", text: $password)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.text)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }

                            HStack(spacing: 8) {
                                actionButton("保存", filled: true) { savePPPoE() }
                                actionButton("立即重拨") { reconnect() }
                            }

                            HStack(spacing: 6) {
                                Dot(on: m.pppoe?.online == true)
                                Text(m.pppoe?.online == true ? "已拨号 · \(m.pppoe?.ip ?? "")" : "未拨号")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(m.pppoe?.online == true ? Theme.green : Theme.dim)
                            }
                        }
                    }

                    if let toast {
                        HStack(spacing: 6) {
                            Image(systemName: toastOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(toastOK ? Theme.green : Theme.red)
                            Text(toast)
                                .font(.system(size: 11))
                                .foregroundColor(toastOK ? Theme.green : Theme.red)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill((toastOK ? Theme.green : Theme.red).opacity(0.10)))
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("关于")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.sub)
                            Text("netmon 原生版 1.0 · 对接 J4125 上的 netmon.py\n后端：\(serverURL)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundColor(Theme.dim)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
            }
        }
        .onAppear(perform: syncFromModel)
        .onChange(of: m.notify?.webhook ?? "") { _ in syncNotify() }
        .onChange(of: m.pppoe?.account ?? "") { _ in syncPPPoE() }
    }

    // MARK: 监控模块

    private var modulesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(text: "监控模块", icon: "square.grid.2x2")
                Text("监控页由这些模块拼成。开关控制显示，箭头调整上下顺序，配置保存在本机。")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.dim)
                    .lineSpacing(2)

                ForEach(modules.order) { id in
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(id.accent.opacity(0.15))
                            Image(systemName: id.icon)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(id.accent)
                        }
                        .frame(width: 20, height: 20)

                        Text(id.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.text)
                        if id.full {
                            Tag(text: "整行", tint: Theme.dim)
                        }
                        Spacer(minLength: 4)

                        Button { modules.up(id) } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.sub)
                                .frame(width: 22, height: 22)
                        }
                        Button { modules.down(id) } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.sub)
                                .frame(width: 22, height: 22)
                        }

                        Toggle("", isOn: Binding(
                            get: { modules.isOn(id) },
                            set: { _ in modules.toggle(id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: id.accent))
                    }
                    .padding(.vertical, 4)
                    .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
                }

                HStack(spacing: 8) {
                    actionButton("恢复默认顺序") { modules.reset() }
                    Text("已显示 \(modules.visible.count) / \(modules.order.count) 个")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                }
            }
        }
    }

    // MARK: 服务器地址

    private var serverCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(text: "服务器地址", icon: "externaldrive.connected.to.line.below")
                HStack(spacing: 8) {
                    TextField(NetmonAPI.defaultServer, text: $serverURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .onSubmit { normalizeServer() }
                    Button {
                        normalizeServer()
                    } label: {
                        Text("应用")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.85)))
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke.opacity(0.7), lineWidth: 0.5))

                Text("内网 192.168.31.1；外网先连 WireGuard 再用同一地址。")
                    .font(.system(size: 9.5))
                    .foregroundColor(Theme.dim)
            }
        }
    }

    private func normalizeServer() {
        var v = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { v = NetmonAPI.defaultServer }
        if !v.lowercased().hasPrefix("http://") && !v.lowercased().hasPrefix("https://") {
            v = "http://" + v
        }
        if !v.hasSuffix("/") { v += "/" }
        serverURL = v
        Task { await m.refreshAll() }
    }

    // MARK: 样式组件

    private func inputRow<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.dim)
            content()
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke.opacity(0.7), lineWidth: 0.5))
        }
    }

    private func actionButton(_ title: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(filled ? Theme.text : Theme.sub)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(filled ? Theme.accent.opacity(0.85) : Color.white.opacity(0.07))
                )
        }
        .disabled(busy)
    }

    // MARK: 同步

    private func syncFromModel() {
        syncNotify()
        syncPPPoE()
    }

    private func syncNotify() {
        guard let cfg = m.notify else { return }
        if webhook.isEmpty { webhook = cfg.webhook }
        dailyOn = cfg.daily_on
        scanOn = cfg.scan_on
    }

    private func syncPPPoE() {
        guard let p = m.pppoe else { return }
        if account.isEmpty { account = p.account ?? "" }
    }

    // MARK: 动作

    private func showToast(_ text: String, ok: Bool) {
        toastOK = ok
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if toast == text { toast = nil }
        }
    }

    private func saveNotify() {
        busy = true
        Task {
            do {
                let resp = try await NetmonAPI.post("api/notify", [
                    "webhook": webhook.trimmingCharacters(in: .whitespaces),
                    "enabled": dailyOn || scanOn,
                    "daily_on": dailyOn,
                    "scan_on": scanOn
                ])
                await MainActor.run {
                    busy = false
                    showToast(resp.text, ok: resp.ok)
                }
                if let cfg = try? await NetmonAPI.notify() {
                    await MainActor.run { m.notify = cfg }
                }
            } catch {
                await MainActor.run {
                    busy = false
                    showToast(error.localizedDescription, ok: false)
                }
            }
        }
    }

    private func testNotify() {
        busy = true
        Task {
            do {
                let resp = try await NetmonAPI.post("api/notify/test", ["webhook": webhook])
                await MainActor.run {
                    busy = false
                    showToast(resp.text, ok: resp.ok)
                }
            } catch {
                await MainActor.run {
                    busy = false
                    showToast(error.localizedDescription, ok: false)
                }
            }
        }
    }

    private func savePPPoE() {
        busy = true
        Task {
            do {
                let resp = try await NetmonAPI.post("api/pppoe", [
                    "account": account.trimmingCharacters(in: .whitespaces),
                    "password": password
                ])
                await MainActor.run {
                    busy = false
                    password = ""
                    showToast(resp.text, ok: resp.ok)
                }
                m.reloadPPPoE()
            } catch {
                await MainActor.run {
                    busy = false
                    showToast(error.localizedDescription, ok: false)
                }
            }
        }
    }

    private func reconnect() {
        busy = true
        Task {
            do {
                let resp = try await NetmonAPI.post("api/pppoe/reconnect", [:])
                await MainActor.run {
                    busy = false
                    showToast(resp.text, ok: resp.ok)
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                m.reloadPPPoE()
            } catch {
                await MainActor.run {
                    busy = false
                    showToast(error.localizedDescription, ok: false)
                }
            }
        }
    }
}
