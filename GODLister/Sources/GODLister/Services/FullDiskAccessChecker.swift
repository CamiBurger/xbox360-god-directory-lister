import AppKit
import Foundation

/// TCC per-app grant, not an entitlement or plist-declared permission - no
/// usage-description key needed. Note: TCC caches the grant per *process*,
/// so a re-check after the user flips the System Settings toggle will keep
/// reporting "not granted" until GODLister is relaunched. That's expected,
/// not a bug in this check.
enum FullDiskAccessChecker {
    /// Only openable by a process that already has Full Disk Access - the
    /// standard self-probe technique, no need to touch a real protected
    /// user folder first.
    static func isGranted() -> Bool {
        guard let handle = FileHandle(forReadingAtPath: "/Library/Application Support/com.apple.TCC/TCC.db") else {
            return false
        }
        handle.closeFile()
        return true
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
