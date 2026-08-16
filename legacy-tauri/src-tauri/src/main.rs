// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Manager};
use tauri_plugin_dialog::DialogExt;

const GOD_TITLE_CSV: &str = include_str!("../resources/gamelist_xbox360.csv");
const DLC_TITLES_CSV: &str = include_str!("../resources/dlc_titles.csv");
const DLC_CONTENT_TYPE_CODE: &str = "00000002";

#[derive(Serialize, Deserialize, Clone)]
struct Settings {
    ask_every_time: bool,
    default_depth: i32,
    god_recognition: bool,
    content_type_recognition: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            ask_every_time: true,
            default_depth: 2,
            god_recognition: false,
            content_type_recognition: false,
        }
    }
}

#[derive(Serialize)]
struct SettingsResponse {
    configured: bool,
    ask_every_time: bool,
    default_depth: i32,
    god_recognition: bool,
    content_type_recognition: bool,
}

fn settings_path(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("settings.json"))
}

fn load_settings(app: &AppHandle) -> Result<(bool, Settings), String> {
    let path = settings_path(app)?;
    Ok(match fs::read_to_string(&path) {
        Ok(text) => match serde_json::from_str::<Settings>(&text) {
            Ok(s) => (true, s),
            Err(_) => (false, Settings::default()),
        },
        Err(_) => (false, Settings::default()),
    })
}

#[tauri::command]
fn get_settings(app: AppHandle) -> Result<SettingsResponse, String> {
    let (configured, settings) = load_settings(&app)?;
    Ok(SettingsResponse {
        configured,
        ask_every_time: settings.ask_every_time,
        default_depth: settings.default_depth,
        god_recognition: settings.god_recognition,
        content_type_recognition: settings.content_type_recognition,
    })
}

#[tauri::command]
fn save_settings(
    app: AppHandle,
    ask_every_time: bool,
    default_depth: i32,
    god_recognition: bool,
    content_type_recognition: bool,
) -> Result<(), String> {
    let path = settings_path(&app)?;
    let settings = Settings {
        ask_every_time,
        default_depth,
        god_recognition,
        content_type_recognition,
    };
    let text = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    fs::write(path, text).map_err(|e| e.to_string())
}

// Uses the callback-based pick_folder/save_file API rather than the
// blocking_* variants: the blocking variants are documented as unsafe to
// call from the main thread (they can deadlock the event loop), and Tauri
// commands may run there. The oneshot channel just lets us await the
// callback's result from an async command.
// Opens macOS's Full Disk Access pane directly. External volumes' hidden
// system folders (.Spotlight-V100, .fseventsd, .DocumentRevisions-V100, etc.)
// are TCC-protected: reading them fails with EPERM ("Operation not
// permitted") regardless of Unix file permissions, and the only fix is the
// user granting this app Full Disk Access.
#[tauri::command]
fn open_full_disk_access_settings() -> Result<(), String> {
    std::process::Command::new("open")
        .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}

// The system TCC database is present on every Mac and is only openable by a
// process that already has Full Disk Access - opening it (not just stat-ing
// it) is the standard way apps probe their own FDA status without needing
// to hit a real protected user folder first.
#[tauri::command]
fn check_full_disk_access() -> bool {
    fs::File::open("/Library/Application Support/com.apple.TCC/TCC.db").is_ok()
}

#[tauri::command]
async fn pick_scan_root(app: AppHandle) -> Option<String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    app.dialog()
        .file()
        .set_title("Select a folder to scan")
        .pick_folder(move |folder| {
            let _ = tx.send(folder);
        });
    let folder = rx.await.ok().flatten()?;
    folder.into_path().ok().map(|p| p.to_string_lossy().to_string())
}

#[tauri::command]
async fn pick_output_path(app: AppHandle) -> Option<String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    app.dialog()
        .file()
        .set_title("Save directory listing as")
        .set_file_name("directory_listing.txt")
        .add_filter("Text file", &["txt"])
        .save_file(move |file| {
            let _ = tx.send(file);
        });
    let file = rx.await.ok().flatten()?;
    file.into_path().ok().map(|p| p.to_string_lossy().to_string())
}

fn build_god_title_map() -> HashMap<String, String> {
    let mut map = HashMap::new();
    for (i, line) in GOD_TITLE_CSV.lines().enumerate() {
        if i == 0 {
            continue; // header row
        }
        let mut parts = line.split('\t');
        let title_id = match parts.next() {
            Some(id) if !id.is_empty() => id.to_uppercase(),
            _ => continue,
        };
        let _media_id = parts.next();
        let title_name = match parts.next() {
            Some(name) if !name.is_empty() => name,
            _ => continue,
        };
        // First occurrence wins on duplicate title IDs (regional variants).
        map.entry(title_id).or_insert_with(|| title_name.to_string());
    }
    map
}

