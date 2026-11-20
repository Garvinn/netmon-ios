import SwiftUI

// MARK: - 玻璃卡片

struct GlassCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

// MARK: - 小标题

struct CardTitle: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.sub)
                .tracking(0.4)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 指标块

struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    var tint: Color = Theme.accent
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.sub)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 0.6)
        )
    }
}

// MARK: - 进度条

struct MiniProgress: View {
    let value: Double          // 0...1
    var tint: Color = Theme.accent
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Capsule()
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
            .fill(on ? color : Theme.dim)
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
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.14))
            )
    }
}

// MARK: - 主背景（深色 + 轻微顶部光晕，跟网页版一致）

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Theme.accent.opacity(0.13), .clear],
                center: .topLeading, startRadius: 10, endRadius: 420
            )
            RadialGradient(
                colors: [Theme.purple.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 10, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}
