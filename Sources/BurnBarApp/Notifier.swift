import Foundation
import UserNotifications
import BurnBarCore

/// Warns at 80% and 95% per window, once per reset cycle.
/// No-ops outside a proper .app bundle (UNUserNotificationCenter requires one).
@MainActor
final class Notifier {
    private var notified: Set<String> = []
    private let thresholds: [Double] = [0.8, 0.95]

    private var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorization() {
        guard isBundled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private var lastFractions: [String: Double] = [:]

    func evaluate(snapshot: UsageSnapshot, displayName: String) {
        guard isBundled else { return }
        // Refill detection: a big downward jump from a loaded window means it reset.
        for window in snapshot.windows {
            let key = "\(snapshot.providerID.rawValue)|\(window.label)"
            if let previous = lastFractions[key],
               previous >= 0.5, window.usedFraction < previous - 0.3 {
                let content = UNMutableNotificationContent()
                content.title = "\(displayName) \(window.label) refilled 🔥"
                content.body = "Back to \(Format.pct(window.usedFraction)) — burn away."
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: UUID().uuidString,
                                          content: content, trigger: nil))
            }
            lastFractions[key] = window.usedFraction
        }
        for window in snapshot.windows {
            for threshold in thresholds where window.usedFraction >= threshold {
                let cycle = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "static"
                let key = "\(snapshot.providerID.rawValue)|\(window.label)|\(threshold)|\(cycle)"
                guard !notified.contains(key) else { continue }
                notified.insert(key)
                post(provider: displayName, window: window, threshold: threshold)
            }
        }
        if notified.count > 400 { notified.removeAll() }  // old reset cycles never recur
    }

    private func post(provider: String, window: LimitWindow, threshold: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(provider) \(window.label) at \(Format.pct(window.usedFraction))"
        if let resetsAt = window.resetsAt {
            content.body = "Refills in \(Format.countdown(until: resetsAt))."
        } else {
            content.body = threshold >= 0.95 ? "Running on empty." : "Burning fast."
        }
        content.sound = threshold >= 0.95 ? .default : nil
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
