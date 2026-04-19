# Recovery Plan — ext4 rm -rf home directory

## Context
- Filesystem: ext4 on NVMe (`/dev/nvme0n1p3` per lsblk)
- `/boot` is FAT32 on `/dev/nvme0n1p1`, swap on `/dev/nvme0n1p2`
- Working directly on NVMe (no full image)
- External recovery drive: `/dev/sdY` (confirm with `lsblk -f` after boot)

## CRITICAL RULES
1. **Never mount the NVMe root partition read-write.** Read-only only, if at all.
2. **Confirm device paths with `lsblk -f` every single time** before running a command that touches a block device.
3. **Type the device path by hand, read it back, then run.** No shell history arrow-up for block device commands.
4. **External drive must be mounted read-write** — that's where output goes.
5. Run everything inside `tmux` so a disconnected session doesn't kill a 12-hour recovery job.

## Path syntax note
ext4magic's `-f` and extundelete's `--restore-directory` both take paths **relative to the filesystem root**, with **no leading slash**. If your home dir was `/home/kyle` on the ext4 partition, you pass `home/kyle` to these tools. This trips a lot of people up.

---

## Step 0 — Boot and identify devices
```
lsblk -f
sudo smartctl -a /dev/nvme0n1 | tee /tmp/smart.txt    # for namespace; use /dev/nvme0 for controller
```

Record these (write them down on paper):
- NVMe root partition: ______________ (probably /dev/nvme0n1p3)
- External drive partition: ______________
- rm timestamp (approximate): ______________

## Step 1 — Mount external drive
```
sudo mkdir -p /mnt/ext
sudo mount /dev/sdY1 /mnt/ext
sudo mkdir -p /mnt/ext/{ext4magic-out,extundelete-out,tsk-out,photorec-out,logs,notes}
df -h /mnt/ext    # confirm space
```

## Step 2 — Start tmux
```
tmux new -s recovery
# Ctrl-b d to detach, `tmux attach -t recovery` to reattach
```

## Step 3 — Back up the journal FIRST (critical)
Before any other recovery attempt, copy the ext4 journal off the drive.
The journal holds the inode snapshots that ext4magic uses to recover
filenames and paths. Every mount, every read of a mounted fs, and
every background process erodes journal data. This step freezes what
you have.

```
bash /path/to/usb/scripts/backup_journal.sh /dev/nvme0n1p3 /mnt/ext/journal.copy
```

Or manually:
```
sudo debugfs -R "dump <8> /mnt/ext/journal.copy" /dev/nvme0n1p3
```

All subsequent ext4magic commands should use `-j /mnt/ext/journal.copy`
to read from this frozen copy instead of the live journal.

## Step 4 — Look for still-present files
rm -rf can be interrupted, can fail on permission errors, and can miss
open files. Mount read-only and check before anything destructive.
```
sudo mkdir -p /mnt/nvme-ro
sudo mount -o ro /dev/nvme0n1p3 /mnt/nvme-ro
ls -la /mnt/nvme-ro/home/
# If anything is still there, rsync it out first:
sudo rsync -aHAXv /mnt/nvme-ro/home/ /mnt/ext/still-present/
sudo umount /mnt/nvme-ro
```

## Step 5 — ext4magic: list what the journal knows
Pick a timestamp just before the rm happened. Example: if rm was at
14:30, use 14:20. Both `-a` (after) and `-b` (before) are valid in
listings; they define the time window to search.
```
# Get unix timestamp for your "before rm" moment:
date -d '2026-04-19 14:20:00' +%s

# List recoverable files in a window (-L = list mode):
sudo ext4magic /dev/nvme0n1p3 \
    -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -L 2>&1 | tee /mnt/ext/logs/ext4magic-listing.txt
```

If the rm was fast (completed in under 5 minutes) and you shut down
right after, ext4magic may find correct time parameters automatically
and the `-a` isn't required. But including it costs nothing.

## Step 6 — ext4magic: recover by path
Recover the whole home dir. Note `home/kyle` (no leading slash):
```
sudo ext4magic /dev/nvme0n1p3 \
    -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -f home/kyle \
    -r \
    -d /mnt/ext/ext4magic-out 2>&1 | tee /mnt/ext/logs/ext4magic-run.log
```

Flags in this command:
- `-j` external journal copy
- `-a` after-time (start of search window)
- `-f home/kyle` path relative to filesystem root
- `-r` recursive recovery (there's also `-R` which is a stronger form
  attempting to restore hardlinks/symlinks; try `-r` first, then `-R`
  if output is sparse)
- `-d` destination directory (must be on a DIFFERENT filesystem)

You can also target specific subdirectories first if you want to
triage the most important content quickly:
```
sudo ext4magic /dev/nvme0n1p3 -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -f home/kyle/music -r \
    -d /mnt/ext/ext4magic-music
```

