import SwiftUI

@main
struct NetmonApp: App {
    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}

enum RootTab: String, CaseIterable, Identifiable {
    case monitor, apps, nat, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monitor: return "监控"
        case .apps: return "应用"
        case .nat: return "映射"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .monitor: return "waveform.path.ecg"
        case .apps: return "square.grid.2x2"
        case .nat: return "arrow.left.arrow.right"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var tab: RootTab = .monitor
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .monitor: DashboardView()
                case .apps: AppsView()
                case .nat: NatView()
                case .settings: SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 82) }

            DockBar(selection: $tab)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
        }
        .environmentObject(model)
        .preferredColorScheme(darkMode ? .dark : .light)
        .onAppear {
            model.startPolling()
            Task { await model.loadRank() }
        }
        .onDisappear { model.stopPolling() }
    }
}

/// 原生 Dock：一条白色半透明胶囊，黑色线性图标 + 小字，
/// 选中项在图标与文字外圈生成一枚液态玻璃气泡（不是整块填充）
struct DockBar: View {
    @Binding var selection: RootTab
    @Namespace private var bubble

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RootTab.allCases) { t in
                let active = selection == t
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                        selection = t
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 18, weight: active ? .semibold : .regular))
                            .symbolRenderingMode(.monochrome)
                        Text(t.title)
                            .font(.system(size: 9.5, weight: active ? .semibold : .regular))
                            .tracking(0.2)
                    }
                    .foregroundColor(active ? Theme.text : Theme.dim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                    .background {
                        if active {
                            Capsule()
                                .fill(Color.clear)
                                .glassEffect(.regular.interactive(), in: .capsule)
                                .matchedGeometryEffect(id: "bubble", in: bubble)
                        }
                    }
                }
                .buttonStyle(DockButtonStyle())
            }
        }
        .padding(5)
        .glassEffect(.regular.interactive(), in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.6))
    }
}

struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
