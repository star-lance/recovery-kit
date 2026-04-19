#!/usr/bin/env bash
# search_recovered.sh — ripgrep over recovered text files for known strings
#
# Use this to find specific recovered content by searching for unique strings
# you remember being in files. Examples:
#   - Project names
#   - Function names from code you wrote
#   - Unique phrases from notes
#   - API tokens / identifiers
#   - Unique filenames referenced elsewhere
#
# Usage: ./search_recovered.sh <input_dir> <pattern> [output_dir]

set -u

INPUT_DIR="${1:-}"
PATTERN="${2:-}"
OUTPUT_DIR="${3:-}"

if [[ -z "$INPUT_DIR" || -z "$PATTERN" ]]; then
    echo "Usage: $0 <input_dir> <pattern> [output_dir]" >&2
    echo "Examples:" >&2
    echo "  $0 /mnt/ext/photorec-out 'NoteWarden'" >&2
    echo "  $0 /mnt/ext/photorec-out 'power.?dialer' /mnt/ext/dialer-matches" >&2
    exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep (rg) required. Install with: pacman -S ripgrep" >&2
    exit 1
fi

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    echo "Searching for '$PATTERN' in $INPUT_DIR, copying matches to $OUTPUT_DIR..."
    # rg --files-with-matches is fast. Follow with cp.
    rg -l --no-ignore --hidden -a "$PATTERN" "$INPUT_DIR" 2>/dev/null | while IFS= read -r f; do
        cp --parents "$f" "$OUTPUT_DIR/" 2>/dev/null || cp "$f" "$OUTPUT_DIR/"
        echo "  matched: $f"
    done
else
    echo "Searching for '$PATTERN' in $INPUT_DIR..."
    rg --no-ignore --hidden -a -l "$PATTERN" "$INPUT_DIR"
fi
