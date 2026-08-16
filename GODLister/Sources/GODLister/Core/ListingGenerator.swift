import Foundation

enum ListingGenerator {
    /// Runs a scan and either writes the listing to `outputPath` or returns
    /// its text as `content` for a preview (when `outputPath` is nil).
    static func generateListing(
        root: String,
        outputPath: String?,
        settings: AppSettings
    ) throws -> ListingSummary {
        let godTitles = settings.godRecognition ? GODTitleCatalog.map : [:]
        let dlcTitles = (settings.godRecognition && settings.contentTypeRecognition) ? DLCTitleCatalog.map : [:]

        // -1 means no depth limit; 0 means "just the selected folder itself" -
        // the header line already covers that, nothing further to walk.
        let maxDepth: Int? = settings.defaultDepth < 0 ? nil : settings.defaultDepth

        var entries: [(depth: Int, label: String)] = []
        let counters = ScanCounters()

        if maxDepth != 0 {
            let rootURL = URL(fileURLWithPath: root)
            DirectoryScanner.collectEntries(
                dir: rootURL,
                depth: 1,
                maxDepth: maxDepth,
                godRecognition: settings.godRecognition,
                contentTypeRecognition: settings.contentTypeRecognition,
                godTitles: godTitles,
                dlcTitles: dlcTitles,
                counters: counters,
                into: &entries
            )
        }

        var text = root
        text.append("\n")
        for (depth, label) in entries {
            text.append(String(repeating: "  ", count: max(0, depth - 1)))
            text.append(label)
            text.append("\n")
        }

        let entriesWritten = UInt32(entries.count)

        if let outputPath {
            do {
                try text.write(toFile: outputPath, atomically: true, encoding: .utf8)
            } catch {
                throw ListingError.writeFailed(path: outputPath, underlying: error)
            }
            return ListingSummary(
                entriesWritten: entriesWritten,
                godMatches: counters.godMatches,
                contentTypeMatches: counters.contentTypeMatches,
                dlcMatches: counters.dlcMatches,
                unreadableCount: counters.unreadableCount,
                fullDiskAccessNeeded: counters.fullDiskAccessNeeded,
                outputPath: outputPath,
                content: nil
            )
        } else {
            return ListingSummary(
                entriesWritten: entriesWritten,
                godMatches: counters.godMatches,
                contentTypeMatches: counters.contentTypeMatches,
                dlcMatches: counters.dlcMatches,
                unreadableCount: counters.unreadableCount,
                fullDiskAccessNeeded: counters.fullDiskAccessNeeded,
                outputPath: nil,
                content: text
            )
        }
    }

    static func saveText(_ text: String, to path: String) throws {
        do {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw ListingError.writeFailed(path: path, underlying: error)
        }
    }
}
