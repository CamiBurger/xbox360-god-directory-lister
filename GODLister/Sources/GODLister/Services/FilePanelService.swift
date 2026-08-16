import AppKit
import UniformTypeIdentifiers

/// Direct AppKit panels rather than SwiftUI's .fileImporter/.fileExporter:
/// those are designed around sandboxed apps and security-scoped bookmarks,
/// which this deliberately non-sandboxed app doesn't use.
@MainActor
enum FilePanelService {
    static func pickScanRoot() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select a folder to scan"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func pickOutputPath() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save directory listing as"
        panel.nameFieldStringValue = "directory_listing.txt"
        if let txtType = UTType(filenameExtension: "txt") {
            panel.allowedContentTypes = [txtType]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}
