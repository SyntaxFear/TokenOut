import Foundation
import Observation

/// Latest known state for one provider, as shown in the UI.
public struct ProviderState: Codable, Sendable, Equatable {
    public var snapshot: UsageSnapshot?
    public var status: ProviderStatus
    public var lastErrorText: String?

    public init(snapshot: UsageSnapshot? = nil, status: ProviderStatus = .stale(since: .distantPast),
                lastErrorText: String? = nil) {
        self.snapshot = snapshot
        self.status = status
        self.lastErrorText = lastErrorText
    }
}

/// Codable container persisted so relaunch shows data instantly.
public struct PersistedState: Codable, Sendable, Equatable {
    public var states: [ProviderID: ProviderState]

    public init(states: [ProviderID: ProviderState] = [:]) {
        self.states = states
    }

    public static func load(from url: URL) -> PersistedState {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.tokenOut.decode(PersistedState.self, from: data)
        else { return PersistedState() }
        return decoded
    }

    public func save(to url: URL) {
        guard let data = try? JSONEncoder.tokenOut.encode(self) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "TokenOut/state.json")
    }
}

extension JSONDecoder {
    public static var tokenOut: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    public static var tokenOut: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

/// Observable hub the UI reads. Providers write via apply(); persistence is debounced by the app layer.
@MainActor
@Observable
public final class UsageStore {
    public private(set) var states: [ProviderID: ProviderState] = [:]
    private let persistenceURL: URL

    public init(persistenceURL: URL = PersistedState.defaultURL) {
        self.persistenceURL = persistenceURL
        self.states = PersistedState.load(from: persistenceURL).states
        for (id, state) in states where state.status == .ok {
            // Data from a previous run is stale until the first live fetch succeeds.
            states[id]?.status = .stale(since: state.snapshot?.fetchedAt ?? .distantPast)
        }
    }

    public func apply(result: Result<UsageSnapshot, Error>, for id: ProviderID) {
        var state = states[id] ?? ProviderState()
        switch result {
        case .success(let snapshot):
            state.snapshot = snapshot
            state.status = .ok
            state.lastErrorText = nil
        case .failure(let error):
            switch error {
            case ProviderError.signedOut(let help): state.status = .signedOut(help: help)
            case ProviderError.unsupported(let reason): state.status = .unsupported(reason: reason)
            default:
                // Soft-fail: a transient error (429, network blip) while the
                // snapshot is still fresh keeps the provider healthy — flagging
                // "stale"/"failed" over minutes-old data is pure noise.
                let age = state.snapshot.map { Date.now.timeIntervalSince($0.fetchedAt) }
                if let age, age < 10 * 60 {
                    state.status = .ok
                } else {
                    state.status = .stale(since: state.snapshot?.fetchedAt ?? .now)
                }
                state.lastErrorText = String(describing: error)
            }
        }
        states[id] = state
        PersistedState(states: states).save(to: persistenceURL)
    }

    public func snapshots(for enabled: Set<ProviderID>) -> [UsageSnapshot] {
        enabled.compactMap { states[$0]?.snapshot }
    }
}
