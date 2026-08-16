import AppKit
import SwiftUI

/// Reusable Full Disk Access status panel, used in both the setup wizard and
/// the native Settings window. Re-checks on app-become-active so returning
/// from System Settings updates it live (see FullDiskAccessChecker's note on
/// the per-process TCC cache still requiring a relaunch to actually change).
struct FDAStatusView: View {
    @State private var granted = false

    var body: some View {
        Group {
            if granted {
                Label(
                    "Full Disk Access is enabled — GODLister can read protected system folders on any drive.",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scanning external drives may hit hidden system folders (like .Spotlight-V100) that macOS blocks unless GODLister has Full Disk Access. GODLister will skip those folders and keep going, but granting access lets it read everything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Full Disk Access Settings…") {
                        FullDiskAccessChecker.openSettings()
                    }
                    Text("Add GODLister with the + button, enable its checkbox, then relaunch GODLister.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        granted = FullDiskAccessChecker.isGranted()
    }
}
