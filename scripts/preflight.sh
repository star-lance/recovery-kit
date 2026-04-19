#!/usr/bin/env bash
# preflight.sh — run this first on the live USB before any recovery
#
# Outputs a complete snapshot of the system state so you can:
# 1. Identify the correct NVMe partition
# 2. Identify the correct external drive
# 3. Confirm nothing is auto-mounted read-write
# 4. Save a log of baseline state before recovery starts
#
# Usage: ./preflight.sh [output_file]

set -u

OUT="${1:-/tmp/preflight.log}"

{
    echo "============================================================"
    echo "PREFLIGHT REPORT — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "============================================================"
    echo ""
    echo "--- kernel & environment ---"
    uname -a
    echo ""
    cat /etc/os-release 2>/dev/null || echo "no /etc/os-release"
    echo ""

    echo "--- block devices (lsblk -f) ---"
    lsblk -f
    echo ""

    echo "--- block devices with sizes & models (lsblk -o) ---"
    lsblk -o NAME,SIZE,TYPE,MODEL,SERIAL,FSTYPE,LABEL,UUID,MOUNTPOINTS
    echo ""

    echo "--- current mounts ---"
    mount | grep -E '^/dev'
    echo ""

    echo "--- mount options (read-only check) ---"
    findmnt -A -o TARGET,SOURCE,FSTYPE,OPTIONS
    echo ""

    echo "--- nvme drives detail ---"
    for nvme in /dev/nvme*n1; do
        [[ -b "$nvme" ]] || continue
        echo "### $nvme ###"
        sudo smartctl -i "$nvme" 2>/dev/null | head -30
        echo ""
        echo "SMART health:"
        sudo smartctl -H "$nvme" 2>/dev/null | grep -i 'health\|status\|passed\|failed'
        echo ""
    done

    echo "--- partition tables ---"
    for dev in /dev/nvme0n1 /dev/sda /dev/sdb /dev/sdc; do
        [[ -b "$dev" ]] || continue
        echo "### $dev ###"
        sudo parted -s "$dev" print 2>/dev/null || echo "(parted failed)"
        echo ""
    done

    echo "--- swap status ---"
    swapon --show 2>/dev/null
    cat /proc/swaps
    echo ""

    echo "--- memory ---"
    free -h
    echo ""

    echo "--- available disk space ---"
    df -h
    echo ""

    echo "--- tool availability check ---"
    for tool in ddrescue ext4magic extundelete photorec testdisk fls tsk_recover icat debugfs smartctl ripgrep sqlite3 ffprobe xmlstarlet unzip file; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf '  [OK]    %-20s %s\n' "$tool" "$(command -v $tool)"
        else
            printf '  [MISS]  %-20s\n' "$tool"
        fi
    done
    echo ""

    echo "--- open deleted files (proc fd) ---"
    echo "(any 'deleted' entries could be recovered via /proc/PID/fd/FD copy)"
    sudo ls -la /proc/*/fd 2>/dev/null | grep -i deleted || echo "(none found)"
    echo ""

    echo "============================================================"
    echo "END OF REPORT"
    echo "============================================================"
} | tee "$OUT"

echo ""
echo "Report saved to: $OUT"
echo ""
echo "NEXT STEPS:"
echo "  1. Review the lsblk output above. Identify:"
echo "     - NVMe root partition (was /dev/nvme0n1p3 on your laptop — confirm)"
echo "     - External recovery drive (should be /dev/sd?1)"
echo "  2. Check that NVMe is NOT auto-mounted rw (findmnt output)"
echo "  3. Confirm tools you need are present (look for [MISS] entries)"
echo "  4. If any tools are missing, install with: sudo pacman -Sy <tool>"
echo "     (SystemRescue includes most; Arch live may need installs)"
