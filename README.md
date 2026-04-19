# Recovery Kit

Preloaded tools and documentation for ext4 `rm -rf` recovery from a
SystemRescue live USB. All commands in the docs have been cross-checked
against the official man pages for ext4magic, photorec/testdisk,
sleuthkit, and extundelete.

## Contents

```
recovery-kit/
├── README.md                      — this file
├── RECOVERY_PLAN.md               — step-by-step runbook, read first
├── CHEATSHEET.md                  — quick command reference
├── ERRATA.md                      — what was corrected from first draft
└── scripts/
    ├── preflight.sh               — run first on live USB; full system report
    ├── backup_journal.sh          — dump ext4 journal before anything else
    ├── photorec_run.sh            — scripted photorec with curated file types
    ├── rename_xrns.sh             — identifies Renoise .xrns (zip + Song.xml)
    ├── rename_zip_formats.sh      — identifies docx/xlsx/pptx/odt/epub/jar/apk
    ├── sort_by_type.sh            — sorts photorec output by MIME
    ├── filter_audio.sh            — keeps only audio above size/duration threshold
    ├── find_text.sh               — classifies text files into py/rust/ts/json/etc
    ├── identify_firefox.sh        — finds Firefox profile sqlite files
    └── search_recovered.sh        — ripgrep over recoveries for known strings
```

## Pre-boot: put this on your Ventoy USB

```
# Assuming Ventoy is mounted at /mnt/ventoy with your user's uid
cp -r recovery-kit /mnt/ventoy/
```

You should end up with `/mnt/ventoy/recovery-kit/` alongside your
SystemRescue ISO.

**Important:** Ventoy's exFAT partition doesn't preserve the executable
bit. Once you boot into the live environment, either invoke scripts
with `bash scriptname.sh`, or `chmod +x scripts/*.sh` first.

## Running order in the live environment

```
cd /run/media/root/Ventoy/recovery-kit

# 1. System inventory, device identification, tool availability check
bash scripts/preflight.sh

# 2. Back up the ext4 journal — most important step, do FIRST
bash scripts/backup_journal.sh /dev/nvme0n1p3 /mnt/ext/journal.copy

# 3. ext4magic with path-based recovery (uses the journal copy)
sudo ext4magic /dev/nvme0n1p3 \
    -j /mnt/ext/journal.copy \
    -a $(date -d 'JUST_BEFORE_RM_TIMESTAMP' +%s) \
    -f home/kyle -r -d /mnt/ext/ext4magic-out

# 4. extundelete as second opinion
sudo extundelete /dev/nvme0n1p3 \
    --restore-directory home/kyle \
    -o /mnt/ext/extundelete-out

# 5. sleuthkit brute-force enumeration
sudo tsk_recover -e /dev/nvme0n1p3 /mnt/ext/tsk-out

# 6. photorec as last resort (carves files without names)
bash scripts/photorec_run.sh /dev/nvme0n1p3 /mnt/ext/photorec-out

# 7. Post-process photorec output
bash scripts/rename_xrns.sh /mnt/ext/photorec-out
bash scripts/rename_zip_formats.sh /mnt/ext/photorec-out
bash scripts/sort_by_type.sh /mnt/ext/photorec-out /mnt/ext/sorted
# etc.
```

See RECOVERY_PLAN.md for the full runbook with safety checks.

## Recommended live distro: SystemRescue

Ships with all required tools: ddrescue, testdisk/photorec, ext4magic,
extundelete, sleuthkit, smartmontools, rsync, ripgrep, sqlite3,
ffmpeg/ffprobe, file, unzip, tmux, debugfs.

Root password on the live environment is `rootpass` by default.

## If using plain Arch install ISO

Plain Arch ISO doesn't ship most of these. You'd need:
```
sudo pacman -Sy ext4magic extundelete testdisk sleuthkit smartmontools \
                ripgrep sqlite ffmpeg unzip tmux e2fsprogs
```
Note: `extundelete` and `ext4magic` are in AUR, not core repos, on some
recent Arch builds. SystemRescue avoids that hassle.

## Philosophy

Layered recovery, organized-first then brute-force:

1. **Journal backup** (debugfs) — freeze the most fragile data source
2. **ext4magic** — best case: recovers filenames and paths from journal
3. **extundelete** — second opinion on the journal with different algorithm
4. **Sleuthkit `tsk_recover`** — filesystem-layer enumeration of deleted inodes
5. **PhotoRec** — signature-based carving, ignores filesystem entirely

Earlier steps preserve names and structure; later steps catch anything
missed but lose metadata. Post-processing scripts re-identify carved
files by content.
