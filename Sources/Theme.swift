import Foundation
import SwiftUI

// MARK: - 设计令牌（严格对齐 index.html 的 CSS 变量）

enum Theme {
    static let bg      = Color(red: 0.043, green: 0.055, blue: 0.078)   // #0b0e14
    static let bgDeep  = Color(red: 0.063, green: 0.078, blue: 0.114)   // #10141d

    static let text    = Color(red: 0.910, green: 0.929, blue: 0.961)   // #e8edf5
    static let sub     = Color(red: 0.604, green: 0.655, blue: 0.741)   // #9aa7bd
    static let dim     = Color(red: 0.420, green: 0.471, blue: 0.565)   // #6b7890

    static let accent  = Color(red: 0.231, green: 0.655, blue: 1.0)     // #3ba7ff
    static let accent2 = Color(red: 0.133, green: 0.827, blue: 0.933)   // #22d3ee
    static let blue    = Color(red: 0.243, green: 0.420, blue: 1.0)     // #3E6BFF 下行
    static let orange  = Color(red: 1.0,   green: 0.624, blue: 0.110)   // #FF9F1C 上行
    static let cyan    = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06b6d4
    static let green   = Color(red: 0.122, green: 0.749, blue: 0.459)   // #1FBF75
    static let amber   = Color(red: 0.961, green: 0.620, blue: 0.043)   // #f59e0b
    static let red     = Color(red: 0.937, green: 0.267, blue: 0.267)   // #ef4444
    static let purple  = Color(red: 0.658, green: 0.333, blue: 0.969)   // #a855f7
    static let pink    = Color(red: 1.0,   green: 0.271, blue: 0.412)

    static let stroke  = Color.white.opacity(0.08)
    static let hair    = Color.white.opacity(0.07)

    // 卡片：linear-gradient(160deg, rgba(255,255,255,.06), rgba(255,255,255,.025))
    static let cardFill = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.025)],
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
