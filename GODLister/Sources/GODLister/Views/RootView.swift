import SwiftUI

struct RootView: View {
    @StateObject private var scanState = ScanState()
    @State private var showSetup = false
    @State private var isFirstRun = false

    var body: some View {
        Group {
            if showSetup {
                SetupView(isFirstRun: isFirstRun) {
                    showSetup = false
                }
            } else {
                ScanView(state: scanState) {
                    isFirstRun = false
                    showSetup = true
                }
            }
        }
        .onAppear {
            if !SettingsStore.hasCompletedSetup {
                isFirstRun = true
                showSetup = true
            } else if SettingsStore.load().askEveryTime {
                isFirstRun = false
                showSetup = true
            }
        }
    }
}
