#!/usr/bin/env bash
# photorec_run.sh — photorec scripted-run wrapper
#
# photorec can be driven headlessly via /cmd. This avoids the ~480-item
# file type menu in the TUI. The format is a SINGLE comma-separated string
# of keywords, not a multi-line config file.
#
# This wrapper generates a sensible command string for a developer +
# music-producer home directory recovery.
#
# Usage: ./photorec_run.sh <device> <output_dir> [--whole|--free]
#   --whole: scan all blocks (slower, catches everything)
#   --free:  scan only unallocated space (faster, still catches deleted)
#
# Default: --free (which is what you want after a rm -rf on ext4)
#
# Reference: https://www.cgsecurity.org/wiki/Scripted_run

set -u

DEVICE="${1:-}"
OUTPUT_DIR="${2:-}"
MODE="${3:---free}"

if [[ -z "$DEVICE" || -z "$OUTPUT_DIR" ]]; then
    cat <<EOF >&2
Usage: $0 <device> <output_dir> [--whole|--free]

Examples:
    $0 /dev/nvme0n1p3 /mnt/ext/photorec-out
    $0 /dev/nvme0n1p3 /mnt/ext/photorec-out --whole

Modes:
    --free    Scan unallocated space only (default, faster)
    --whole   Scan entire partition including allocated data

Output goes to OUTPUT_DIR/recup_dir.1/, .2/, etc.
EOF
    exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: $DEVICE is not a block device" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Sanity: output should NOT be on the device being scanned
if findmnt -n -o SOURCE --target "$OUTPUT_DIR" 2>/dev/null | grep -q "^$DEVICE"; then
    echo "ERROR: output dir is on the same device you're scanning — this would overwrite data" >&2
    exit 1
fi

case "$MODE" in
    --free) SCAN_MODE="freespace" ;;
    --whole) SCAN_MODE="wholespace" ;;
    *) echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac

# File type selection. photorec's /cmd syntax:
#   fileopt,everything,(enable|disable),<ext>,(enable|disable),...
# We disable everything then re-enable only high-value types for a
# developer + music producer home dir.
#
# Categories enabled:
#   Audio: wav, flac, mp3, ogg, aif, au, mid, mod, it, xm, s3m
#   Archives (xrns, docx, etc. all ride on zip): zip, 7z, rar, gz, bz2, tar, xz
#   Images: jpg, png, gif, tiff, bmp, webp, raw formats
#   Documents: pdf, doc, rtf, odt
#   Video: mov (covers mp4 family), mkv, avi, webm, riff
#   Databases: sqlite (Firefox profile)
#   Fonts: ttf
#
# Note: PhotoRec groups many formats. "riff" covers wav/avi/cdr. "mov"
# covers mp4/m4a/m4v. So enabling fewer keywords still covers broad scope.
#
# "everything,disable" followed by per-extension "enable" is the canonical
# narrowing pattern.
FILEOPTS="fileopt,everything,disable"
FILEOPTS+=",wav,enable,flac,enable,mp3,enable,ogg,enable,au,enable"
FILEOPTS+=",aif,enable,mid,enable,mod,enable,it,enable,xm,enable,s3m,enable"
FILEOPTS+=",zip,enable,7z,enable,rar,enable,gz,enable,bz2,enable,tar,enable,xz,enable"
FILEOPTS+=",jpg,enable,png,enable,gif,enable,tif,enable,bmp,enable,webp,enable"
FILEOPTS+=",raw,enable,cr2,enable,nef,enable,orf,enable,arw,enable,dng,enable"
FILEOPTS+=",pdf,enable,doc,enable,rtf,enable"
FILEOPTS+=",mov,enable,mkv,enable,avi,enable,webm,enable,riff,enable"
FILEOPTS+=",sqlite,enable"
FILEOPTS+=",ttf,enable"

# Full command string. Order matters for /cmd:
#   1. Partition table detection
#   2. Partition selection (here: auto since we pass a partition device)
#   3. options (mode_ext2 for ext2/3/4 inode-aware scan)
#   4. fileopt chain
#   5. freespace/wholespace
#   6. search (trigger)
CMD="options,mode_ext2,$FILEOPTS,$SCAN_MODE,search"

LOGFILE="$OUTPUT_DIR/photorec.log"

echo "Running photorec with:"
echo "  device:  $DEVICE"
echo "  output:  $OUTPUT_DIR"
echo "  mode:    $MODE ($SCAN_MODE)"
echo "  log:     $LOGFILE"
echo ""
echo "Command:"
echo "  photorec /log /logname $LOGFILE /d $OUTPUT_DIR/recup_dir /cmd $DEVICE $CMD"
echo ""
echo "This will run for HOURS on a large partition. Detach from tmux with Ctrl-b d."
echo "Press Ctrl-C within 10 seconds to cancel..."
sleep 10

# Run it. /d specifies output path prefix — photorec adds .1, .2 etc.
sudo photorec /log /logname "$LOGFILE" /d "$OUTPUT_DIR/recup_dir" /cmd "$DEVICE" "$CMD"
