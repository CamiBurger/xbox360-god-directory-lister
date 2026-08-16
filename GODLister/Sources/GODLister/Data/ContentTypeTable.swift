import Foundation

/// STFS/GOD content-type folder codes, formatted as 8 uppercase hex digits.
/// Source: XboxInternals/Stfs/StfsConstants.h in hetelek/Velocity, cross-checked
/// against iso2god-rs's own ContentType enum (GamesOnDemand = 0x7000).
enum ContentTypeTable {
    static let dlcContentTypeCode = "00000002"

    private static let table: [String: String] = [
        "00000001": "Saved Game",
        "00000002": "DLC / Marketplace Content",
        "00000003": "Publisher",
        "00001000": "Xbox 360 Title",
        "00002000": "IPTV Pause Buffer",
        "00004000": "Installed Game",
        "00005000": "Xbox Original Game",
        "00007000": "Games on Demand",
        "00008000": "Avatar Asset Pack",
        "00009000": "Avatar Item",
        "00010000": "Profile",
        "00020000": "Gamer Picture",
        "00030000": "Theme",
        "00040000": "Cache File",
        "00050000": "Storage Download",
        "00060000": "Xbox Saved Game",
        "00070000": "Xbox Download",
        "00080000": "Game Demo",
        "000A0000": "Gamer Title",
        "000B0000": "Title Update",
        "000C0000": "Game Trailer",
        "000D0000": "Xbox Live Arcade Game",
        "000E0000": "XNA Game",
        "000F0000": "License Store",
        "00100000": "Movie",
        "00200000": "Video",
        "00300000": "Music Video",
        "00400000": "Game Video",
        "00500000": "Podcast Video",
        "00600000": "Viral Video",
        "02000000": "Community Game"
    ]

    static func name(for code: String) -> String? {
        table[code]
    }
}
