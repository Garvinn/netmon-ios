import SwiftUI

// MARK: - 背景（浅灰底，极淡的冷暖过渡，与 NasPulse 一致）

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            LinearGradient(colors: [Theme.bgDeep.opacity(0.6), Theme.bg.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
            // 静态柔光：不用 blur，避免滚动时每帧重算
            GeometryReader { geo in
                ZStack {
                    RadialGradient(colors: [Theme.accent.opacity(0.20), .clear],
                                   center: .center, startRadius: 0,
                                   endRadius: geo.size.width * 0.62)
                        .frame(width: geo.size.width * 1.3, height: geo.size.width * 1.3)
                        .position(x: geo.size.width * 0.16, y: geo.size.height * 0.14)
                    RadialGradient(colors: [Theme.purple.opacity(0.18), .clear],
                                   center: .center, startRadius: 0,
                                   endRadius: geo.size.width * 0.58)
                        .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                        .position(x: geo.size.width * 0.92, y: geo.size.height * 0.42)
                    RadialGradient(colors: [Theme.cyan.opacity(0.14), .clear],
                                   center: .center, startRadius: 0,
                                   endRadius: geo.size.width * 0.55)
                        .frame(width: geo.size.width * 1.1, height: geo.size.width * 1.1)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.92)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// 原生 Liquid Glass 底板（iOS 26 glassEffect）
struct GlassPanel: ViewModifier {
    var radius: CGFloat = 16
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .glassEffect(
                tint == nil ? .regular : .regular.tint(tint!.opacity(0.18)),
                in: .rect(cornerRadius: radius)
            )
    }
}

extension View {
    func glassPanel(radius: CGFloat = 16, tint: Color? = nil) -> some View {
        modifier(GlassPanel(radius: radius, tint: tint))
    }
}

// MARK: - 玻璃卡片（网页 .card / .stat）

struct WebCard<Content: View>: View {
    var padding: CGFloat
    var radius: CGFloat
    let content: Content

    init(padding: CGFloat = 18, radius: CGFloat = Theme.radius, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(radius: radius)
    }
}

/// 带标题栏的卡片：h3 14px 600 + 右侧 sub
struct PanelCard<Content: View, Trailing: View>: View {
    let title: String
    var sub: String? = nil
    var radius: CGFloat = Theme.radius
    let trailing: () -> Trailing
    let content: () -> Content

    init(title: String, sub: String? = nil, radius: CGFloat = Theme.radius,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.sub = sub
        self.radius = radius
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer(minLength: 6)
                if let sub = sub {
                    Text(sub).font(.system(size: 12)).foregroundColor(Theme.dim)
                }
                trailing()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .overlay(
                Rectangle().fill(Theme.hair).frame(height: 1),
                alignment: .bottom
            )
            content().padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: radius)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension PanelCard where Trailing == EmptyView {
    init(title: String, sub: String? = nil, radius: CGFloat = Theme.radius, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, sub: sub, radius: radius, trailing: { EmptyView() }, content: content)
    }
}

// MARK: - 顶部胶囊（网页 .pill）

struct Pill: View {
    let text: String
    var tint: Color = Theme.sub
    var dot: Bool = true
    var on: Bool = false
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if dot {
                Circle()
                    .fill(dotColor ?? (on ? Theme.green : Theme.dim))
                    .frame(width: 7, height: 7)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(on ? Theme.green.opacity(0.08) : Theme.fillSoft)
        )
        .overlay(
            Capsule().stroke(on ? Theme.green.opacity(0.35) : Theme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - 兼容旧调用：玻璃卡片 / 小标题

struct GlassCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(radius: Theme.radius)
    }
}

struct CardTitle: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 页面标题栏（网页 topbar：h1 19px 700 + sub 11px）

struct PageHeader: View {
    let title: String
    var subtitle: String? = nil
    var onRefresh: (() -> Void)? = nil
    var refreshing: Bool = false
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Theme.text)
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    darkMode.toggle()
                }
            } label: {
                Image(systemName: darkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.sub)
                    .frame(width: 38, height: 38)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            if let onRefresh = onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(refreshing ? Theme.accent : Theme.sub)
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.fillSoft))
                        .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - 指标块（网页 .stat）

struct StatCard: View {
    let label: String
    var dotColor: Color = Theme.accent
    var value: String
    var unit: String = ""
    var note: String? = nil
    var tint: Color = Theme.text
    var arrow: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let arrow = arrow {
                    Text(arrow)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(tint)
                }
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(tint)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tint.opacity(0.9))
                }
            }
            if let note = note {
                Text(note)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: Theme.radius)
    }
}

// MARK: - 进度条

struct MiniProgress: View {
    var value: Double          // 0...1
    var tint: Color = Theme.green
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.fillMid)
                    .overlay(Capsule().fill(
                        LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.65)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().fill(
                        LinearGradient(colors: [Color.white.opacity(0.45), .clear],
                                       startPoint: .top, endPoint: .center)))
                    .frame(width: max(2, geo.size.width * CGFloat(min(max(value, 0), 1))),
                           height: height)
                    .shadow(color: tint.opacity(0.35), radius: 3, y: 1)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 状态点

struct Dot: View {
    var on: Bool
    var color: Color = Theme.green
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(on ? color : Theme.dim.opacity(0.7))
            .frame(width: size, height: size)
            .shadow(color: on ? color.opacity(0.7) : .clear, radius: 4)
    }
}

// MARK: - 标签

struct Tag: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.16)))
    }
}

