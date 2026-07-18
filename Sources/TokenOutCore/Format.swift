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

    /// Human-friendly countdown: "1 h 50 m", "3 d 9 h", "50 m", "under 1 m".
    /// Two units max — precision beyond that is noise in a menu bar app.
    public static func humanCountdown(seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "under 1 m" }
        let totalMinutes = Int((seconds / 60).rounded(.up))
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days) d \(hours) h" : "\(days) d" }
        if hours > 0 { return minutes > 0 ? "\(hours) h \(minutes) m" : "\(hours) h" }
        return "\(minutes) m"
    }

    public static func humanCountdown(until date: Date, from now: Date = .now) -> String {
        humanCountdown(seconds: date.timeIntervalSince(now))
    }

    /// The wall-clock moment a limit resets: "5:30 PM" today, "Tue 5:30 PM"
    /// within a week, else "Jul 21, 5:30 PM" — enough context, no more.
    public static func resetClock(_ date: Date, now: Date = .now,
                                  calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if date.timeIntervalSince(now) < 7 * 86_400 {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            return "\(weekday) \(time)"
        }
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return "\(day), \(time)"
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
