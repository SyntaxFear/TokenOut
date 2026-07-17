import Foundation

/// One recorded reading of a provider's primary windows.
public struct HistorySample: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var providerID: ProviderID
    /// label → usedFraction at that moment.
    public var fractions: [String: Double]
    public var todayTokens: Int?
    public var todayCostUSD: Double?

    public init(timestamp: Date, providerID: ProviderID, fractions: [String: Double],
                todayTokens: Int? = nil, todayCostUSD: Double? = nil) {
        self.timestamp = timestamp
        self.providerID = providerID
        self.fractions = fractions
        self.todayTokens = todayTokens
        self.todayCostUSD = todayCostUSD
    }
}

/// Append-only JSONL history with in-memory tail, pruned to `retention`.
/// One instance per app; readers get value-type copies.
public final class HistoryStore: @unchecked Sendable {
    private let url: URL
    private let retention: TimeInterval
    private let minInterval: TimeInterval
    private var samples: [HistorySample] = []
    private var lastRecorded: [ProviderID: Date] = [:]
    private let queue = DispatchQueue(label: "burnbar.history")

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "BurnBar/history.jsonl")
    }

    public init(url: URL = HistoryStore.defaultURL,
                retention: TimeInterval = 30 * 86400,
                minInterval: TimeInterval = 55) {
        self.url = url
        self.retention = retention
        self.minInterval = minInterval
        self.samples = Self.load(from: url, cutoff: Date.now.addingTimeInterval(-retention))
        for sample in samples {
            if lastRecorded[sample.providerID].map({ sample.timestamp > $0 }) ?? true {
                lastRecorded[sample.providerID] = sample.timestamp
            }
        }
    }

    /// Record a snapshot; throttled per provider so tight refresh loops don't bloat the file.
    public func record(snapshot: UsageSnapshot) {
        queue.sync {
            if let last = lastRecorded[snapshot.providerID],
               snapshot.fetchedAt.timeIntervalSince(last) < minInterval { return }
            lastRecorded[snapshot.providerID] = snapshot.fetchedAt
            let sample = HistorySample(
                timestamp: snapshot.fetchedAt,
                providerID: snapshot.providerID,
                fractions: Dictionary(uniqueKeysWithValues:
                    snapshot.windows.map { ($0.label, $0.usedFraction) }),
                todayTokens: snapshot.tokens?.todayTokens,
                todayCostUSD: snapshot.tokens?.todayCostUSD)
            samples.append(sample)
            append(sample)
            pruneIfNeeded()
        }
    }

    public func samples(for provider: ProviderID, since: Date) -> [HistorySample] {
        queue.sync {
            samples.filter { $0.providerID == provider && $0.timestamp >= since }
                .sorted { $0.timestamp < $1.timestamp }
        }
    }

    // MARK: persistence

    private static func load(from url: URL, cutoff: Date) -> [HistorySample] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder.burnBar
        return text.split(separator: "\n").compactMap {
            guard let data = $0.data(using: .utf8) else { return nil }
            return try? decoder.decode(HistorySample.self, from: data)
        }.filter { $0.timestamp >= cutoff }
    }

    private func append(_ sample: HistorySample) {
        guard let data = try? JSONEncoder.burnBar.encode(sample) else { return }
        let line = data + Data("\n".utf8)
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }

    /// Rewrite the file (dropping expired samples) when in-memory expiry is detected.
    private func pruneIfNeeded() {
        let cutoff = Date.now.addingTimeInterval(-retention)
        guard let oldest = samples.first?.timestamp, oldest < cutoff else { return }
        samples.removeAll { $0.timestamp < cutoff }
        let encoder = JSONEncoder.burnBar
        let text = samples.compactMap { try? encoder.encode($0) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: "\n") + "\n"
        try? Data(text.utf8).write(to: url, options: .atomic)
    }
}

public enum BurnRate {
    public struct Projection: Equatable, Sendable {
        public var perHour: Double
        public var hitsCapAt: Date
    }

    /// Linear projection of when a window hits 100%, from recent samples of its fraction.
    /// Returns nil when there's no meaningful upward burn or too little data.
    public static func projection(samples: [(Date, Double)], now: Date = .now,
                                  lookback: TimeInterval = 45 * 60) -> Projection? {
        let recent = samples.filter { $0.0 >= now.addingTimeInterval(-lookback) }
            .sorted { $0.0 < $1.0 }
        guard let first = recent.first, let last = recent.last, recent.count >= 2 else { return nil }
        let dt = last.0.timeIntervalSince(first.0)
        guard dt >= 5 * 60 else { return nil }              // need a real time base
        let slope = (last.1 - first.1) / dt                 // fraction per second
        guard slope > 0.00001, last.1 < 1.0 else { return nil }
        let secondsToCap = (1.0 - last.1) / slope
        guard secondsToCap < 24 * 3600 else { return nil }  // beyond a day isn't a projection
        return Projection(perHour: slope * 3600,
                          hitsCapAt: last.0.addingTimeInterval(secondsToCap))
    }
}
