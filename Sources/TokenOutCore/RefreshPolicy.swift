import Foundation

/// Pure cadence math: hot when any window is half-used, backed off on failures.
public struct RefreshPolicy: Sendable {
    public var hotInterval: TimeInterval
    public var coldInterval: TimeInterval
    public var maxInterval: TimeInterval

    public init(hotInterval: TimeInterval = 60, coldInterval: TimeInterval = 300,
                maxInterval: TimeInterval = 900) {
        self.hotInterval = hotInterval
        self.coldInterval = coldInterval
        self.maxInterval = maxInterval
    }

    public func interval(maxUtilization: Double, consecutiveFailures: Int) -> TimeInterval {
        let base = maxUtilization >= 0.5 ? hotInterval : coldInterval
        let backoff = base * pow(2, Double(max(0, consecutiveFailures)))
        return min(backoff, maxInterval)
    }

    /// Deterministic-input jitter multiplier in [0.9, 1.1] so providers don't sync up.
    public static func jitter(seed: Double) -> Double {
        0.9 + 0.2 * abs(seed.truncatingRemainder(dividingBy: 1.0))
    }
}
