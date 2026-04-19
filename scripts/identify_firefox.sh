#!/usr/bin/env bash
# identify_firefox.sh — find Firefox profile files among photorec SQLite recoveries
#
# Photorec recovers SQLite files as .sqlite. Firefox profile has well-known
# schema names. This script opens each and checks the table names to identify:
#   - places.sqlite (history & bookmarks)
#   - cookies.sqlite
#   - formhistory.sqlite
#   - permissions.sqlite
#   - favicons.sqlite
#   - storage.sqlite
#   - webappsstore.sqlite
#   - key4.db (logins — though this is encrypted, needs key + logins.json to decrypt)
#
# Usage: ./identify_firefox.sh <photorec_output_dir> [output_dir]

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT_DIR" ]]; then
    echo "Usage: $0 <photorec_output_dir> [output_dir]" >&2
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_DIR")/firefox-recovered"
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "Required command not found: sqlite3" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"/{places,cookies,formhistory,permissions,favicons,storage,other}

identify_sqlite() {
    local f="$1"
    # Get table names — errors out silently if file is corrupt
    local tables
    tables=$(sqlite3 "$f" '.tables' 2>/dev/null) || return 1
    [[ -z "$tables" ]] && return 1

    # Firefox schema fingerprints
    if echo "$tables" | grep -qw 'moz_places' && echo "$tables" | grep -qw 'moz_bookmarks'; then
        echo "places"; return 0
    fi
    if echo "$tables" | grep -qw 'moz_cookies'; then
        echo "cookies"; return 0
    fi
    if echo "$tables" | grep -qw 'moz_formhistory'; then
        echo "formhistory"; return 0
    fi
    if echo "$tables" | grep -qw 'moz_perms' || echo "$tables" | grep -qw 'moz_hosts'; then
        echo "permissions"; return 0
    fi
    if echo "$tables" | grep -qw 'moz_icons' || echo "$tables" | grep -qw 'moz_pages_w_icons'; then
        echo "favicons"; return 0
    fi
    if echo "$tables" | grep -qw 'webappsstore2' || echo "$tables" | grep -qw 'object_data'; then
        echo "storage"; return 0
    fi

    echo "other"
    return 0
}

found=0
checked=0
declare -A counts

echo "Scanning SQLite files in $INPUT_DIR..."

while IFS= read -r -d '' f; do
    checked=$((checked + 1))
    if (( checked % 50 == 0 )); then
        echo "  scanned $checked sqlite files..."
    fi

    # Skip tiny files — likely fragments
    size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    (( size < 4096 )) && continue

    type=$(identify_sqlite "$f") || continue
    [[ -z "$type" ]] && continue

    basename_f=$(basename "$f")
    dest="$OUTPUT_DIR/$type/$basename_f"
    counter=1
    while [[ -e "$dest" ]]; do
        dest="$OUTPUT_DIR/$type/${basename_f%.*}_${counter}.${basename_f##*.}"
        counter=$((counter + 1))
    done
    cp "$f" "$dest"
    found=$((found + 1))
    counts[$type]=$((${counts[$type]:-0} + 1))
done < <(find "$INPUT_DIR" -type f -iname '*.sqlite' -print0)

echo ""
echo "Scanned $checked SQLite files. Identified $found Firefox-related:"
for type in "${!counts[@]}"; do
    echo "  $type: ${counts[$type]}"
done
echo ""
echo "Output: $OUTPUT_DIR"
echo ""
echo "NEXT STEPS:"
echo "  - places/: contains history & bookmarks. Open with Firefox or: "
echo "      sqlite3 <file> 'SELECT url, title, visit_count FROM moz_places ORDER BY visit_count DESC LIMIT 50;'"
echo "  - Most recent places.sqlite is the most useful. Sort by file size (larger = more history)."
echo "  - cookies.sqlite: rarely useful alone."
echo "  - For saved logins: recover key4.db AND logins.json together. Without both, logins are unrecoverable."
