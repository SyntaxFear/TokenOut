import Foundation
import Observation
import Sparkle

/// The single app-owned Sparkle service. SwiftUI owns only user-facing preferences;
/// Sparkle remains responsible for scheduling, downloading, verification, and install.
@MainActor
@Observable
final class UpdateController {
    @ObservationIgnored
    private let standardController: SPUStandardUpdaterController

    init(startingUpdater: Bool = true) {
        standardController = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private var updater: SPUUpdater { standardController.updater }

    var canCheckForUpdates: Bool { updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    var updateCheckInterval: TimeInterval {
        get { updater.updateCheckInterval }
        set { updater.updateCheckInterval = max(3600, newValue) }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
