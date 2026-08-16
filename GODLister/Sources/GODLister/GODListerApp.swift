import SwiftUI

@main
struct GODListerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 480, minHeight: 400)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 480)

        Settings {
            SettingsView()
        }
    }
}