// DLC_titles.csv (github.com/CamiBurger/xbox360_DLC_titles) is RFC4180 CSV
// with CRLF line endings: `[Title],ReleaseDate,RatingId,Price,SizeMB,DLC Name,ContentId`.
// The first line is just a generation-date stamp, not a header or data row.
// ContentId is the 42-hex-char package identifier XM360 matches installed
// DLC files against - i.e. the literal filename of the DLC package on disk
// inside a title's "00000002" (DLC) content-type folder.
fn build_dlc_title_map() -> HashMap<String, String> {
    let mut map = HashMap::new();
    let body = match DLC_TITLES_CSV.split_once('\n') {
        Some((_, rest)) => rest,
        None => return map,
    };
    let mut reader = csv::ReaderBuilder::new()
        .has_headers(false)
        .from_reader(body.as_bytes());
    for result in reader.records() {
        let record = match result {
            Ok(r) => r,
            Err(_) => continue,
        };
        let dlc_name = match record.get(5) {
            Some(n) if !n.is_empty() => n,
            _ => continue,
        };
        let content_id = match record.get(6) {
            Some(id) if !id.is_empty() => id.trim().to_uppercase(),
            _ => continue,
        };
        // First occurrence wins on duplicate content IDs (the source catalog
        // occasionally lists multiple named offers under one content id).
        map.entry(content_id).or_insert_with(|| dlc_name.to_string());
    }
    map
}

fn is_god_title_id(name: &str) -> bool {
    name.len() == 8 && name.chars().all(|c| c.is_ascii_hexdigit())
}

// STFS/GOD content-type folder codes, formatted as 8 uppercase hex digits.
// Source: XboxInternals/Stfs/StfsConstants.h in hetelek/Velocity, cross-checked
// against iso2god-rs's own ContentType enum (GamesOnDemand = 0x7000).
fn content_type_name(code: &str) -> Option<&'static str> {
    match code {
        "00000001" => Some("Saved Game"),
        DLC_CONTENT_TYPE_CODE => Some("DLC / Marketplace Content"),
        "00000003" => Some("Publisher"),
        "00001000" => Some("Xbox 360 Title"),
        "00002000" => Some("IPTV Pause Buffer"),
        "00004000" => Some("Installed Game"),
        "00005000" => Some("Xbox Original Game"),
        "00007000" => Some("Games on Demand"),
        "00008000" => Some("Avatar Asset Pack"),
        "00009000" => Some("Avatar Item"),
        "00010000" => Some("Profile"),
        "00020000" => Some("Gamer Picture"),
        "00030000" => Some("Theme"),
        "00040000" => Some("Cache File"),
        "00050000" => Some("Storage Download"),
        "00060000" => Some("Xbox Saved Game"),
        "00070000" => Some("Xbox Download"),
        "00080000" => Some("Game Demo"),
        "000A0000" => Some("Gamer Title"),
        "000B0000" => Some("Title Update"),
        "000C0000" => Some("Game Trailer"),
        "000D0000" => Some("Xbox Live Arcade Game"),
        "000E0000" => Some("XNA Game"),
        "000F0000" => Some("License Store"),
        "00100000" => Some("Movie"),
        "00200000" => Some("Video"),
        "00300000" => Some("Music Video"),
        "00400000" => Some("Game Video"),
        "00500000" => Some("Podcast Video"),
        "00600000" => Some("Viral Video"),
        "02000000" => Some("Community Game"),
        _ => None,
    }
}

fn label_for(
    name: &str,
    parent_name: &str,
    god_recognition: bool,
    content_type_recognition: bool,
    god_titles: &HashMap<String, String>,
    dlc_titles: &HashMap<String, String>,
    god_matches: &mut u32,
    content_type_matches: &mut u32,
    dlc_matches: &mut u32,
) -> String {
    if god_recognition && content_type_recognition && is_god_title_id(parent_name) {
        let code = name.to_uppercase();
        if let Some(content_type) = content_type_name(&code) {
            *content_type_matches += 1;
            return format!("{} ({})", code, content_type);
        }
    }

    if god_recognition && content_type_recognition && parent_name.eq_ignore_ascii_case(DLC_CONTENT_TYPE_CODE) {
        let key = name.to_uppercase();
        if let Some(dlc_name) = dlc_titles.get(&key) {
            *dlc_matches += 1;
            return format!("{} - {}", key, dlc_name);
        }
    }

    if god_recognition && is_god_title_id(name) {
        let key = name.to_uppercase();
        if let Some(title) = god_titles.get(&key) {
            *god_matches += 1;
            return format!("{} - {}", key, title);
        }
    }

    name.to_string()
}

