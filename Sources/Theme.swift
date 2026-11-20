import Foundation
import SwiftUI

// MARK: - 设计令牌（严格对齐 index.html 的 CSS 变量）

enum Theme {
    static let bg      = Color(red: 0.027, green: 0.039, blue: 0.067)   // #070a11 页面底色
    static let bgDeep  = Color(red: 0.016, green: 0.024, blue: 0.043)   // 极光底部

    static let text    = Color(red: 0.914, green: 0.933, blue: 0.984)   // #E9EEFB
    static let sub     = Color(red: 0.667, green: 0.722, blue: 0.824)   // #AAB8D2
    static let dim     = Color(red: 0.545, green: 0.576, blue: 0.655)   // #8B93A7

    static let accent  = Color(red: 0.357, green: 0.549, blue: 1.0)     // #5B8CFF
    static let blue    = Color(red: 0.231, green: 0.655, blue: 1.0)     // #3BA7FF 下行
    static let orange  = Color(red: 1.0,   green: 0.624, blue: 0.110)   // #FF9F1C 上行
    static let cyan    = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let green   = Color(red: 0.063, green: 0.725, blue: 0.506)   // #10B981
    static let amber   = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let red     = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
    static let purple  = Color(red: 0.658, green: 0.333, blue: 0.969)   // #A855F7
    static let pink    = Color(red: 1.0,   green: 0.271, blue: 0.412)

    static let stroke  = Color.white.opacity(0.08)
    static let hair    = Color.white.opacity(0.06)

    // 卡片：linear-gradient(160deg, rgba(255,255,255,.06), rgba(255,255,255,.025))
    static let cardFill = LinearGradient(
        colors: [Color.white.opacity(0.065), Color.white.opacity(0.025)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 18
    static let radiusBig: CGFloat = 24
    static let shadow = Color.black.opacity(0.22)
}

// MARK: - 数值格式化（与 index.html 的 fmt / fmtSize 一致）

enum Fmt {
    static func rate(_ b: Double) -> String {
        if b >= 1_048_576 { return String(format: "%.1f MB/s", b / 1_048_576) }
        if b >= 1024 { return "\(Int((b / 1024).rounded())) KB/s" }
        return "\(Int(b.rounded())) B/s"
    }

    static func rateValue(_ b: Double) -> String {
        if b >= 1_048_576 { return String(format: "%.1f", b / 1_048_576) }
        if b >= 1024 { return "\(Int((b / 1024).rounded()))" }
        return "\(Int(b.rounded()))"
    }

    static func rateUnit(_ b: Double) -> String {
        if b >= 1_048_576 { return "MB/s" }
        if b >= 1024 { return "KB/s" }
        return "B/s"
    }

    /// 每秒字节数 → 小字（网页里 stat 下方的 mono 一行）
    static func bps(_ b: Double) -> String {
        if b >= 1_048_576 { return String(format: "%.2f MBytes/s", b / 1_048_576) }
        if b >= 1024 { return String(format: "%.1f KBytes/s", b / 1024) }
        return "\(Int(b.rounded())) Bytes/s"
    }

    static func size(_ b: Double) -> String {
        if b >= 1_073_741_824 { return String(format: "%.2f GB", b / 1_073_741_824) }
        if b >= 1_048_576 { return String(format: "%.1f MB", b / 1_048_576) }
        if b >= 1024 { return "\(Int((b / 1024).rounded())) KB" }
        return "\(Int(b)) B"
    }

    static func count(_ v: Double) -> String {
        if v >= 10_000 { return String(format: "%.1f 万", v / 10_000) }
        return "\(Int(v))"
    }

    static func pct(_ v: Double) -> String {
        String(format: "%.1f%%", v)
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    static func time(_ ms: Double) -> String {
        clock(Date(timeIntervalSince1970: ms / 1000))
    }

    static func ago(_ sec: Double?) -> String {
        guard let s = sec else { return "-" }
        if s < 60 { return "\(Int(s)) 秒前" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        if s < 86400 { return "\(Int(s / 3600)) 小时前" }
        return "\(Int(s / 86400)) 天前"
    }

    static func rangeLabel(_ r: String) -> String {
        switch r {
        case "1": return "24 小时"
        case "7": return "7 天"
        case "30": return "30 天"
        default: return "1 年"
        }
    }
}