## Step 7 — extundelete: second attempt with different algorithm
extundelete uses a different journal-reading approach than ext4magic.
Sometimes it finds what ext4magic missed, sometimes vice-versa.

Key syntax: `--restore-all` and `--restore-directory` are **alternative
actions** — pick one per run. Path is relative to filesystem root.
```
# Recover a specific directory tree:
sudo extundelete /dev/nvme0n1p3 \
    --restore-directory home/kyle \
    -o /mnt/ext/extundelete-out

# OR recover everything deleted:
sudo extundelete /dev/nvme0n1p3 \
    --restore-all \
    -o /mnt/ext/extundelete-out
```

Time window filters are `--after` and `--before` (both accept unix epoch):
```
sudo extundelete /dev/nvme0n1p3 \
    --after $(date -d '2026-04-19 14:20:00' +%s) \
    --restore-directory home/kyle \
    -o /mnt/ext/extundelete-out
```

If you omit `-o`, extundelete writes to `./RECOVERED_FILES` in the
current working directory.

## Step 8 — Sleuthkit: deleted inode enumeration
List every deleted entry the filesystem layer still remembers:
```
sudo fls -r -d /dev/nvme0n1p3 > /mnt/ext/logs/fls-deleted.txt
```

Bulk extract unallocated files (default is unallocated-only; `-e`
grabs everything):
```
sudo tsk_recover -e /dev/nvme0n1p3 /mnt/ext/tsk-out
```

## Step 9 — PhotoRec: file carving
Use the scripted wrapper (avoids the ~480-item TUI menu):
```
bash /path/to/usb/scripts/photorec_run.sh \
    /dev/nvme0n1p3 \
    /mnt/ext/photorec-out
```

Or run the TUI interactively:
```
sudo photorec /dev/nvme0n1p3
# In the UI:
#   Partition table: Intel (or whatever lsblk shows)
#   Select the ext4 partition
#   File Opt: enable only the types you care about
#   Filesystem: ext2/ext3 (yes, for ext4 too — this is what photorec calls it)
#   "Free" = scan unallocated only (faster, still catches deleted)
#   "Whole" = scan all blocks
#   Output: /mnt/ext/photorec-out (MUST be on different disk)
```

Photorec will run for 6–24 hours on a large NVMe. Let it. Detach
from tmux with Ctrl-b d and reattach later.

## Step 10 — Post-process photorec output
```
USB=/path/to/usb

# Identify Renoise .xrns hiding as .zip
bash $USB/scripts/rename_xrns.sh /mnt/ext/photorec-out

# Identify docx/xlsx/pptx/odt/epub/jar/apk
bash $USB/scripts/rename_zip_formats.sh /mnt/ext/photorec-out

# Sort all files by MIME type
bash $USB/scripts/sort_by_type.sh /mnt/ext/photorec-out /mnt/ext/sorted

# Filter audio to non-fragment sizes
bash $USB/scripts/filter_audio.sh /mnt/ext/photorec-out /mnt/ext/audio-keep

# Classify recovered text by language/format
bash $USB/scripts/find_text.sh /mnt/ext/photorec-out

# Identify Firefox profile sqlite files
bash $USB/scripts/identify_firefox.sh /mnt/ext/photorec-out

# Search recoveries by keyword
bash $USB/scripts/search_recovered.sh /mnt/ext/photorec-out 'NoteWarden'
```

## Step 11 — Cross-check against known remotes
Don't waste recovery effort on things that are already safe:
- Chezmoi-managed dotfiles → reinstall via `chezmoi init <repo>`
- Anything pushed to github → reclone
- VST plugins → reinstall
- Sample libraries from vendors (Splice etc.) → redownload
- Games / steam — redownload

Focus recovery effort on:
- Renoise projects (.xrns) — run rename_xrns.sh
- Original recordings / samples (.wav, .flac) — run filter_audio.sh
- Serum presets (.fxp), Vital presets (.vital)
- Unfinished/unpushed code — rely on ext4magic; photorec carves code
  as noisy .txt
- Firefox profile (places.sqlite for history/bookmarks) — run
  identify_firefox.sh
- Documents, photos
- SSH keys — regenerate instead, don't reuse recovered ones

## Emergency safety checks before any command
```
lsblk -f                 # confirm NVMe still at expected path
findmnt /dev/nvme0n1p3   # confirm not mounted rw
df -h /mnt/ext           # confirm external has space
```

Type the command, DO NOT run, read it once more, then run.

## After recovery
- Verify recovered data on another drive before doing anything
  destructive to the NVMe
- Fresh Arch install on the NVMe (or a new drive)
- chezmoi init → reclone repos → reinstall VSTs → copy recovered
  user data into place
