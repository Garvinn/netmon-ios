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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                listCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(
            AppBackground()
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(
                title: "设备",
                subtitle: "在线 \(m.snap?.online ?? 0) / 共 \(m.snap?.total ?? 0) 台",
                onRefresh: { Task { await m.refreshAll() } },
                refreshing: m.isRefreshing
            )

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.dim)
                    TextField("搜索 名称 / IP / MAC", text: $q)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))

                Menu {
                    Button("按速率排序") { sort = 0 }
                    Button("按名称排序") { sort = 1 }
                    Button("在线优先") { sort = 2 }
                } label: {
                    HStack(spacing: 5) {
                        Text(["速率", "名称", "在线"][sort])
                        Image(systemName: "chevron.down").font(.system(size: 9))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
            }
        }
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 8) {
                Text("设备").frame(maxWidth: .infinity, alignment: .leading)
                Text("连接").frame(width: 62, alignment: .leading)
                Text("下行").frame(width: 82, alignment: .trailing)
                Text("上行").frame(width: 82, alignment: .trailing)
                Text("累计").frame(width: 96, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.dim)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.03))

            Rectangle().fill(Theme.hair).frame(height: 1)

            ForEach(devices) { d in
                DeviceTableRow(d: d)
                Rectangle().fill(Theme.hair).frame(height: 1)
            }

            if devices.isEmpty {
                Text("没有匹配的设备")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.sub)
                    .padding(.vertical, 22)
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
    }
}

// MARK: - 设备行（对应网页 table 行）

struct DeviceTableRow: View {
    let d: Device

    private var wired: Bool {
        let t = (d.conn_type ?? "").lowercased()
        return t.contains("wire") || t.contains("eth") || (!t.contains("wifi") && !t.contains("wl"))
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(d.online ? Theme.green : Theme.dim.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(d.online ? Theme.text : Theme.sub)
                        .lineLimit(1)
                    if d.blocked == true {
                        Tag(text: "已禁外网", tint: Theme.red)
                    }
                    if let limit = d.limit, limit > 0 {
                        Tag(text: "限 \(Int(limit))M", tint: Theme.amber)
                    }
                }
                Text(subLine)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(wired ? "有线" : "无线")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(wired ? Theme.green : Theme.purple)
                .frame(width: 62, alignment: .leading)

            Text(Fmt.rate(d.down))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.blue)
                .monospacedDigit()
                .frame(width: 82, alignment: .trailing)

            Text(Fmt.rate(d.up))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.orange)
                .monospacedDigit()
                .frame(width: 82, alignment: .trailing)

            Text(Fmt.size(d.total_in + d.total_out))
                .font(.system(size: 12))
                .foregroundColor(Theme.sub)
                .monospacedDigit()
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var displayName: String {
        let n = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        if !d.raw.isEmpty { return d.raw }
        return d.mac.isEmpty ? d.ip : d.mac
    }

    private var subLine: String {
        var parts: [String] = []
        if !d.ip.isEmpty { parts.append(d.ip) }
        if !d.mac.isEmpty { parts.append(d.mac) }
        if !d.online, let last = d.last { parts.append(Fmt.ago(last)) }
        return parts.joined(separator: " · ")
    }
}
