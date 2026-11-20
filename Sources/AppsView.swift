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
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var services: [NamedStat] {
        (m.apps?.data.services ?? [:])
            .map { NamedStat(name: $0.key, stat: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    title: "应用",
                    subtitle: "容器 \(containers.count) 个 · 服务 \(services.count) 个",
                    onRefresh: { m.reloadApps() },
                    refreshing: m.isRefreshing
                )

                if containers.isEmpty && services.isEmpty {
                    loadingCard
                } else {
                    if !containers.isEmpty {
                        sectionTitle("容器", count: containers.count)
                        AutoGrid(minWidth: 280, spacing: 14) {
                            ForEach(containers) { item in
                                AppMetricCard(name: item.name, stat: item.stat, tag: "容器", tint: Theme.purple)
                            }
                        }
                    }

                    if !services.isEmpty {
                        sectionTitle("系统服务", count: services.count)
                        AutoGrid(minWidth: 280, spacing: 14) {
                            ForEach(services) { item in
                                AppMetricCard(name: item.name, stat: item.stat, tag: "服务", tint: Theme.cyan)
                            }
                        }
                    }
                }
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

    private func sectionTitle(_ text: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(Theme.dim)
            Spacer()
        }
        .padding(.top, 2)
    }

    private var loadingCard: some View {
        WebCard {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("正在读取容器与后台服务…")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.sub)
            }
        }
    }
}

// MARK: - 应用卡（对应网页 .app-card + .app-metrics 2×2）

struct AppMetricCard: View {
    let name: String
    let stat: AppStat
    var tag: String = "容器"
    var tint: Color = Theme.purple

    private var memText: String {
        var parts: [String] = []
        if let p = stat.mem_pct, let v = Double(p), v > 0 {
            parts.append(String(format: "%.1f%%", v))
        }
        if let mem = stat.mem, let first = mem.split(separator: "/").first {
            let trimmed = first.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { parts.append(sizeText(trimmed)) }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private var storeText: String {
        if let store = stat.store, !store.isEmpty { return sizeText(store) }
        if let rw = stat.rw, !rw.isEmpty { return sizeText(rw) }
        return "—"
    }

    private func sizeText(_ raw: String) -> String {
        // 后端给的是 "707.5MB" / "4.1kB" 这类字符串，直接透出即可
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(stat.running ? Theme.green : Theme.red)
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Tag(text: tag, tint: tint)
            }

            Rectangle().fill(Theme.hair).frame(height: 1)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      alignment: .leading, spacing: 8) {
                metricCell("运行", stat.up_text ?? "—")
                metricCell("CPU", stat.cpu ?? "—")
                metricCell("内存", memText)
                metricCell("存储", storeText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
    }

    private func metricCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.dim)
                .tracking(0.4)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(value == "—" ? Theme.dim : Theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
