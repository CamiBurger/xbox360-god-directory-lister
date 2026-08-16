import Foundation

/// Tab-separated Xbox 360 GOD title lookup: title_id -> title_name.
/// First occurrence wins on duplicate title IDs (regional variants).
enum GODTitleCatalog {
    static let map: [String: String] = load()

    private static func load() -> [String: String] {
        guard let url = AppResources.url(forResource: "gamelist_xbox360", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        var map: [String: String] = [:]
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if index == 0 { continue } // header row
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let titleID = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let titleName = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !titleID.isEmpty, !titleName.isEmpty else { continue }
            let key = titleID.uppercased()
            if map[key] == nil {
                map[key] = titleName
            }
        }
        return map
    }
}
