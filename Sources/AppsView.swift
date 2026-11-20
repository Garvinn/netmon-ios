import SwiftUI

struct NamedStat: Identifiable {
    var id: String { name }
    let name: String
    let stat: AppStat
}

struct AppsView: View {
    @EnvironmentObject var m: AppModel

    private var containers: [NamedStat] {
        (m.apps?.data.containers ?? [:])
            .map { NamedStat(name: $0.key, stat: $0.value) }
            .sorted { $0.name < $1.name }
    }
    private var services: [NamedStat] {
        (m.apps?.data.services ?? [:])
            .map { NamedStat(name: $0.key, stat: $0.value) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    PageHeader(
                        title: "应用",
                        subtitle: "容器 \(containers.count) 个 · 服务 \(services.count) 个",
                        refreshing: m.isRefreshing
                    ) {
                        Task { await m.refreshAll() }
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(containers) { item in
                            AppCard(name: item.name, stat: item.stat)
                        }
                    }

                    if !services.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                CardTitle(text: "系统服务", icon: "gearshape.2")
                                ForEach(services) { item in
                                    ServiceRow(name: item.name, stat: item.stat)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 26)
            }
        }
    }
}

struct AppCard: View {
    let name: String
    let stat: AppStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Dot(on: stat.running)
                Text(name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(stat.up_text ?? (stat.running ? "运行中" : "已停止"))
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .lineLimit(1)

            divider

            metric(label: "CPU", value: stat.cpu ?? "-", fraction: min(stat.cpuValue / 100, 1), tint: Theme.amber)
            metric(label: "内存", value: stat.mem_pct ?? "-", fraction: min(stat.memPercent / 100, 1), tint: Theme.green)
            metric(label: "存储", value: stat.store ?? "-", fraction: 0, tint: Theme.accent)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Theme.stroke, lineWidth: 0.6))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5)
    }

    private func metric(label: String, value: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 9.5)).foregroundColor(Theme.dim)
                Spacer(minLength: 2)
                Text(value)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if fraction > 0 {
                MiniProgress(value: fraction, tint: tint, height: 2.5)
            }
        }
    }
}

struct ServiceRow: View {
    let name: String
    let stat: AppStat

    var body: some View {
        HStack(spacing: 8) {
            Dot(on: true, size: 6)
            Text(name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Theme.text)
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)
            Text(stat.up_text ?? "-")
                .font(.system(size: 9.5))
                .foregroundColor(Theme.dim)
                .frame(width: 74, alignment: .leading)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(stat.cpu ?? "-")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Theme.amber)
                .frame(width: 46, alignment: .trailing)
            Text(stat.mem ?? "-")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(Theme.green)
                .frame(width: 62, alignment: .trailing)
        }
    }
}
