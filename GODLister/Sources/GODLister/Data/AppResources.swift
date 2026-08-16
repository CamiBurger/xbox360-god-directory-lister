import Foundation

/// Resolves bundled resources by trying Bundle.main first (Contents/Resources
/// in a packaged .app - the standard, codesign-friendly location) and only
/// falling back to Bundle.module (the SwiftPM-generated accessor, which
/// expects a loose top-level *.bundle folder outside Contents/) for `swift
/// run`/`swift test` dev builds. `??` short-circuits, so a packaged app never
/// touches Bundle.module and can't hit its fatalError if that loose folder
/// isn't shipped.
enum AppResources {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext) ?? Bundle.module.url(forResource: name, withExtension: ext)
    }
}
