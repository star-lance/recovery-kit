#!/usr/bin/env bash
# sort_by_type.sh — organize photorec output into subfolders by file type
#
# Photorec dumps everything into recup_dir.N/ folders with extension-based
# names like f0000001.jpg. This script uses libmagic (`file` command) to
# verify the actual type and symlinks (or copies) files into a cleaner
# directory structure organized by MIME category.
#
# Usage: ./sort_by_type.sh <photorec_output_dir> <sorted_output_dir> [--copy|--symlink]
# Default is --symlink (saves space). Use --copy if you want hard copies.

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"
MODE="${3:---symlink}"

if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <photorec_output_dir> <sorted_output_dir> [--copy|--symlink]" >&2
    exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Input directory not found: $INPUT_DIR" >&2
    exit 1
fi

if ! command -v file >/dev/null 2>&1; then
    echo "Required command not found: file" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

copy_or_link() {
    local src="$1" dst="$2"
    if [[ "$MODE" == "--copy" ]]; then
        cp "$src" "$dst"
    else
        ln -s "$src" "$dst"
    fi
}

categorize() {
    local mime="$1"
    case "$mime" in
        audio/*)           echo "audio" ;;
        video/*)           echo "video" ;;
        image/*)           echo "images" ;;
        application/pdf)   echo "pdf" ;;
        application/zip|application/x-7z*|application/x-rar|application/x-tar|application/gzip|application/x-xz|application/x-bzip2)
                           echo "archives" ;;
        application/msword|application/vnd.openxmlformats*|application/vnd.ms-*|application/vnd.oasis*)
                           echo "documents" ;;
        application/x-sqlite3)
                           echo "sqlite" ;;
        text/*)            echo "text" ;;
        application/json)  echo "text" ;;
        application/xml)   echo "text" ;;
        application/x-executable|application/x-sharedlib|application/x-mach-binary|application/x-dosexec)
                           echo "executables" ;;
        font/*|application/x-font-*|application/vnd.ms-opentype)
                           echo "fonts" ;;
        *)                 echo "other" ;;
    esac
}

total=0
start_time=$(date +%s)

echo "Sorting files from $INPUT_DIR into $OUTPUT_DIR (mode: $MODE)..."

# Use absolute path for symlinks to work from anywhere
INPUT_ABS=$(readlink -f "$INPUT_DIR")

while IFS= read -r -d '' f; do
    total=$((total + 1))
    if (( total % 500 == 0 )); then
        elapsed=$(( $(date +%s) - start_time ))
        echo "  processed $total files in ${elapsed}s..."
    fi

    mime=$(file -b --mime-type "$f" 2>/dev/null || echo "application/octet-stream")
    category=$(categorize "$mime")
    mime_sanitized="${mime//\//_}"

    dest_dir="$OUTPUT_DIR/$category/$mime_sanitized"
    mkdir -p "$dest_dir"

    basename_f=$(basename "$f")
    dest="$dest_dir/$basename_f"

    counter=1
    while [[ -e "$dest" ]]; do
        dest="$dest_dir/${basename_f%.*}_${counter}.${basename_f##*.}"
        counter=$((counter + 1))
    done

    copy_or_link "$(readlink -f "$f")" "$dest"
done < <(find "$INPUT_ABS" -type f -print0)

echo ""
echo "Sorted $total files."
echo "Summary by category:"
for d in "$OUTPUT_DIR"/*/; do
    [[ -d "$d" ]] || continue
    count=$(find "$d" -type f -o -type l | wc -l)
    echo "  $(basename "$d"): $count files"
done
