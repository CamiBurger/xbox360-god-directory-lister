import Foundation

struct ListingSummary: Identifiable {
    let id = UUID()
    var entriesWritten: UInt32
    var godMatches: UInt32
    var contentTypeMatches: UInt32
    var dlcMatches: UInt32
    var unreadableCount: UInt32
    var fullDiskAccessNeeded: Bool
    var outputPath: String?
    /// Present only when outputPath is nil: the full listing text, for a
    /// preview sheet instead of a file write.
    var content: String?
}

enum ListingError: Error, LocalizedError {
    case writeFailed(path: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let path, let underlying):
            return "Couldn't write \(path): \(underlying.localizedDescription)"
        }
    }
}
