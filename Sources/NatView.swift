import SwiftUI

struct NatView: View {
    @EnvironmentObject var m: AppModel

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    PageHeader(
                        title: "端口映射",
                        subtitle: "9990–9992 三条固定入口，转发到内网指定 IP",
                        refreshing: m.isRefreshing
                    ) {
                        Task { await m.refreshAll() }
                    }

                    if let slots = m.nat?.slots, !slots.isEmpty {
                        ForEach(slots) { slot in
                            NatSlotCard(slot: slot, lanIPs: m.nat?.ips ?? []) {
                                m.reloadNat()
                            }
                        }
                    } else {
                        GlassCard {
                            Text("读取映射配置…")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.dim)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("说明")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.sub)
                            Text("· 端口固定为 9990 / 9991 / 9992，外网访问 J4125 的公网 IP 加该端口即可进入对应的内网服务。\n· 内网 IP 必须是 10.x / 172.16-31.x / 192.168.x 私有地址。\n· 关闭开关会立即删除对应 iptables 规则。")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.dim)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
            }
        }
    }
}

struct NatSlotCard: View {
    let slot: NatSlot
    let lanIPs: [NatIP]
    var onSaved: () -> Void

    @State private var ip: String
    @State private var iport: String
    @State private var on: Bool
    @State private var busy = false
    @State private var message: String?
    @State private var messageOK = true

    init(slot: NatSlot, lanIPs: [NatIP], onSaved: @escaping () -> Void) {
        self.slot = slot
        self.lanIPs = lanIPs
        self.onSaved = onSaved
        _ip = State(initialValue: slot.ip)
        _iport = State(initialValue: "\(slot.iport)")
        _on = State(initialValue: slot.on)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("\(slot.port)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.text)
                    Text("→")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                    if slot.active {
                        Tag(text: "已生效", tint: Theme.green)
                    } else if slot.on {
                        Tag(text: "已配置", tint: Theme.amber)
                    } else {
                        Tag(text: "未启用", tint: Theme.dim)
                    }
                    if !slot.valid {
                        Tag(text: "IP 无效", tint: Theme.red)
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: $on)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                }

                row(label: "内网 IP") {
                    TextField("192.168.31.x", text: $ip)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.text)
                }
                row(label: "内网端口") {
                    TextField("\(slot.port)", text: $iport)
                        .keyboardType(.numberPad)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.text)
                }

                if !lanIPs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(lanIPs.prefix(8)) { item in
                                Button {
                                    ip = item.ip
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.ip)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundColor(Theme.accent)
                                        if let host = item.host, !host.isEmpty {
                                            Text(host)
                                                .font(.system(size: 8.5))
                                                .foregroundColor(Theme.dim)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent.opacity(0.10)))
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        save()
                    } label: {
                        HStack(spacing: 5) {
                            if busy { ProgressView().scaleEffect(0.6) }
                            Text(busy ? "保存中" : "保存")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Theme.text)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent.opacity(0.85)))
                    }
                    .disabled(busy)

                    if let message {
                        Text(message)
                            .font(.system(size: 10))
                            .foregroundColor(messageOK ? Theme.green : Theme.red)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func row<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(Theme.dim)
                .frame(width: 52, alignment: .leading)
            content()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke.opacity(0.7), lineWidth: 0.5))
    }

    private func save() {
        busy = true
        message = nil
        let body: [String: Any] = [
            "port": slot.port,
            "ip": ip.trimmingCharacters(in: .whitespaces),
            "iport": Int(iport.trimmingCharacters(in: .whitespaces)) ?? 0,
            "on": on
        ]
        Task {
            do {
                let resp = try await NetmonAPI.post("api/natmap", body)
                await MainActor.run {
                    busy = false
                    messageOK = resp.ok
                    message = resp.text
                    onSaved()
                }
            } catch {
                await MainActor.run {
                    busy = false
                    messageOK = false
                    message = error.localizedDescription
                }
            }
        }
    }
}
