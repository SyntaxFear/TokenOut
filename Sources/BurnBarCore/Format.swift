import Foundation

/// Display formatting shared by the menu bar and popover.
public enum Format {
    /// "H:MM" until reset, ceiling to the next minute so "0:01" means "under a minute".
    public static func countdown(seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0:00" }
        let totalMinutes = Int((seconds / 60).rounded(.up))
        return "\(totalMinutes / 60):" + String(format: "%02d", totalMinutes % 60)
    }

    public static func countdown(until date: Date, from now: Date = .now) -> String {
        countdown(seconds: date.timeIntervalSince(now))
    }

    /// 950 / 12.4K / 2.3M / 1.0B
    public static func tokens(_ count: Int) -> String {
        let n = Double(count)
        switch count {
        case ..<1_000: return "\(count)"
        case ..<1_000_000: return String(format: "%.1fK", n / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", n / 1_000_000)
        default: return String(format: "%.1fB", n / 1_000_000_000)
        }
    }

    public static func pct(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    public static func usd(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
}
