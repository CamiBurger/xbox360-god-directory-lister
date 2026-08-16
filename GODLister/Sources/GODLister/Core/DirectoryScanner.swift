import Foundation

/// Mutable counters threaded through a scan, mirroring the `&mut u32` params
/// in the original Rust `collect_entries`.
final class ScanCounters {
    var godMatches: UInt32 = 0
    var contentTypeMatches: UInt32 = 0
    var dlcMatches: UInt32 = 0
    var unreadableCount: UInt32 = 0
    var fullDiskAccessNeeded = false
}

enum DirectoryScanner {
    /// An 8-hex-char name (byte length, ASCII hex only - matches Rust's
    /// `name.len() == 8 && name.chars().all(|c| c.is_ascii_hexdigit())`,
    /// deliberately not Swift's grapheme-cluster `count`/Unicode `isHexDigit`).
    static func isGodTitleID(_ name: String) -> Bool {
        let bytes = Array(name.utf8)
        guard bytes.count == 8 else { return false }
        return bytes.allSatisfy { byte in
            (0x30...0x39).contains(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte)
        }
    }

    static func labelFor(
        name: String,
        parentName: String,
        godRecognition: Bool,
        contentTypeRecognition: Bool,
        godTitles: [String: String],
        dlcTitles: [String: String],
        counters: ScanCounters
    ) -> String {
        if godRecognition, contentTypeRecognition, isGodTitleID(parentName) {
            let code = name.uppercased()
            if let contentType = ContentTypeTable.name(for: code) {
                counters.contentTypeMatches += 1
                return "\(code) (\(contentType))"
            }
        }

        if godRecognition, contentTypeRecognition, parentName.uppercased() == ContentTypeTable.dlcContentTypeCode {
            let key = name.uppercased()
            if let dlcName = dlcTitles[key] {
                counters.dlcMatches += 1
                return "\(key) - \(dlcName)"
            }
        }

        if godRecognition, isGodTitleID(name) {
            let key = name.uppercased()
            if let title = godTitles[key] {
                counters.godMatches += 1
                return "\(key) - \(title)"
            }
        }

        return name
    }

    /// Reads errno directly via a fresh `opendir` probe on the failing path,
    /// so EPERM (macOS's TCC/privacy error) can be told apart from a plain
    /// EACCES - Foundation's `contentsOfDirectory` collapses both into the
    /// same NSCocoaErrorDomain code.
    private static func probeErrno(_ path: String) -> Int32 {
        if let dp = opendir(path) {
            closedir(dp)
            return 0
        }
        return errno
    }

    static func collectEntries(
        dir: URL,
        depth: Int,
        maxDepth: Int?,
        godRecognition: Bool,
        contentTypeRecognition: Bool,
        godTitles: [String: String],
        dlcTitles: [String: String],
        counters: ScanCounters,
        into entries: inout [(depth: Int, label: String)]
    ) {
        let parentName = dir.lastPathComponent

        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            counters.unreadableCount += 1
            let errnoValue = probeErrno(dir.path)
            if errnoValue == EPERM {
                counters.fullDiskAccessNeeded = true
            }
            let message = String(cString: strerror(errnoValue))
            entries.append((depth, "(couldn't read this folder: \(message))"))
            return
        }

        // Accept Unicode-canonical ordering here (Swift String `<`) rather than
        // Rust's byte-wise PathBuf sort - identical for the ASCII hex-heavy
        // GOD/DLC use case, a documented harmless divergence on accented names.
        let sorted = children.sorted { $0.path < $1.path }

        for child in sorted {
            let name = child.lastPathComponent
            let label = labelFor(
                name: name,
                parentName: parentName,
                godRecognition: godRecognition,
                contentTypeRecognition: contentTypeRecognition,
                godTitles: godTitles,
                dlcTitles: dlcTitles,
                counters: counters
            )
            entries.append((depth, label))

            let continueDeeper = maxDepth.map { depth < $0 } ?? true
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if continueDeeper, isDirectory {
                collectEntries(
                    dir: child,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    godRecognition: godRecognition,
                    contentTypeRecognition: contentTypeRecognition,
                    godTitles: godTitles,
                    dlcTitles: dlcTitles,
                    counters: counters,
                    into: &entries
                )
            }
        }
    }
}
