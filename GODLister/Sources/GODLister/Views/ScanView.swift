import SwiftUI

struct ScanView: View {
    @ObservedObject var state: ScanState
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("GOD Lister").font(.title2.bold())
                Spacer()
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            VStack(alignment: .leading, spacing: 4) {
                Button("Choose Folder to Scan…") {
                    if let url = FilePanelService.pickScanRoot() {
                        state.root = url.path
                    }
                }
                Text(state.root ?? "No folder selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Button("Choose Where to Save…") {
                    if let url = FilePanelService.pickOutputPath() {
                        state.outputPath = url.path
                    }
                }
                .disabled(state.previewMode)
                Text(state.outputPath ?? "No save location selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(state.previewMode ? 0.5 : 1)
            }

            Toggle("Just show me the result instead of saving to a file", isOn: $state.previewMode)

            Button("Generate List") {
                runGenerate()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!state.canGenerate || state.isRunning)

            if let message = state.resultMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(state.resultIsError ? .red : .secondary)
            }

            if state.lastRunNeededFullDiskAccess {
                Button("Open Full Disk Access Settings…") {
                    FullDiskAccessChecker.openSettings()
                }
            }

            Spacer()
        }
        .padding(20)
        .sheet(item: $state.previewSummary) { summary in
            PreviewSheet(state: state, summary: summary)
        }
    }

    private func runGenerate() {
        guard let root = state.root else { return }
        state.isRunning = true
        state.resultMessage = nil
        state.lastRunNeededFullDiskAccess = false

        let settings = SettingsStore.load()
        let outputPath = state.previewMode ? nil : state.outputPath

        Task {
            defer { state.isRunning = false }
            do {
                let summary = try ListingGenerator.generateListing(root: root, outputPath: outputPath, settings: settings)
                handle(summary)
            } catch {
                state.resultMessage = "Error: \(error.localizedDescription)"
                state.resultIsError = true
            }
        }
    }

    private func handle(_ summary: ListingSummary) {
        let fdaNote = summary.unreadableCount > 0
            ? "\n\(summary.unreadableCount) folder\(summary.unreadableCount == 1 ? "" : "s") couldn't be read and \(summary.unreadableCount == 1 ? "was" : "were") skipped" +
              (summary.fullDiskAccessNeeded ? " — this usually means GOD Lister needs Full Disk Access." : ".")
            : ""

        if let content = summary.content {
            state.previewContent = content
            state.previewSummary = summary
        } else {
            state.resultIsError = false
            var lines = ["Wrote \(summary.entriesWritten) entr\(summary.entriesWritten == 1 ? "y" : "ies") to \(summary.outputPath ?? "")"]
            if summary.godMatches > 0 {
                lines.append("Labeled \(summary.godMatches) GOD game folder\(summary.godMatches == 1 ? "" : "s") with their title.")
            }
            if summary.contentTypeMatches > 0 {
                lines.append("Labeled \(summary.contentTypeMatches) content-type folder\(summary.contentTypeMatches == 1 ? "" : "s").")
            }
            if summary.dlcMatches > 0 {
                lines.append("Labeled \(summary.dlcMatches) DLC file\(summary.dlcMatches == 1 ? "" : "s") with its name.")
            }
            state.resultMessage = lines.joined(separator: "\n") + fdaNote
            state.lastRunNeededFullDiskAccess = summary.fullDiskAccessNeeded
        }
    }
}
