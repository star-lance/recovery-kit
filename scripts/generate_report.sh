#!/usr/bin/env bash
# generate_report.sh — snapshot current recovery state into a single report
#
# Run this after Pass 1 (rsync of allocated) and Pass 2 (tsk_recover) but
# BEFORE launching photorec. The output gives a complete picture of:
#   - What tools are present
#   - What rescued data we have so far (sizes, directory structure)
#   - Whether critical user-specified directories came back
#   - Free space available for photorec
#   - Filesystem stats
#   - Deleted-entry counts by important keyword
#
# Commit the output to the repo, push, paste into chat for analysis.
#
# Usage: ./generate_report.sh [output_file]
# Default output: logs/recovery-report-<timestamp>.md

set -u

# Paths — edit these if your setup differs
NVME_DEVICE="/dev/nvme0n1p3"
EXT_MOUNT="/mnt/ext"
RESCUED_ALLOCATED="$EXT_MOUNT/rescued-allocated"
RESCUED_DELETED="$EXT_MOUNT/rescued-deleted"
PHOTOREC_OUT="$EXT_MOUNT/photorec-out"
JOURNAL_COPY="$EXT_MOUNT/journal.copy"
LOGS_DIR="$EXT_MOUNT/logs"

# Critical directories the user cares about (customize as needed)
CRITICAL_DIRS=(
    "home/star/audio"
    "home/star/STARDUST"
    "home/star/Documents"
    "home/star/Music"
    "home/star/.config"
    "home/star/.ssh"
    "home/star/Renoise"
    "home/star/.local/share/Renoise"
    "home/star/projects"
    "home/star/code"
    "home/star/dev"
)

# Keywords for greppable file types
GREP_KEYWORDS=(
    "xrns"
    "renoise"
    "\\.wav"
    "\\.flac"
    "\\.mp3"
    "\\.ogg"
    "\\.fxp"
    "\\.vital"
    "\\.xrni"
    "\\.xrnt"
    "\\.mid"
)

TIMESTAMP=$(date -u '+%Y%m%d-%H%M%SZ')
OUT="${1:-$(dirname "$0")/../logs/recovery-report-$TIMESTAMP.md}"
OUT_DIR=$(dirname "$OUT")
mkdir -p "$OUT_DIR"

exec > "$OUT" 2>&1

echo "# Recovery Status Report"
echo ""
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Host: $(hostname) — $(uname -a)"
echo ""

# ---------------------------------------------------------------------------
echo "## 1. Environment"
echo ""
echo '```'
if [[ -f /etc/os-release ]]; then
    grep -E '^(NAME|VERSION|PRETTY_NAME)=' /etc/os-release
fi
echo ""
echo "Memory:"
free -h
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 2. Tool availability"
echo ""
echo '```'
for tool in photorec testdisk fls tsk_recover icat ifind istat debugfs jls jcat \
            ddrescue smartctl sqlite3 ffprobe unzip file rsync ripgrep tmux \
            ext4magic extundelete; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'OK   %-15s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'MISS %-15s\n' "$tool"
    fi
done
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 3. Block devices"
echo ""
echo '```'
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS 2>/dev/null || lsblk -f
echo '```'
echo ""
echo '```'
echo "findmnt for $NVME_DEVICE:"
findmnt -S "$NVME_DEVICE" 2>/dev/null || echo "(not mounted)"
echo ""
echo "findmnt for $EXT_MOUNT:"
findmnt --target "$EXT_MOUNT" 2>/dev/null || echo "(not found)"
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 4. NVMe health (SMART)"
echo ""
echo '```'
if command -v smartctl >/dev/null 2>&1; then
    nvme_dev=$(echo "$NVME_DEVICE" | sed -E 's/p[0-9]+$//')
    sudo smartctl -H "$nvme_dev" 2>&1 | grep -iE '(health|status|passed|failed)' || echo "(smartctl -H returned no recognizable output)"
    echo ""
    sudo smartctl -A "$nvme_dev" 2>&1 | grep -iE '(percentage.*used|available.*spare|data.*written|unsafe.*shut)' || true
else
    echo "smartctl not installed"
