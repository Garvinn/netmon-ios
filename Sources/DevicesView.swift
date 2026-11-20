import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var m: AppModel
    @State private var q = ""
    @State private var sort = 0

    private var devices: [Device] {
        var arr = m.snap?.devices ?? []
        if !q.isEmpty {
            arr = arr.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                || $0.ip.contains(q)
                || $0.mac.localizedCaseInsensitiveContains(q)
            }
        }
        switch sort {
        case 0: arr.sort { ($0.down + $0.up) > ($1.down + $1.up) }
        case 1: arr.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        default: arr.sort { (($0.online ? 1 : 0) > ($1.online ? 1 : 0)) }
        }
        return arr
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                PageHeader(
                    title: "设备",
                    subtitle: "在线 \(m.snap?.online ?? 0) / 共 \(m.snap?.total ?? 0)",
                    refreshing: m.isRefreshing
                ) {
                    Task { await m.refreshAll() }
                }
                .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.dim)
                        TextField("搜索名称 / IP / MAC", text: $q)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text)
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.stroke, lineWidth: 0.6))

                    Menu {
                        Button("按速率") { sort = 0 }
                        Button("按名称") { sort = 1 }
                        Button("按在线优先") { sort = 2 }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.sub)
                            .padding(9)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 14)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(devices) { d in
                            DeviceRow(device: d)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Dot(on: device.online, color: device.blocked == true ? Theme.red : Theme.green)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if device.blocked == true { Tag(text: "禁网", tint: Theme.red) }
                    if let limit = device.limit, limit > 0 { Tag(text: "限速 \(Int(limit))M", tint: Theme.amber) }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 5) {
                    Text(device.ip)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.sub)
                    Text("·").foregroundColor(Theme.dim).font(.system(size: 10))
                    Text(device.conn ?? device.conn_type ?? "")
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.dim)
                    Spacer(minLength: 0)
                    if !device.online {
                        Text(Fmt.ago(device.last))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.dim)
                    }
                }
                HStack(spacing: 10) {
                    rateItem(icon: "arrow.down", value: device.down, tint: Theme.cyan)
                    rateItem(icon: "arrow.up", value: device.up, tint: Theme.purple)
                    Spacer(minLength: 0)
                    Text("累计 ↓\(Fmt.size(device.total_in)) ↑\(Fmt.size(device.total_out))")
                        .font(.system(size: 9.5))
                        .foregroundColor(Theme.dim)
                }
            }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 0.6))
        .opacity(device.online ? 1 : 0.62)
    }

    private func rateItem(icon: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8.5))
                .foregroundColor(tint)
            Text(Fmt.rate(value))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(value > 0 ? Theme.text : Theme.dim)
        }
    }
}
