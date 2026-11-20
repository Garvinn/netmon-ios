import Foundation
import SwiftUI

enum Theme {
    static let bg      = Color(red: 0.043, green: 0.055, blue: 0.078)   // #0b0e14
    static let bgTop   = Color(red: 0.078, green: 0.086, blue: 0.145)   // 顶部渐变
    static let card    = Color.white.opacity(0.055)
    static let stroke  = Color.white.opacity(0.10)
    static let text    = Color(red: 0.914, green: 0.933, blue: 0.984)   // #E9EEFB
    static let sub     = Color(red: 0.667, green: 0.722, blue: 0.824)   // #AAB8D2
    static let dim     = Color(red: 0.420, green: 0.471, blue: 0.565)   // #6B7890
    static let accent  = Color(red: 0.357, green: 0.549, blue: 1.0)     // #5B8CFF
    static let cyan    = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let green   = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let amber   = Color(red: 1.0,   green: 0.749, blue: 0.286)
    static let red     = Color(red: 1.0,   green: 0.435, blue: 0.435)
    static let purple  = Color(red: 0.655, green: 0.545, blue: 1.0)

    static let bgGradient = LinearGradient(
        colors: [bgTop, bg, bg],
        startPoint: .top, endPoint: .bottom
    )

    static let downGradient = LinearGradient(
        colors: [cyan.opacity(0.55), cyan.opacity(0.05)],
        startPoint: .top, endPoint: .bottom
    )

    static let upGradient = LinearGradient(
        colors: [purple.opacity(0.45), purple.opacity(0.04)],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - 数值格式化（与 index.html 的 fmt / fmtSize 保持一致）

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

    static func time(_ ms: Double) -> String {
        let d = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }

    static func ago(_ sec: Double?) -> String {
        guard let s = sec else { return "-" }
        if s < 60 { return "\(Int(s)) 秒前" }
        if s < 3600 { return "\(Int(s / 60)) 分钟前" }
        if s < 86400 { return "\(Int(s / 3600)) 小时前" }
        return "\(Int(s / 86400)) 天前"
    }
}
