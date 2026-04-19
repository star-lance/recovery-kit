# Recovery Cheat Sheet

## Golden rules
1. `lsblk -f` BEFORE every block device operation
2. Read command once, then run
3. Output ALWAYS goes to external drive, NEVER back to NVMe
4. Everything inside tmux: `tmux new -s rec` / `tmux attach -t rec`
5. Paths passed to ext4magic `-f` and extundelete `--restore-directory`
   are **relative to filesystem root, no leading slash**

---

## Identify devices
```
lsblk -f                                    # overview
sudo fdisk -l /dev/nvme0n1                  # partition details
sudo smartctl -a /dev/nvme0n1               # NVMe drive health
sudo smartctl -H /dev/nvme0n1               # quick health pass/fail only
```

## Mount external drive (writable)
```
sudo mkdir -p /mnt/ext
sudo mount /dev/sdX1 /mnt/ext
df -h /mnt/ext
```

## Get unix timestamp for a moment in time
```
date -d '2026-04-19 14:20:00' +%s
date +%s                                    # right now
date -d '-6 hours' +%s                      # 6 hours ago
date -d@1745078400                          # reverse: epoch -> readable
```

## Back up journal (do this FIRST)
```
sudo debugfs -R "dump <8> /mnt/ext/journal.copy" /dev/nvme0n1p3
# Then pass -j /mnt/ext/journal.copy to all ext4magic commands
```

## ext4magic — list recoverable files
```
sudo ext4magic /dev/nvme0n1p3 \
    -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -L
```

## ext4magic — recover by path (most useful form)
```
sudo ext4magic /dev/nvme0n1p3 \
    -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -f home/kyle -r \
    -d /mnt/ext/ext4magic-out
```
`-f home/kyle` has NO leading slash. `-r` is recursive recover;
`-R` is a stronger variant to try if `-r` output is sparse.

## ext4magic — magic mode for fully-deleted filesystems
```
sudo ext4magic /dev/nvme0n1p3 -M \
    -j /mnt/ext/journal.copy \
    -a $(date -d '2026-04-19 14:20:00' +%s) \
    -d /mnt/ext/ext4magic-magic
```
`-M` = restore all; `-m` = restore only deleted.

## extundelete — recover specific directory
```
sudo extundelete /dev/nvme0n1p3 \
    --restore-directory home/kyle \
    -o /mnt/ext/extundelete-out
```
Again, NO leading slash on `home/kyle`.

## extundelete — recover everything deleted
```
sudo extundelete /dev/nvme0n1p3 \
    --restore-all \
    -o /mnt/ext/extundelete-out
```
`--restore-all` and `--restore-directory` are alternatives, pick one.

## extundelete — time-bounded recovery
```
sudo extundelete /dev/nvme0n1p3 \
    --after $(date -d '2026-04-19 14:20:00' +%s) \
    --restore-directory home/kyle \
    -o /mnt/ext/extundelete-out
```

## Sleuthkit — list deleted entries
```
sudo fls -r -d /dev/nvme0n1p3 > /mnt/ext/deleted-list.txt
```
`-r` recursive, `-d` show deleted only. Output prefixed with `*`
indicates deletion, with inode number shown.

## Sleuthkit — extract everything
```
sudo tsk_recover -e /dev/nvme0n1p3 /mnt/ext/tsk-out
```
Default behavior is unallocated-only; `-e` = everything (allocated + deleted).

## Sleuthkit — extract specific inode
```
sudo icat /dev/nvme0n1p3 <inode_number> > /mnt/ext/recovered-file
```

## PhotoRec — scripted run
```
bash scripts/photorec_run.sh /dev/nvme0n1p3 /mnt/ext/photorec-out
```

## PhotoRec — TUI
```
sudo photorec /dev/nvme0n1p3
# Select partition -> ext2/ext3 filesystem -> Free (unallocated)
#   -> output dir on /mnt/ext/
```

## debugfs — interactive ext4 forensics
```
sudo debugfs /dev/nvme0n1p3
# Inside:
#   lsdel                         # list deleted inodes
#   logdump                       # dump the journal
#   stat <12345>                  # info on inode 12345
#   dump <12345> /mnt/ext/out     # dump inode data
#   cd / ; ls                     # browse filesystem
```

## Mount NVMe read-only (checking still-present files)
```
sudo mkdir -p /mnt/nvme-ro
sudo mount -o ro /dev/nvme0n1p3 /mnt/nvme-ro
ls -la /mnt/nvme-ro/home/
sudo rsync -aHAXv /mnt/nvme-ro/home/ /mnt/ext/still-present/
sudo umount /mnt/nvme-ro
```

---

## Post-processing scripts
```
USB=/path/to/usb/recovery-kit

bash $USB/scripts/backup_journal.sh /dev/nvme0n1p3 /mnt/ext/journal.copy
bash $USB/scripts/photorec_run.sh /dev/nvme0n1p3 /mnt/ext/photorec-out
bash $USB/scripts/rename_xrns.sh /mnt/ext/photorec-out
bash $USB/scripts/rename_zip_formats.sh /mnt/ext/photorec-out
bash $USB/scripts/sort_by_type.sh /mnt/ext/photorec-out /mnt/ext/sorted
bash $USB/scripts/filter_audio.sh /mnt/ext/photorec-out /mnt/ext/audio-keep
bash $USB/scripts/find_text.sh /mnt/ext/photorec-out
bash $USB/scripts/identify_firefox.sh /mnt/ext/photorec-out
bash $USB/scripts/search_recovered.sh /mnt/ext/photorec-out 'NoteWarden'
```

---

## Tmux cheatsheet
```
tmux new -s rec              # new session
tmux attach -t rec           # reattach
Ctrl-b d                     # detach without killing
Ctrl-b c                     # new window
Ctrl-b n / p                 # next/prev window
Ctrl-b [                     # scroll mode (q to exit)
tmux ls                      # list sessions
```

## Watch progress in another pane
```
watch -n 10 'du -sh /mnt/ext/photorec-out 2>/dev/null; \
  find /mnt/ext/photorec-out -type f 2>/dev/null | wc -l'
```
