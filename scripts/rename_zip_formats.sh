#!/usr/bin/env bash
# rename_zip_formats.sh — identify zip-based file formats in photorec output
#
# Handles: docx, xlsx, pptx, odt, ods, odp, epub, jar, apk, and anything
# else that's actually a zip underneath. For Office formats, attempts to
# extract the document title from docProps/core.xml.
#
# Usage: ./rename_zip_formats.sh <photorec_output_dir> [output_dir]

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT_DIR" ]]; then
    echo "Usage: $0 <photorec_output_dir> [output_dir]" >&2
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_DIR")/zipformats-recovered"
fi

mkdir -p "$OUTPUT_DIR"/{docx,xlsx,pptx,odt,ods,odp,epub,jar,apk,xrns,unknown}

for cmd in unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

sanitize() {
    printf '%s' "$1" | tr -d '\0' | tr '/\\:*?"<>|' '_' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Identify zip type by looking at the file listing and, for ODF/epub
# files, reading the mimetype member (which by spec is the first entry
# and stored uncompressed).
identify_zip() {
    local zipfile="$1"

    # Get list of files inside; abort on broken zip
    local contents
    contents=$(unzip -l "$zipfile" 2>/dev/null | awk 'NR>3 && NF>=4 {print $NF}') || return 1
    [[ -z "$contents" ]] && return 1

    # Renoise: Song.xml at root
    if echo "$contents" | grep -qx 'Song.xml'; then
        echo "xrns"; return 0
    fi

    # OOXML formats have characteristic subdirectory files
    if echo "$contents" | grep -qx 'word/document.xml'; then
        echo "docx"; return 0
    fi
    if echo "$contents" | grep -qx 'xl/workbook.xml'; then
        echo "xlsx"; return 0
    fi
    if echo "$contents" | grep -qx 'ppt/presentation.xml'; then
        echo "pptx"; return 0
    fi

    # ODF and epub both have a 'mimetype' file at root with specific content
    if echo "$contents" | grep -qx 'mimetype'; then
        local mime
        mime=$(unzip -p "$zipfile" mimetype 2>/dev/null | head -c 200)
        case "$mime" in
            *opendocument.text*)          echo "odt";  return 0 ;;
            *opendocument.spreadsheet*)   echo "ods";  return 0 ;;
            *opendocument.presentation*)  echo "odp";  return 0 ;;
            *application/epub*)           echo "epub"; return 0 ;;
        esac
    fi

    # Android APK: has AndroidManifest.xml in addition to META-INF
    if echo "$contents" | grep -qx 'AndroidManifest.xml'; then
        echo "apk"; return 0
    fi

    # JAR: has META-INF/MANIFEST.MF but no AndroidManifest.xml
    if echo "$contents" | grep -qx 'META-INF/MANIFEST.MF'; then
        echo "jar"; return 0
    fi

    echo "unknown"
    return 0
}

extract_ooxml_title() {
    local zipfile="$1"
    unzip -p "$zipfile" docProps/core.xml 2>/dev/null | \
        grep -oP '(?<=<dc:title>)[^<]+(?=</dc:title>)' | head -1 || true
}

found=0
checked=0

echo "Scanning $INPUT_DIR for zip-based formats..."

while IFS= read -r -d '' zipfile; do
    checked=$((checked + 1))
    if (( checked % 100 == 0 )); then
        echo "  scanned $checked archives..."
    fi

    type=$(identify_zip "$zipfile") || continue
    [[ -z "$type" ]] && continue

    basename_src=$(basename "$zipfile" .zip)
    dest_name="$basename_src"

    # Try to get a real name for Office docs
    case "$type" in
        docx|xlsx|pptx)
            title=$(extract_ooxml_title "$zipfile")
            if [[ -n "$title" ]]; then
                title=$(sanitize "$title")
                [[ -n "$title" ]] && dest_name="$title"
            fi
            ;;
    esac

    dest="$OUTPUT_DIR/$type/${dest_name}.${type}"
    counter=1
    while [[ -e "$dest" ]]; do
        dest="$OUTPUT_DIR/$type/${dest_name}_${counter}.${type}"
        counter=$((counter + 1))
    done
    cp "$zipfile" "$dest"
    found=$((found + 1))
done < <(find "$INPUT_DIR" -type f -iname '*.zip' -print0)

echo ""
echo "Scanned $checked archives, identified $found recognized formats."
echo "Output tree: $OUTPUT_DIR"
for d in "$OUTPUT_DIR"/*/; do
    [[ -d "$d" ]] || continue
    count=$(find "$d" -maxdepth 1 -type f | wc -l)
    (( count > 0 )) && echo "  $(basename "$d"): $count"
done
