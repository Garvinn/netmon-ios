import SwiftUI

@main
struct NetmonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

enum RootTab: String, CaseIterable, Identifiable {
    case monitor, devices, apps, security, nat, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monitor: return "监控"
        case .devices: return "设备"
        case .apps: return "应用"
        case .security: return "安全"
        case .nat: return "映射"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .monitor: return "waveform.path.ecg"
        case .devices: return "dot.radiowaves.left.and.right"
        case .apps: return "square.grid.2x2"
        case .security: return "shield.lefthalf.filled"
        case .nat: return "arrow.left.arrow.right"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var tab: RootTab = .monitor

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .monitor: DashboardView()
                case .devices: DevicesView()
                case .apps: AppsView()
                case .security: SecurityView()
                case .nat: NatView()
                case .settings: SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 76) }

            DockBar(selection: $tab)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
        }
        .environmentObject(model)
        .onAppear {
            model.startPolling()
            Task { await model.loadRank() }
        }
        .onDisappear { model.stopPolling() }
    }
}

/// iOS 26 风格悬浮玻璃 Dock：胶囊底板、选中态高亮、无分割线
struct DockBar: View {
    @Binding var selection: RootTab

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(RootTab.allCases) { t in
                    let active = selection == t
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = t }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon)
                                .font(.system(size: 17, weight: active ? .bold : .medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(active ? Theme.accent : Theme.sub.opacity(0.85))
                            Text(t.title)
                                .font(.system(size: 9.5, weight: active ? .semibold : .regular))
                                .foregroundColor(active ? Theme.accent : Theme.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(DockButtonStyle())
                    .glassEffect(active ? .regular.tint(Theme.accent.opacity(0.28)).interactive()
                                        : .regular.interactive(),
                                 in: .rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}

struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
