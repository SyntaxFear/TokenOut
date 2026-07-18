import Foundation
import UserNotifications
import TokenOutCore

/// Warns at 80% and 95% per window, once per reset cycle.
/// No-ops outside a proper .app bundle (UNUserNotificationCenter requires one).
@MainActor
final class Notifier {
    private var notified: Set<String> = []

    private var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func requestAuthorization() {
        guard isBundled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private var lastFractions: [String: Double] = [:]

    func evaluate(snapshot: UsageSnapshot, displayName: String,
                  warningThreshold: Double, criticalThreshold: Double,
                  refillNotifications: Bool) {
        guard isBundled else { return }
        // Refill detection: a big downward jump from a loaded window means it reset.
        for window in snapshot.windows {
            let key = "\(snapshot.providerID.rawValue)|\(window.label)"
            if refillNotifications, let previous = lastFractions[key],
               previous >= 0.5, window.usedFraction < previous - 0.3 {
                let content = UNMutableNotificationContent()
                content.title = "\(displayName) \(window.label) refilled"
                content.body = "Usage is back to \(Format.pct(window.usedFraction))."
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: UUID().uuidString,
                                          content: content, trigger: nil))
            }
            lastFractions[key] = window.usedFraction
        }
        let thresholds = [warningThreshold, criticalThreshold]
        for window in snapshot.windows {
            for threshold in thresholds where window.usedFraction >= threshold {
                let cycle = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "static"
                let key = "\(snapshot.providerID.rawValue)|\(window.label)|\(threshold)|\(cycle)"
                guard !notified.contains(key) else { continue }
                notified.insert(key)
                post(provider: displayName, window: window, threshold: threshold,
                     criticalThreshold: criticalThreshold)
            }
        }
        if notified.count > 400 { notified.removeAll() }  // old reset cycles never recur
    }

    private func post(provider: String, window: LimitWindow, threshold: Double,
                      criticalThreshold: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(provider) \(window.label) at \(Format.pct(window.usedFraction))"
        if let resetsAt = window.resetsAt {
            content.body = "Refills in \(Format.countdown(until: resetsAt))."
        } else {
            content.body = threshold >= criticalThreshold ? "Almost at the limit." : "Usage is climbing quickly."
        }
        content.sound = threshold >= criticalThreshold ? .default : nil
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
