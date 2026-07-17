import SwiftUI

@main
struct BurnBarApp: App {
    @State private var app = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(app)
                .onAppear { OnboardingWindow.showIfNeeded(app: app) }
        } label: {
            MenuBarLabel(reading: app.menuBarReading)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(app)
        }
    }
}
