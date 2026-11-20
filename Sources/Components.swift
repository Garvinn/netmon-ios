import SwiftUI

// MARK: - 背景（深色底 + 极光光晕，与网页 body 一致）

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.12, y: 0.0),
                           startRadius: 4, endRadius: 620)
            RadialGradient(colors: [Theme.purple.opacity(0.13), .clear],
                           center: UnitPoint(x: 1.0, y: 0.18),
                           startRadius: 4, endRadius: 660)
            RadialGradient(colors: [Theme.cyan.opacity(0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 1.05),
                           startRadius: 4, endRadius: 700)
            LinearGradient(colors: [.clear, Theme.bgDeep.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
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
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
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
        .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
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
            Capsule().fill(on ? Theme.green.opacity(0.08) : Color.white.opacity(0.04))
        )
        .overlay(
            Capsule().stroke(on ? Theme.green.opacity(0.35) : Color.white.opacity(0.10), lineWidth: 1)
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
            .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
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
            if let onRefresh = onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(refreshing ? Theme.accent : Theme.sub)
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
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
        .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 14, x: 0, y: 8)
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
                RoundedRectangle(cornerRadius: height / 2).fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(tint)
                    .frame(width: max(2, geo.size.width * CGFloat(min(max(value, 0), 1))))
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
        default: return Color.white.opacity(0.09)
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


// MARK: - Stats 风格卡片（浅色半透明底、细圆角、无渐变）

struct StatsCard<Content: View>: View {
    var padding: CGFloat = 14
    var corner: CGFloat = 10
    let content: Content

    init(padding: CGFloat = 14, corner: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.corner = corner
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Color.white.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - 主数值（Stats topValueView：26pt 细体 + 13pt 细体单位）

struct StatsValue: View {
    let value: String
    var unit: String = ""
    var tint: Color = Theme.text
    var size: CGFloat = 26
    var leading: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .light))
                .foregroundColor(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: max(11, size * 0.5), weight: .light))
                    .foregroundColor(Theme.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }
}

// MARK: - 说明行（Stats bottom caption：12×12 色块 + 11pt 文字）

struct StatsCaption: View {
    let text: String
    var color: Color? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let color = color {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.sub)
                .lineLimit(1)
            if let trailing = trailing, !trailing.isEmpty {
                Spacer(minLength: 4)
                Text(trailing)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Theme.dim)
                    .lineLimit(1)
            }
        }
    }
}
