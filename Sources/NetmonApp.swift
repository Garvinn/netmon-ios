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

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("监控", systemImage: "waveform.path.ecg") }
            DevicesView()
                .tabItem { Label("设备", systemImage: "dot.radiowaves.left.and.right") }
            AppsView()
                .tabItem { Label("应用", systemImage: "square.grid.2x2") }
            NatView()
                .tabItem { Label("映射", systemImage: "arrow.left.arrow.right") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .environmentObject(model)
        .accentColor(Theme.accent)
        .onAppear {
            model.startPolling()
            Task { await model.loadRank() }
        }
        .onDisappear { model.stopPolling() }
    }
}
