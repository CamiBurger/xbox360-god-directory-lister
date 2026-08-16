# GODLister

A small native macOS app that scans a folder and writes a depth-limited `.txt` directory listing, with optional Xbox 360 GOD-title and DLC recognition.

## Features

- Depth control: `0` = header only, `N` = N levels deep, `-1` = unlimited depth
- Xbox 360 GOD title recognition (8-hex-char folder names → game name, via a bundled offline lookup table)
- STFS content-type recognition (DLC, Title Update, Games on Demand, etc.)
- DLC package name lookup, matched by the DLC file's own content ID against a bundled catalog
- Preview mode — see the listing before deciding whether to save it
- First-run setup wizard, plus a native Settings window (⌘,) for changing defaults later
- Full Disk Access detection, with a one-click link to the right System Settings pane, for scanning external drives with TCC-protected hidden folders

## Requirements

macOS 14 (Sonoma) or later. Built with Swift 6 / SwiftUI.

## Building

```
cd GODLister
swift build            # or: swift run
swift test              # run the unit test suite
```

To produce a proper double-clickable `GODLister.app`:

```
GODLister/Packaging/build_app.sh
```

This builds a release binary, assembles the `.app` bundle, and ad-hoc code-signs it. There's no Apple Developer ID certificate involved, so macOS Gatekeeper will still block the first launch — right-click the app and choose **Open** once to get past it.

## Project layout

```
GODLister/
  Sources/GODLister/
    Data/      - CSV parsing + the bundled GOD title / DLC catalogs
    Core/      - directory scanning and listing generation
    Models/    - settings + app state
    Services/  - Full Disk Access checks, file pickers
    Views/     - SwiftUI views
  Tests/GODListerTests/
  Packaging/   - app bundle build script + icon
```

## Older cross-platform version

This app was originally built with Tauri (Rust + HTML/JS) to be cross-platform; that version lives in [`legacy-tauri/`](legacy-tauri/) for reference and is no longer maintained. The Swift version above is the actively developed one.