fn collect_entries(
    dir: &Path,
    depth: u32,
    max_depth: Option<u32>,
    god_recognition: bool,
    content_type_recognition: bool,
    god_titles: &HashMap<String, String>,
    dlc_titles: &HashMap<String, String>,
    out: &mut Vec<(u32, String)>,
    god_matches: &mut u32,
    content_type_matches: &mut u32,
    dlc_matches: &mut u32,
    unreadable_count: &mut u32,
    full_disk_access_needed: &mut bool,
) -> Result<(), String> {
    let parent_name = dir
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();

    // A single unreadable folder (e.g. a TCC-protected .Spotlight-V100 on an
    // external volume) shouldn't abort the whole scan - skip it, note it in
    // the output, and keep going.
    let read_dir = match fs::read_dir(dir) {
        Ok(rd) => rd,
        Err(e) => {
            *unreadable_count += 1;
            // EPERM (errno 1) is macOS's TCC/privacy-protection error, distinct
            // from a plain Unix EACCES (13) permission error.
            if e.raw_os_error() == Some(1) {
                *full_disk_access_needed = true;
            }
            out.push((depth, format!("(couldn't read this folder: {})", e)));
            return Ok(());
        }
    };

    let mut children: Vec<PathBuf> = read_dir
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .collect();
    children.sort();

    for child in children {
        let name = child
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        let label = label_for(
            &name,
            &parent_name,
            god_recognition,
            content_type_recognition,
            god_titles,
            dlc_titles,
            god_matches,
            content_type_matches,
            dlc_matches,
        );
        out.push((depth, label));

        let continue_deeper = match max_depth {
            None => true, // -1 sentinel: no depth limit
            Some(max) => depth < max,
        };
        if continue_deeper && child.is_dir() {
            collect_entries(
                &child,
                depth + 1,
                max_depth,
                god_recognition,
                content_type_recognition,
                god_titles,
                dlc_titles,
                out,
                god_matches,
                content_type_matches,
                dlc_matches,
                unreadable_count,
                full_disk_access_needed,
            )?;
        }
    }

    Ok(())
}

#[derive(Serialize)]
struct ListingSummary {
    entries_written: u32,
    god_matches: u32,
    content_type_matches: u32,
    dlc_matches: u32,
    unreadable_count: u32,
    full_disk_access_needed: bool,
    output_path: Option<String>,
    // Present only when output_path is None: the full listing text, for a
    // preview popup instead of a file write.
    content: Option<String>,
}

#[tauri::command]
async fn generate_listing(
    app: AppHandle,
    root: String,
    output_path: Option<String>,
) -> Result<ListingSummary, String> {
    let (_, settings) = load_settings(&app)?;
    let root_path = PathBuf::from(&root);

    let god_titles = if settings.god_recognition {
        build_god_title_map()
    } else {
        HashMap::new()
    };
    let dlc_titles = if settings.god_recognition && settings.content_type_recognition {
        build_dlc_title_map()
    } else {
        HashMap::new()
    };

    // -1 means no depth limit; 0 means "just the selected folder itself" -
    // the header line below already covers that, so there's nothing further
    // to walk.
    let max_depth: Option<u32> = if settings.default_depth < 0 {
        None
    } else {
        Some(settings.default_depth as u32)
    };

    let mut entries = Vec::new();
    let mut god_matches = 0u32;
    let mut content_type_matches = 0u32;
    let mut dlc_matches = 0u32;
    let mut unreadable_count = 0u32;
    let mut full_disk_access_needed = false;
    if max_depth != Some(0) {
        collect_entries(
            &root_path,
            1,
            max_depth,
            settings.god_recognition,
            settings.content_type_recognition,
            &god_titles,
            &dlc_titles,
            &mut entries,
            &mut god_matches,
            &mut content_type_matches,
            &mut dlc_matches,
            &mut unreadable_count,
            &mut full_disk_access_needed,
        )?;
    }

    let mut text = String::new();
    text.push_str(&root);
    text.push('\n');
    for (depth, label) in &entries {
        text.push_str(&"  ".repeat((*depth - 1) as usize));
        text.push_str(label);
        text.push('\n');
    }

    let entries_written = entries.len() as u32;

    match output_path {
        Some(path) => {
            fs::write(&path, text)
                .map_err(|e| format!("Couldn't write {}: {}", path, e))?;
            Ok(ListingSummary {
                entries_written,
                god_matches,
                content_type_matches,
                dlc_matches,
                unreadable_count,
                full_disk_access_needed,
                output_path: Some(path),
                content: None,
            })
        }
        None => Ok(ListingSummary {
            entries_written,
            god_matches,
            content_type_matches,
            dlc_matches,
            unreadable_count,
            full_disk_access_needed,
            output_path: None,
            content: Some(text),
        }),
    }
}

#[tauri::command]
fn save_text(path: String, text: String) -> Result<(), String> {
    fs::write(&path, text).map_err(|e| format!("Couldn't write {}: {}", path, e))
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            get_settings,
            save_settings,
            pick_scan_root,
            pick_output_path,
            generate_listing,
            save_text,
            open_full_disk_access_settings,
            check_full_disk_access
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
