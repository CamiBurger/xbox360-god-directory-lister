import Foundation

/// Plain value type edited as a local draft in the setup UI; only persisted
/// on explicit Save (never bound directly to @AppStorage, which would write
/// on every keystroke and break Cancel-discards semantics).
struct AppSettings: Equatable {
    var askEveryTime: Bool = true
    var defaultDepth: Int = 2
    var godRecognition: Bool = false
    var contentTypeRecognition: Bool = false
}

enum SettingsStore {
    private static let defaults = UserDefaults.standard

    private enum Keys {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let askEveryTime = "askEveryTime"
        static let defaultDepth = "defaultDepth"
        static let godRecognition = "godRecognition"
        static let contentTypeRecognition = "contentTypeRecognition"
    }

    /// Explicit first-run flag rather than inferring from parse success -
    /// more robust than the original's "does settings.json exist and parse."
    static var hasCompletedSetup: Bool {
        defaults.bool(forKey: Keys.hasCompletedSetup)
    }

    static func load() -> AppSettings {
        AppSettings(
            askEveryTime: defaults.object(forKey: Keys.askEveryTime) as? Bool ?? true,
            defaultDepth: defaults.object(forKey: Keys.defaultDepth) as? Int ?? 2,
            godRecognition: defaults.object(forKey: Keys.godRecognition) as? Bool ?? false,
            contentTypeRecognition: defaults.object(forKey: Keys.contentTypeRecognition) as? Bool ?? false
        )
    }

    static func save(_ settings: AppSettings) {
        defaults.set(settings.askEveryTime, forKey: Keys.askEveryTime)
        defaults.set(settings.defaultDepth, forKey: Keys.defaultDepth)
        defaults.set(settings.godRecognition, forKey: Keys.godRecognition)
        defaults.set(settings.contentTypeRecognition, forKey: Keys.contentTypeRecognition)
        defaults.set(true, forKey: Keys.hasCompletedSetup)
    }
}
