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
                    "Full Disk Access is enabled — GOD Lister can read protected system folders on any drive.",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scanning external drives may hit hidden system folders (like .Spotlight-V100) that macOS blocks unless GOD Lister has Full Disk Access. GOD Lister will skip those folders and keep going, but granting access lets it read everything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Full Disk Access Settings…") {
                        FullDiskAccessChecker.openSettings()
                    }
                    Text("Add GOD Lister with the + button, enable its checkbox, then relaunch GOD Lister.")
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
