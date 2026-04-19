#!/usr/bin/env bash
# filter_audio.sh — filter audio recoveries to keep only "real" files
#
# Photorec recovers tons of tiny audio fragments that are useless.
# This script copies audio files above a minimum size threshold to
# a clean directory, optionally with duration check via ffprobe.
#
# Usage: ./filter_audio.sh <input_dir> <output_dir> [min_size_kb] [min_duration_sec]
# Defaults: min_size_kb=500 (500KB), min_duration_sec=10

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"
MIN_SIZE_KB="${3:-500}"
MIN_DURATION="${4:-10}"

if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <input_dir> <output_dir> [min_size_kb] [min_duration_sec]" >&2
    exit 1
fi

HAVE_FFPROBE=0
if command -v ffprobe >/dev/null 2>&1; then
    HAVE_FFPROBE=1
fi

mkdir -p "$OUTPUT_DIR"/{wav,flac,mp3,ogg,aiff,mid,other}

get_duration() {
    local f="$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null | \
        awk '{printf "%d\n", $1}'
}

kept=0
rejected_size=0
rejected_duration=0
min_size_bytes=$((MIN_SIZE_KB * 1024))

while IFS= read -r -d '' f; do
    size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    if (( size < min_size_bytes )); then
        rejected_size=$((rejected_size + 1))
        continue
    fi

    if [[ $HAVE_FFPROBE -eq 1 ]]; then
        duration=$(get_duration "$f")
        if [[ -n "$duration" ]] && (( duration < MIN_DURATION )); then
            rejected_duration=$((rejected_duration + 1))
            continue
        fi
    fi

    ext="${f##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext_lower" in
        wav)  subdir="wav" ;;
        flac) subdir="flac" ;;
        mp3)  subdir="mp3" ;;
        ogg|oga) subdir="ogg" ;;
        aif|aiff) subdir="aiff" ;;
        mid|midi) subdir="mid" ;;
        *)    subdir="other" ;;
    esac

    basename_f=$(basename "$f")
    dest="$OUTPUT_DIR/$subdir/$basename_f"
    counter=1
    while [[ -e "$dest" ]]; do
        dest="$OUTPUT_DIR/$subdir/${basename_f%.*}_${counter}.${basename_f##*.}"
        counter=$((counter + 1))
    done
    cp "$f" "$dest"
    kept=$((kept + 1))
done < <(find "$INPUT_DIR" -type f \( \
    -iname '*.wav' -o -iname '*.flac' -o -iname '*.mp3' -o \
    -iname '*.ogg' -o -iname '*.oga' -o -iname '*.aif' -o \
    -iname '*.aiff' -o -iname '*.mid' -o -iname '*.midi' \
\) -print0)

echo ""
echo "Kept:               $kept"
echo "Rejected (size):    $rejected_size"
echo "Rejected (duration): $rejected_duration"
echo "Output: $OUTPUT_DIR"