fi
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 5. Filesystem stats"
echo ""
echo '```'
if command -v fsstat >/dev/null 2>&1; then
    sudo fsstat "$NVME_DEVICE" 2>&1 | head -50
else
    echo "fsstat not installed"
fi
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 6. Rescue progress — sizes and disk usage"
echo ""
echo '```'
echo "External drive ($EXT_MOUNT):"
df -h "$EXT_MOUNT" 2>/dev/null
echo ""
echo "Rescue directories:"
for d in "$RESCUED_ALLOCATED" "$RESCUED_DELETED" "$PHOTOREC_OUT"; do
    if [[ -d "$d" ]]; then
        size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
        count=$(find "$d" -type f 2>/dev/null | wc -l)
        printf '%-40s %10s  %10s files\n' "$d" "$size" "$count"
    else
        printf '%-40s %10s\n' "$d" "(does not exist)"
    fi
done
echo ""
echo "Journal backup:"
if [[ -f "$JOURNAL_COPY" ]]; then
    ls -lh "$JOURNAL_COPY"
else
    echo "$JOURNAL_COPY: does not exist"
fi
echo '```'
echo ""

# ---------------------------------------------------------------------------
echo "## 7. Critical directory survival check"
echo ""
echo "For each user-important path, checks what's present in each rescue dir."
echo ""
for d in "${CRITICAL_DIRS[@]}"; do
    echo "### \`/$d\`"
    echo ""

    # Pass 1 location: rsync dumps home/star content to root of rescued-allocated
    # so /home/star/audio -> /mnt/ext/rescued-allocated/audio
    stripped="${d#home/star/}"
    alloc_path="$RESCUED_ALLOCATED/$stripped"

    # Pass 2 location: tsk_recover preserves full path from filesystem root
    deleted_path="$RESCUED_DELETED/$d"

    echo '```'
    if [[ -d "$alloc_path" ]]; then
        count=$(find "$alloc_path" -type f 2>/dev/null | wc -l)
        size=$(du -sh "$alloc_path" 2>/dev/null | awk '{print $1}')
        echo "rescued-allocated: $count files, $size"
        echo "  top entries:"
        find "$alloc_path" -maxdepth 2 2>/dev/null | head -15 | sed 's|^|    |'
    elif [[ -f "$alloc_path" ]]; then
        echo "rescued-allocated: file exists ($(stat -c '%s' "$alloc_path") bytes)"
    else
        echo "rescued-allocated: MISSING"
    fi
    echo ""
    if [[ -d "$deleted_path" ]]; then
        count=$(find "$deleted_path" -type f 2>/dev/null | wc -l)
        size=$(du -sh "$deleted_path" 2>/dev/null | awk '{print $1}')
        echo "rescued-deleted:   $count files, $size"
        echo "  top entries:"
        find "$deleted_path" -maxdepth 2 2>/dev/null | head -15 | sed 's|^|    |'
    elif [[ -f "$deleted_path" ]]; then
        echo "rescued-deleted:   file exists ($(stat -c '%s' "$deleted_path") bytes)"
    else
        echo "rescued-deleted:   MISSING"
    fi
    echo '```'
    echo ""
done

# ---------------------------------------------------------------------------
echo "## 8. fls deleted-entry analysis"
echo ""
FLS_DEL="$LOGS_DIR/fls-deleted.txt"
if [[ -f "$FLS_DEL" ]]; then
    echo '```'
    echo "File: $FLS_DEL"
    wc -l "$FLS_DEL"
    echo ""
    total=$(wc -l < "$FLS_DEL")
    realloc=$(grep -c '(realloc)' "$FLS_DEL" 2>/dev/null || echo 0)
    echo "total entries:       $total"
    echo "entries reallocated: $realloc"
    echo ""
    echo "By critical directory:"
    for d in "${CRITICAL_DIRS[@]}"; do
        count=$(grep -c "$d" "$FLS_DEL" 2>/dev/null || echo 0)
        printf '  %-45s %8d\n' "$d" "$count"
    done
    echo ""
    echo "By file type keyword:"
    for k in "${GREP_KEYWORDS[@]}"; do
        count=$(grep -ci "$k" "$FLS_DEL" 2>/dev/null || echo 0)
        printf '  %-25s %8d\n' "$k" "$count"
    done
    echo '```'
    echo ""
    echo "### Sample deleted entries mentioning critical keywords"
    echo ""
    echo '```'
    for d in "${CRITICAL_DIRS[@]}"; do
        hits=$(grep "$d" "$FLS_DEL" 2>/dev/null | head -10)
        if [[ -n "$hits" ]]; then
            echo "--- $d ---"
            echo "$hits"
            echo ""
        fi
    done
    echo '```'
    echo ""
    echo "### Sample audio/project files in deleted entries"
    echo ""
    echo '```'
    grep -iE '\.(wav|flac|mp3|ogg|aif|xrns|xrni|mid|fxp|vital)' "$FLS_DEL" 2>/dev/null | head -40
    echo '```'
