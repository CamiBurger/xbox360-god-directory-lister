import SwiftUI

struct PreviewSheet: View {
    @ObservedObject var state: ScanState
    let summary: ListingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listing Preview").font(.title2.bold())

            Text(countsText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if summary.fullDiskAccessNeeded {
                Button("Open Full Disk Access Settings…") {
                    FullDiskAccessChecker.openSettings()
                }
            }

            ScrollView {
                Text(state.previewContent ?? "")
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(minHeight: 240)

            HStack {
                Button("Close (discard)") {
                    close()
                }
                Spacer()
                Button("Save As…") {
                    saveAs()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 420)
    }

    private var countsText: String {
        var parts = ["\(summary.entriesWritten) entr\(summary.entriesWritten == 1 ? "y" : "ies")"]
        if summary.godMatches > 0 {
            parts.append("\(summary.godMatches) GOD title\(summary.godMatches == 1 ? "" : "s")")
        }
        if summary.contentTypeMatches > 0 {
            parts.append("\(summary.contentTypeMatches) content-type match\(summary.contentTypeMatches == 1 ? "" : "es")")
        }
        if summary.dlcMatches > 0 {
            parts.append("\(summary.dlcMatches) DLC name\(summary.dlcMatches == 1 ? "" : "s")")
        }
        var text = parts.joined(separator: " · ")
        if summary.unreadableCount > 0 {
            text += "\n\(summary.unreadableCount) folder\(summary.unreadableCount == 1 ? "" : "s") couldn't be read and \(summary.unreadableCount == 1 ? "was" : "were") skipped" +
                (summary.fullDiskAccessNeeded ? " — this usually means GOD Lister needs Full Disk Access." : ".")
        }
        return text
    }

    private func close() {
        state.previewContent = nil
        state.previewSummary = nil
    }

    private func saveAs() {
        guard let content = state.previewContent, let url = FilePanelService.pickOutputPath() else { return }
        do {
            try ListingGenerator.saveText(content, to: url.path)
            close()
            state.resultIsError = false
            state.resultMessage = "Saved to \(url.path)"
        } catch {
            state.resultMessage = "Error saving: \(error.localizedDescription)"
            state.resultIsError = true
        }
    }
}
