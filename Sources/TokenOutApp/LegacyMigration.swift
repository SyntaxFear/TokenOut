import Foundation

/// One-time migration from the app's original name (BurnBar, renamed because
/// the name was taken on the Mac App Store). Moves usage history and copies
/// preferences so existing users lose nothing. The "BurnBar"/"burnbar"
/// literals below are intentional — they are the legacy locations.
enum LegacyMigration {
    static func runIfNeeded() {
        let fm = FileManager.default

        // ~/Library/Application Support/BurnBar → TokenOut (history + state).
        if let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let old = base.appending(path: "BurnBar")
            let new = base.appending(path: "TokenOut")
            if fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) {
                try? fm.moveItem(at: old, to: new)
            }
        }

        // Preferences: import the old bundle id's domain once, never clobbering
        // anything already set in the new domain.
        let marker = "didMigrateFromBurnBar"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }
        UserDefaults.standard.set(true, forKey: marker)
        let oldPlist = fm.homeDirectoryForCurrentUser
            .appending(path: "Library/Preferences/dev.burnbar.mac.plist")
        guard let data = try? Data(contentsOf: oldPlist),
              let dict = try? PropertyListSerialization.propertyList(
                  from: data, format: nil) as? [String: Any] else { return }
        for (key, value) in dict where UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
}
