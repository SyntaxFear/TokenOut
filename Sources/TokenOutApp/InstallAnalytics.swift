import Foundation

private struct InstallAnalyticsPayload: Encodable {
    let appVersion: String
    let build: String
    let macOSVersion: String
    let architecture: String
}

enum InstallAnalytics {
    private static let recordedKey = "dev.tokenout.analytics.firstLaunchRecorded.v1"
    private static let endpoint = URL(string: "https://tokenout.scrubmac.app/api/analytics/install")!

    @MainActor
    static func recordFirstLaunchIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: recordedKey) else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let payload = InstallAnalyticsPayload(
            appVersion: version,
            build: build,
            macOSVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            architecture: architecture
        )

        Task {
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("TokenOut/\(version)", forHTTPHeaderField: "User-Agent")
                request.httpBody = try JSONEncoder().encode(payload)
                request.timeoutInterval = 8

                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 8
                configuration.timeoutIntervalForResource = 10
                let session = URLSession(configuration: configuration)
                defer { session.finishTasksAndInvalidate() }

                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else { return }

                UserDefaults.standard.set(true, forKey: recordedKey)
            } catch {
                // Analytics must never affect launch. A failed event retries next time.
            }
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