else
    echo "_fls-deleted.txt not found at $FLS_DEL_"
fi
echo ""

# ---------------------------------------------------------------------------
echo "## 9. fls all-entries analysis (allocated + deleted)"
echo ""
FLS_ALL="$LOGS_DIR/fls-all.txt"
if [[ -f "$FLS_ALL" ]]; then
    echo '```'
    echo "File: $FLS_ALL"
    wc -l "$FLS_ALL"
    echo ""
    echo "Entries still present for critical dirs (non-deleted):"
    for d in "${CRITICAL_DIRS[@]}"; do
        count=$(grep "$d" "$FLS_ALL" 2>/dev/null | grep -cv '\*' || echo 0)
        printf '  %-45s %8d\n' "$d" "$count"
    done
    echo '```'
else
    echo "_fls-all.txt not found at $FLS_ALL_"
fi
echo ""

# ---------------------------------------------------------------------------
echo "## 10. tsk_recover log summary"
echo ""
TSK_LOG="$LOGS_DIR/tsk-recover.log"
if [[ -f "$TSK_LOG" ]]; then
    echo '```'
    echo "Last 30 lines of $TSK_LOG:"
    tail -30 "$TSK_LOG"
    echo '```'
else
    echo "_tsk-recover.log not found_"
fi
echo ""

# ---------------------------------------------------------------------------
echo "## 11. File type breakdown in rescued directories"
echo ""
for label in "allocated:$RESCUED_ALLOCATED" "deleted:$RESCUED_DELETED"; do
    name="${label%%:*}"
    path="${label#*:}"
    if [[ ! -d "$path" ]]; then
        continue
    fi
    echo "### $name ($path)"
    echo ""
    echo '```'
    echo "Top 20 file extensions by count:"
    find "$path" -type f 2>/dev/null | \
        awk -F. '{ if (NF>1) print tolower($NF); else print "(none)" }' | \
        sort | uniq -c | sort -rn | head -20
    echo ""
    echo "Total files: $(find "$path" -type f 2>/dev/null | wc -l)"
    echo "Total size:  $(du -sh "$path" 2>/dev/null | awk '{print $1}')"
    echo '```'
    echo ""
done

# ---------------------------------------------------------------------------
echo "## 12. Recommendations checklist (for my own reference)"
echo ""
echo "- [ ] Did critical dirs survive in allocated? If yes: most of the fight is done."
echo "- [ ] Did tsk_recover pull anything useful for critical dirs? If yes: merge with allocated."
echo "- [ ] How much free space on \$EXT_MOUNT remaining? Photorec needs ~same size as source at worst."
echo "- [ ] Photorec --free mode or --whole mode based on completeness of passes 1+2."
echo "- [ ] Photorec file types to narrow if strongly biased toward one content type (audio)."
echo ""
echo "---"
echo ""
echo "_Report generated by generate_report.sh — commit to repo and share for analysis_"

# Also emit a note to the controlling terminal so user knows where it went
if [[ -t 2 ]] || [[ -t 1 ]]; then
    true
fi
printf '\nReport written to: %s\n' "$OUT" > /dev/tty 2>/dev/null || printf '\nReport written to: %s\n' "$OUT" >&2
printf 'To push to repo:\n  cd %s/..\n  git add logs/%s\n  git commit -m "Add recovery report %s"\n  git push\n' \
    "$(dirname "$OUT")" "$(basename "$OUT")" "$TIMESTAMP" > /dev/tty 2>/dev/null || true
