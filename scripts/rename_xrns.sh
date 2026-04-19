#!/usr/bin/env bash
# rename_xrns.sh — identify Renoise projects in photorec output
#
# Renoise XRNS files are ZIP archives containing Song.xml with
# <RenoiseSong doc_version="NN"> as the root element. Photorec
# recovers them as generic .zip files because it sees the ZIP header.
#
# This script walks a photorec output tree, peeks into each .zip, and
# if it contains Song.xml with a RenoiseSong root, copies the file to
# an output directory with a .xrns extension. When possible, the song
# name is extracted from the XML.
#
# Handles partially corrupted zip files gracefully (photorec carving
# frequently produces zips with damaged central directories).
#
# Usage: ./rename_xrns.sh <photorec_output_dir> [output_dir]

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT_DIR" ]]; then
    echo "Usage: $0 <photorec_output_dir> [output_dir]" >&2
    exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Input directory not found: $INPUT_DIR" >&2
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_DIR")/xrns-recovered"
fi

mkdir -p "$OUTPUT_DIR"

for cmd in unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

sanitize() {
    # Strip characters that cause filesystem trouble
    printf '%s' "$1" | tr -d '\0' | tr '/\\:*?"<>|' '_' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Extract song name from Renoise Song.xml.
# Tries several XPath-like patterns in order, since the exact tag depends
# on the doc_version. Falls back to empty string if nothing found.
extract_song_name() {
    local xml_content="$1"
    local name=""

    # Common patterns seen across Renoise versions:
    # <GlobalSongData><SongName>...</SongName></GlobalSongData>
    # <SongName>...</SongName> directly under RenoiseSong
    # <Name>...</Name> inside various containers
    for pattern in \
        '<SongName>([^<]+)</SongName>' \
        '<Name>([^<]+)</Name>' \
        '<song_name>([^<]+)</song_name>' \
        '<GlobalSongData>[[:space:]]*<[Nn]ame>([^<]+)<'
    do
        name=$(echo "$xml_content" | grep -oP "$pattern" | head -1 | sed -E 's/<[^>]+>//g' | head -1)
        if [[ -n "$name" ]]; then
            printf '%s' "$name"
            return
        fi
    done
}

process_zip() {
    local zipfile="$1"

    # Check zip integrity enough to list contents. unzip -l is lenient.
    # If this fails outright, skip.
    if ! unzip -l "$zipfile" >/dev/null 2>&1; then
        return 1
    fi

    # Must contain Song.xml
    if ! unzip -l "$zipfile" 2>/dev/null | grep -qE '[[:space:]]Song\.xml$'; then
        return 1
    fi

    # Extract Song.xml to stdout
    local xml
    xml=$(unzip -p "$zipfile" Song.xml 2>/dev/null | head -c 16384) || return 1
    [[ -z "$xml" ]] && return 1

    # Confirm it's a Renoise song file
    if ! echo "$xml" | grep -q '<RenoiseSong'; then
        return 1
    fi

    # Try to extract a meaningful name
    local song_name
    song_name=$(extract_song_name "$xml")

    # doc_version for bookkeeping
    local doc_version
    doc_version=$(echo "$xml" | grep -oP 'doc_version="[0-9]+"' | head -1 | grep -oP '[0-9]+' || true)

    # Build filename
    local basename_src
    basename_src=$(basename "$zipfile" .zip)
    [[ -z "$song_name" ]] && song_name="Untitled_${basename_src}"
    song_name=$(sanitize "$song_name")
    [[ -z "$song_name" ]] && song_name="Untitled_${basename_src}"

    local dest_base="$song_name"
    [[ -n "$doc_version" ]] && dest_base="${dest_base}_v${doc_version}"
    local dest="$OUTPUT_DIR/${dest_base}.xrns"

    # Avoid collisions
    local counter=1
    while [[ -e "$dest" ]]; do
        dest="$OUTPUT_DIR/${dest_base}_${counter}.xrns"
        counter=$((counter + 1))
    done

    cp "$zipfile" "$dest"
    printf '  [FOUND] %s -> %s\n' "$(basename "$zipfile")" "$(basename "$dest")"

    return 0
}

found=0
checked=0

echo "Scanning $INPUT_DIR for Renoise projects..."

while IFS= read -r -d '' zipfile; do
    checked=$((checked + 1))
    if (( checked % 100 == 0 )); then
        echo "  ... scanned $checked zips, found $found xrns so far"
    fi
    if process_zip "$zipfile"; then
        found=$((found + 1))
    fi
done < <(find "$INPUT_DIR" -type f \( -iname '*.zip' -o -iname '*.xrns' \) -print0)

echo ""
echo "Done. Scanned $checked archives, identified $found Renoise projects."
echo "Output: $OUTPUT_DIR"
