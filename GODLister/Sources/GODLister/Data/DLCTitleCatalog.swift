import Foundation

/// DLC content-ID (42-hex-char package identifier) -> DLC name.
///
/// Merges two sources, primary-wins:
///  1. `dlc_titles.csv` - RFC4180, columns Title,ReleaseDate,TypeCode,Price,
///     Size,DLCName,Hash. Sourced from github.com/CamiBurger/xbox360_DLC_titles
///     (scrapes the now-dead Xbox Live Marketplace catalog API).
///  2. `dlc_titles_nointro.csv` - RFC4180, columns ContentId,DLCName. Fallback
///     only, used where the primary source has no entry. Converted from
///     No-Intro's "Microsoft - Xbox 360 (Digital)" DAT via
///     Scripts/convert_nointro_dlc_dat.py - see that script and the README's
///     "Data sources" section for provenance and licensing (CC BY-SA 4.0,
///     distinct from this project's own MIT license).
/// First occurrence wins on duplicate ContentIds within each source.
enum DLCTitleCatalog {
    static let map: [String: String] = mergedMap()

    private static func mergedMap() -> [String: String] {
        var merged = loadPrimary()
        for (contentID, dlcName) in loadNoIntroFallback() where merged[contentID] == nil {
            merged[contentID] = dlcName
        }
        return merged
    }

    private static func loadPrimary() -> [String: String] {
        guard let url = AppResources.url(forResource: "dlc_titles", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        guard let body = bodyAfterHeaderLine(of: text) else { return [:] }

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

    private static func loadNoIntroFallback() -> [String: String] {
        guard let url = AppResources.url(forResource: "dlc_titles_nointro", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        guard let body = bodyAfterHeaderLine(of: text) else { return [:] }

        var map: [String: String] = [:]
        for record in RFC4180Parser.parse(body) {
            guard record.count >= 2 else { continue }
            let contentID = record[0].trimmingCharacters(in: .whitespaces).uppercased()
            let dlcName = record[1]
            guard !contentID.isEmpty, !dlcName.isEmpty else { continue }
            if map[contentID] == nil {
                map[contentID] = dlcName
            }
        }
        return map
    }

    // Scan unicodeScalars, not firstIndex(of: Character) - a CRLF line
    // ending is a single Swift Character (grapheme clustering), so a
    // Character-level search for "\n" alone can silently fail to find it.
    private static func bodyAfterHeaderLine(of text: String) -> Substring? {
        guard let firstNewlineScalar = text.unicodeScalars.firstIndex(of: "\n") else { return nil }
        return text[text.unicodeScalars.index(after: firstNewlineScalar)...]
    }
}
