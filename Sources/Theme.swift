import Foundation
import SwiftUI
import UIKit

/// 随系统深浅色自动切换的颜色令牌
private func dyn(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? dark : light
    })
}

// MARK: - 设计令牌（浅色 NasPulse 风；深色为同结构的夜间配色）

enum Theme {
    static let bg      = dyn(UIColor(red: 0.945, green: 0.957, blue: 0.972, alpha: 1),
                             UIColor(red: 0.055, green: 0.063, blue: 0.078, alpha: 1))   // #F1F4F8 / #0E1014
    static let bgDeep  = dyn(.white, UIColor(red: 0.094, green: 0.106, blue: 0.125, alpha: 1))

    static let text    = dyn(UIColor(red: 0.078, green: 0.086, blue: 0.110, alpha: 1),
                             UIColor(red: 0.945, green: 0.953, blue: 0.965, alpha: 1))
    static let sub     = dyn(UIColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1),
                             UIColor(red: 0.635, green: 0.663, blue: 0.706, alpha: 1))
    static let dim     = dyn(UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1),
                             UIColor(red: 0.478, green: 0.502, blue: 0.545, alpha: 1))

    static let accent  = Color(red: 0.145, green: 0.388, blue: 0.922)   // #2563EB
    static let accent2 = Color(red: 0.055, green: 0.647, blue: 0.914)   // #0EA5E9
    static let blue    = Color(red: 0.145, green: 0.388, blue: 0.922)   // #2563EB 下行
    static let orange  = Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B 上行
    static let cyan    = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06B6D4
    static let green   = Color(red: 0.063, green: 0.725, blue: 0.506)   // #10B981
    static let amber   = Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B
    static let red     = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
    static let purple  = Color(red: 0.486, green: 0.361, blue: 0.988)   // #7C5CFC
    static let pink    = Color(red: 0.925, green: 0.282, blue: 0.600)   // #EC4899

    static let stroke  = dyn(UIColor(red: 0.898, green: 0.914, blue: 0.937, alpha: 1),
                             UIColor(red: 0.208, green: 0.227, blue: 0.255, alpha: 1))
    static let hair    = dyn(UIColor(red: 0.929, green: 0.941, blue: 0.957, alpha: 1),
                             UIColor(red: 0.169, green: 0.184, blue: 0.208, alpha: 1))

    /// 卡片内部再分区用的底色
    static let fillSoft = dyn(UIColor(red: 0.957, green: 0.965, blue: 0.976, alpha: 1),
                              UIColor(white: 1, alpha: 0.06))
    static let fillMid  = dyn(UIColor(red: 0.918, green: 0.933, blue: 0.953, alpha: 1),
                              UIColor(white: 1, alpha: 0.10))

    // 卡片：纯白，靠 1px 描边和极淡投影分层
    static let cardFill = LinearGradient(
        colors: [Color.white, Color.white],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 16
    static let radiusBig: CGFloat = 20
    static let shadow = Color.black.opacity(0.05)
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