// MARK: - 排行行（网页 .rk-row：渐变条 + 名次徽标 + 名称 + 次数）

struct RankRow: View {
    let index: Int
    let main: String
    let sub: String?
    let count: String
    let unitText: String
    let ratio: Double          // 0...1

    private var noFill: Color {
        switch index {
        case 0: return Color(red: 1.0, green: 0.25, blue: 0.41).opacity(0.28)
        case 1: return Color(red: 1.0, green: 0.59, blue: 0.24).opacity(0.26)
        case 2: return Color(red: 1.0, green: 0.84, blue: 0.35).opacity(0.24)
        default: return Theme.fillMid
        }
    }
    private var noText: Color {
        switch index {
        case 0: return Color(red: 1.0, green: 0.75, blue: 0.81)
        case 1: return Color(red: 1.0, green: 0.82, blue: 0.66)
        case 2: return Color(red: 1.0, green: 0.91, blue: 0.65)
        default: return Theme.sub
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.24), Theme.accent.opacity(0.03)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * CGFloat(min(max(ratio, 0), 1))))
            }
            HStack(spacing: 9) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(noText)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 6).fill(noFill))
                VStack(alignment: .leading, spacing: 1) {
                    Text(main)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    if let sub = sub, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.sub)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 3) {
                    Text(count)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.text)
                        .monospacedDigit()
                    Text(unitText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.sub)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
        }
        .frame(height: 40)
    }
}

// MARK: - 迷你列表行

struct MiniItemRow: View {
    let name: String
    var sub: String? = nil
    var right: String = ""
    var rightColor: Color = Theme.text
    var dotOn: Bool? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let dotOn = dotOn {
                Circle().fill(dotOn ? Theme.green : Theme.dim.opacity(0.7)).frame(width: 6, height: 6)
            }
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(1)
            if let sub = sub {
                Text(sub).font(.system(size: 11)).foregroundColor(Theme.dim).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(right)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(rightColor)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - 自适应网格（对应网页 auto-fill grid）

struct AutoGrid<Item: View>: View {
    var minWidth: CGFloat = 330
    var spacing: CGFloat = 16
    let content: () -> Item

    init(minWidth: CGFloat = 330, spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Item) {
        self.minWidth = minWidth
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: spacing)], spacing: spacing) {
            content()
        }
    }
}

// MARK: - NasPulse 卡片：彩色图标 + 标题 + 右侧状态点

struct PulseCard<Content: View>: View {
    let icon: String
    let title: String
    var accent: Color
    var status: String?
    var statusOK: Bool
    var padding: CGFloat
    let content: Content

    init(icon: String,
         title: String,
         accent: Color = Theme.accent,
         status: String? = nil,
         statusOK: Bool = true,
         padding: CGFloat = 12,
         @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.status = status
        self.statusOK = statusOK
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accent.opacity(0.16))
                    Image(systemName: icon)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(accent)
                }
                .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if let status = status, !status.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusOK ? Theme.green : Theme.orange)
                            .frame(width: 5, height: 5)
                        Text(status)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(statusOK ? Theme.green : Theme.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }

            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(radius: 14)
    }
}

// MARK: - 小标签（NasPulse 的 CPU LOAD / MEMORY 这种大写说明）

struct PulseLabel: View {
    let text: String
    var trailing: String? = nil
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(tint ?? Theme.dim)
                .lineLimit(1)
            if let trailing = trailing, !trailing.isEmpty {
                Spacer(minLength: 4)
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 主数值（粗体数字 + 小单位）

struct PulseValue: View {
    let value: String
    var unit: String = ""
    var tint: Color = Theme.text
    var size: CGFloat = 26
    var leading: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .heavy))
                .foregroundColor(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: max(11, size * 0.45), weight: .semibold))
                    .foregroundColor(Theme.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }
}

// MARK: - 小药丸（存储池 / 容器状态这类）

struct PulseChip: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - 安全类排行行（来源 IP / 扫描端口）

struct PulseRankRow: View {
    let index: Int
    let main: String
    var sub: String? = nil
    var right: String = ""
    var unit: String = ""
    var ratio: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.sub)
                .frame(width: 16, height: 16)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.fillSoft))
            VStack(alignment: .leading, spacing: 1) {
                Text(main)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let sub = sub, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                Text(right)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.text)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.sub)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 7)
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: max(8, geo.size.width * CGFloat(min(max(ratio, 0), 1))))
            }
        )
        .overlay(Rectangle().fill(Theme.hair).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - 原生玻璃分段控件（统一时间窗口 / 其它切换）

struct GlassRangeBar: View {
    let options: [(key: String, label: String)]
    @Binding var selection: String
    var loading: Bool = false
    var onChange: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(options, id: \.key) { opt in
                    let active = selection == opt.key
                    Button {
                        guard !active else { return }
                        selection = opt.key
                        onChange(opt.key)
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 12.5, weight: active ? .semibold : .medium))
                            .foregroundColor(active ? Color.white : Theme.sub)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(active
                                 ? .regular.tint(Theme.accent.opacity(0.55)).interactive()
                                 : .clear.interactive(),
                                 in: .rect(cornerRadius: 10))
                }
                if loading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.accent)
                        .padding(.trailing, 8)
                        .transition(.opacity)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
    }
}

// MARK: - 原生玻璃切换按钮（日/夜等二态）

struct GlassToggle: View {
    let icon: String
    var tint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .glassEffect(.regular.tint(tint.opacity(0.14)).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}
