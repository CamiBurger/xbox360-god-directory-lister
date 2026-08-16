import Foundation

/// RFC4180 DLC catalog: ContentId (42-hex-char package identifier) -> DLC name.
/// Columns: Title,ReleaseDate,TypeCode,Price,Size,DLCName,Hash.
/// First line is skipped unconditionally (a stamp/header row, not data).
/// First occurrence wins on duplicate ContentIds.
enum DLCTitleCatalog {
    static let map: [String: String] = load()

    private static func load() -> [String: String] {
        guard let url = AppResources.url(forResource: "dlc_titles", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        // Scan unicodeScalars, not firstIndex(of: Character) - the real file
        // uses CRLF line endings, and Swift's grapheme clustering treats
        // "\r\n" as one Character, so a Character-level search for "\n"
        // alone never matches and silently returns an empty catalog.
        guard let firstNewlineScalar = text.unicodeScalars.firstIndex(of: "\n") else { return [:] }
        let body = text[text.unicodeScalars.index(after: firstNewlineScalar)...]

        var map: [String: String] = [:]
        for record in RFC4180Parser.parse(body) {
            guard record.count >= 7 else { continue }
            let dlcName = record[5]
            let contentID = record[6].trimmingCharacters(in: .whitespaces).uppercased()
            guard !dlcName.isEmpty, !contentID.isEmpty else { continue }
            if map[contentID] == nil {
                map[contentID] = dlcName
            }
        }
        return map
    }
}
