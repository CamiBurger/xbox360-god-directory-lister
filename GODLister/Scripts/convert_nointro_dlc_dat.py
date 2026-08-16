#!/usr/bin/env python3
"""
Converts No-Intro's "Microsoft - Xbox 360 (Digital)" DAT (ClrMamePro plaintext
format, via github.com/libretro/libretro-database) into a bundled 2-column
CSV of DLC content-ID -> name, used as GOD Lister's fallback DLC catalog.

Source: https://github.com/libretro/libretro-database
        metadat/no-intro/Microsoft - Xbox 360 (Digital).dat

Each `rom name` field is TitleID(8 hex) + ContentType(8 hex) +
ContentIDHash(42 hex) = 58 hex chars. DLC entries are identified by their
`game name` ending in "(Addon)" or "(Addon for XBLA)"; a small number of
full-game "GOD" entries use a different, longer rom-name format (a
.dataDataNNNN split-archive suffix) and are excluded by the 58-hex-char
length guard.

Re-run this script to regenerate dlc_titles_nointro.csv if the upstream DAT
is ever updated.
"""
import csv
import html
import re
import sys
import urllib.request
from pathlib import Path

DAT_URL = (
    "https://raw.githubusercontent.com/libretro/libretro-database/master/"
    "metadat/no-intro/Microsoft%20-%20Xbox%20360%20(Digital).dat"
)
OUTPUT_PATH = (
    Path(__file__).resolve().parent.parent
    / "Sources" / "GODLister" / "Resources" / "dlc_titles_nointro.csv"
)

GAME_BLOCK_RE = re.compile(r'game \(\s*name "([^"]*)".*?rom \( name "([^"]*)"', re.DOTALL)
CONTENT_ID_RE = re.compile(r"^[0-9A-Fa-f]{58}$")
DLC_NAME_SUFFIXES = ("(Addon)", "(Addon for XBLA)")


def fetch_dat() -> str:
    with urllib.request.urlopen(DAT_URL) as response:
        return response.read().decode("utf-8")


def parse_dlc_entries(dat_text: str):
    seen = {}
    for game_name, rom_name in GAME_BLOCK_RE.findall(dat_text):
        if not game_name.endswith(DLC_NAME_SUFFIXES):
            continue
        if not CONTENT_ID_RE.match(rom_name):
            continue
        content_id = rom_name[16:58].upper()
        dlc_name = html.unescape(game_name)
        seen.setdefault(content_id, dlc_name)  # first occurrence wins
    return seen


def main():
    print(f"Fetching {DAT_URL} ...", file=sys.stderr)
    dat_text = fetch_dat()

    entries = parse_dlc_entries(dat_text)
    print(f"Parsed {len(entries)} unique DLC content IDs", file=sys.stderr)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["ContentId", "DLCName"])
        for content_id in sorted(entries):
            writer.writerow([content_id, entries[content_id]])

    print(f"Wrote {OUTPUT_PATH}", file=sys.stderr)


if __name__ == "__main__":
    main()
