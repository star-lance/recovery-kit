#!/usr/bin/env bash
# backup_journal.sh — copy the ext4 journal to external storage BEFORE recovery
#
# This is the SINGLE MOST IMPORTANT STEP before running ext4magic.
# From the ext4magic documentation:
#   "It's important to create this journal copy immediately before a new mount
#    of the file system. Otherwise some journal data will be destroyed and lost."
#
# The journal holds the inode copies ext4magic uses to recover filenames and
# paths. Every mount, every read from a mounted fs, and every background
# process nibbles at journal data. Dumping a copy now lets you replay
# recovery attempts against a frozen snapshot, which is priceless.
#
# Usage: ./backup_journal.sh <block_device> <output_path>
# Example: ./backup_journal.sh /dev/nvme0n1p3 /mnt/ext/journal.copy

set -u

DEVICE="${1:-}"
OUTPUT="${2:-}"

if [[ -z "$DEVICE" || -z "$OUTPUT" ]]; then
    cat <<EOF >&2
Usage: $0 <block_device> <output_path>

Examples:
    $0 /dev/nvme0n1p3 /mnt/ext/journal.copy
    $0 /dev/sda3 /mnt/recovery/journal.bin

OUTPUT must be on a DIFFERENT filesystem than the device being recovered.
EOF
    exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: $DEVICE is not a block device" >&2
    exit 1
fi

if [[ -e "$OUTPUT" ]]; then
    echo "ERROR: $OUTPUT already exists — refusing to overwrite" >&2
    exit 1
fi

# Sanity check: is output on a DIFFERENT fs than the device?
output_dir=$(dirname "$OUTPUT")
if ! mkdir -p "$output_dir" 2>/dev/null; then
    echo "ERROR: cannot create output directory $output_dir" >&2
    exit 1
fi

output_fs_source=$(findmnt -n -o SOURCE --target "$output_dir" 2>/dev/null || true)
if [[ "$output_fs_source" == "$DEVICE"* ]]; then
    echo "ERROR: output path is on the same device you're trying to recover from" >&2
    echo "  device:       $DEVICE" >&2
    echo "  output on fs: $output_fs_source" >&2
    echo "Use an external drive." >&2
    exit 1
fi

if ! command -v debugfs >/dev/null 2>&1; then
    echo "ERROR: debugfs not found (install e2fsprogs)" >&2
    exit 1
fi

# Confirm device is NOT mounted read-write
rw_mount=$(findmnt -n -o OPTIONS --source "$DEVICE" 2>/dev/null | grep -v -E '(^|,)ro(,|$)' || true)
if [[ -n "$rw_mount" ]]; then
    echo "WARNING: $DEVICE appears to be mounted read-write." >&2
    echo "Continuing anyway, but recovery may fail and data may be lost." >&2
    echo "Press Ctrl-C within 10 seconds to abort..." >&2
    sleep 10
fi

echo "Backing up journal from $DEVICE to $OUTPUT..."
echo "Command: debugfs -R \"dump <8> $OUTPUT\" $DEVICE"
echo ""

# The ext4 journal is always inode 8
if sudo debugfs -R "dump <8> $OUTPUT" "$DEVICE"; then
    if [[ -s "$OUTPUT" ]]; then
        size=$(stat -c '%s' "$OUTPUT")
        size_mb=$((size / 1024 / 1024))
        echo ""
        echo "Journal backup successful."
        echo "  File:  $OUTPUT"
        echo "  Size:  ${size_mb} MB ($size bytes)"
        echo ""
        echo "Use with ext4magic like:"
        echo "  ext4magic $DEVICE -j $OUTPUT -a <timestamp> -r -d /path/to/recovery"
        exit 0
    else
        echo "ERROR: journal dump produced empty file" >&2
        rm -f "$OUTPUT"
        exit 1
    fi
else
    echo "ERROR: debugfs dump failed" >&2
    exit 1
fi
