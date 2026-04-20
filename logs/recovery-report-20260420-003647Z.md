# Recovery Status Report

Generated: 2026-04-20 00:36:47 UTC
Host: sysrescue — Linux sysrescue 6.18.20-1-lts #1 SMP PREEMPT_DYNAMIC Wed, 25 Mar 2026 12:17:34 +0000 x86_64 GNU/Linux

## 1. Environment

```
NAME="SystemRescue"
PRETTY_NAME="SystemRescue 13.00"
VERSION="13.00"

Memory:
               total        used        free      shared  buff/cache   available
Mem:            30Gi       1.3Gi        13Gi        70Mi        16Gi        29Gi
Swap:             0B          0B          0B
```

## 2. Tool availability

```
OK   photorec        /usr/bin/photorec
OK   testdisk        /usr/bin/testdisk
OK   fls             /usr/bin/fls
OK   tsk_recover     /usr/bin/tsk_recover
OK   icat            /usr/bin/icat
OK   ifind           /usr/bin/ifind
OK   istat           /usr/bin/istat
OK   debugfs         /usr/bin/debugfs
OK   jls             /usr/bin/jls
OK   jcat            /usr/bin/jcat
OK   ddrescue        /usr/bin/ddrescue
OK   smartctl        /usr/bin/smartctl
OK   sqlite3         /usr/bin/sqlite3
MISS ffprobe        
OK   unzip           /usr/bin/unzip
OK   file            /usr/bin/file
OK   rsync           /usr/bin/rsync
MISS ripgrep        
OK   tmux            /usr/bin/tmux
MISS ext4magic      
MISS extundelete    
```

## 3. Block devices

```
NAME          SIZE TYPE FSTYPE   LABEL      UUID                                 MOUNTPOINTS
loop0           1G loop squashfs                                                 /run/archiso/sfs/airootfs
sda           1.9T disk                                                          
└─sda1        1.9T part ext4     recovery   122320d4-c696-4baa-be58-112aa976de9b /mnt/ext
sdb           1.8T disk                                                          
└─sdb1        1.8T part ext4                19c17da7-538c-482d-8c62-e3845593fb20 
sdc          14.3G disk                                                          
├─sdc1       14.3G part exfat    Ventoy     E050-D1CD                            
│ ├─ventoy    1.2G dm   iso9660  RESCUE1300 2026-03-28-09-44-20-00               /run/archiso/bootmnt
│ └─sdc1     14.3G dm   exfat    Ventoy     E050-D1CD                            /mnt/usb
└─sdc2         32M part vfat     VTOYEFI    F46C-2C32                            
nvme0n1     931.5G disk                                                          
├─nvme0n1p1     1G part vfat                F6C7-35EC                            
├─nvme0n1p2     8G part swap                2d92ebd2-2abb-43ce-ba62-33761893039b 
└─nvme0n1p3 922.5G part ext4                aa1bc1c6-de25-4053-9eb2-72cb4ec49537 
```

```
findmnt for /dev/nvme0n1p3:
(not mounted)

findmnt for /mnt/ext:
TARGET   SOURCE    FSTYPE OPTIONS
/mnt/ext /dev/sda1 ext4   rw,relatime
```

## 4. NVMe health (SMART)

```
SMART overall-health self-assessment test result: PASSED

Available Spare:                    100%
Available Spare Threshold:          10%
Percentage Used:                    4%
Data Units Written:                 68,212,741 [34.9 TB]
Unsafe Shutdowns:                   314
```

## 5. Filesystem stats

```
FILE SYSTEM INFORMATION
--------------------------------------------
File System Type: Ext4
Volume Name: 
Volume ID: 3795c44ecb72b29e534025dec6c11baa

Last Written at: 2026-04-19 15:23:08 (UTC)
Last Checked at: 2025-05-12 23:07:46 (UTC)

Last Mounted at: 2026-04-19 15:23:08 (UTC)
Unmounted properly
Last mounted on: /sysroot

Source OS: Linux
Dynamic Structure
Compat Features: Journal, Ext Attributes, Resize Inode, Dir Index
InCompat Features: Filetype, Extents, 64bit, Flexible Block Groups, 
Read Only Compat Features: Sparse Super, Large File, Huge File, Extra Inode Size

Journal ID: 00
Journal Inode: 8

METADATA INFORMATION
--------------------------------------------
Inode Range: 1 - 60465153
Root Directory: 2
Free Inodes: 59694972
Inode Size: 256

CONTENT INFORMATION
--------------------------------------------
Block Groups Per Flex Group: 16
Block Range: 0 - 241830911
Block Size: 4096
Free Blocks: 213306554

BLOCK GROUP INFORMATION
--------------------------------------------
Number of Block Groups: 7381
Inodes per group: 8192
Blocks per group: 32768

Group: 0:
  Block Group Flags: [INODE_ZEROED, ]
  Inode Range: 1 - 8192
  Block Range: 0 - 32767
  Layout:
    Super Block: 0 - 0
    Group Descriptor Table: 1 - 116
    Group Descriptor Growth Blocks: 117 - 1140
```

## 6. Rescue progress — sizes and disk usage

```
External drive (/mnt/ext):
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       1.9T   15G  1.8T   1% /mnt/ext

Rescue directories:
/mnt/ext/rescued-allocated                     4.1G       73062 files
/mnt/ext/rescued-deleted                       9.2G         284 files
/mnt/ext/photorec-out                          4.0K           0 files

Journal backup:
-rw-r--r-- 1 root root 1.0G Apr 19 23:32 /mnt/ext/journal.copy
```

## 7. Critical directory survival check

For each user-important path, checks what's present in each rescue dir.

### `/home/star/audio`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/STARDUST`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/Documents`

```
rescued-allocated: 3 files, 26M
  top entries:
    /mnt/ext/rescued-allocated/Documents
    /mnt/ext/rescued-allocated/Documents/dred bass.wav
    /mnt/ext/rescued-allocated/Documents/serum_manual.md
    /mnt/ext/rescued-allocated/Documents/serum_manual.pdf

rescued-deleted:   MISSING
```

### `/home/star/Music`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/.config`

```
rescued-allocated: 660 files, 175M
  top entries:
    /mnt/ext/rescued-allocated/.config
    /mnt/ext/rescued-allocated/.config/QDirStat
    /mnt/ext/rescued-allocated/.config/QDirStat/QDirStat.conf
    /mnt/ext/rescued-allocated/.config/QDirStat/QDirStat-mime.conf
    /mnt/ext/rescued-allocated/.config/QDirStat/QDirStat-cleanup.conf
    /mnt/ext/rescued-allocated/.config/QDirStat/QDirStat-exclude.conf
    /mnt/ext/rescued-allocated/.config/pulse
    /mnt/ext/rescued-allocated/.config/pulse/cookie
    /mnt/ext/rescued-allocated/.config/google-chrome
    /mnt/ext/rescued-allocated/.config/google-chrome/TrustTokenKeyCommitments
    /mnt/ext/rescued-allocated/.config/google-chrome/OnDeviceHeadSuggestModel
    /mnt/ext/rescued-allocated/.config/google-chrome/PKIMetadata
    /mnt/ext/rescued-allocated/.config/google-chrome/CertificateRevocation
    /mnt/ext/rescued-allocated/.config/google-chrome/ShaderCache
    /mnt/ext/rescued-allocated/.config/google-chrome/GraphiteDawnCache

rescued-deleted:   MISSING
```

### `/home/star/.ssh`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/Renoise`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/.local/share/Renoise`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/projects`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/code`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

### `/home/star/dev`

```
rescued-allocated: MISSING

rescued-deleted:   MISSING
```

## 8. fls deleted-entry analysis

```
File: /mnt/ext/logs/fls-deleted.txt
1297 /mnt/ext/logs/fls-deleted.txt

total entries:       1297
entries reallocated: 395

By critical directory:
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/audio                                      0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/STARDUST                                   0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/Documents                                  0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/Music                                      0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/.config                                    0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/.ssh                                       0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/Renoise                                    0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/.local/share/Renoise                       0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/projects                                   0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/code                                       0
scripts/generate_report.sh: line 233: printf: 0
0: invalid number
  home/star/dev                                        0

By file type keyword:
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  xrns                             0
  renoise                          1
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.wav                            0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.flac                           0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.mp3                            0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.ogg                            0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.fxp                            0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.vital                          0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.xrni                           0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.xrnt                           0
scripts/generate_report.sh: line 239: printf: 0
0: invalid number
  \.mid                            0
```

### Sample deleted entries mentioning critical keywords

```
```

### Sample audio/project files in deleted entries

```
```

## 9. fls all-entries analysis (allocated + deleted)

```
File: /mnt/ext/logs/fls-all.txt
837447 /mnt/ext/logs/fls-all.txt

Entries still present for critical dirs (non-deleted):
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/audio                                      0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/STARDUST                                   0
  home/star/Documents                                  4
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/Music                                      0
  home/star/.config                                 1037
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/.ssh                                       0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/Renoise                                    0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/.local/share/Renoise                       0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/projects                                   0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/code                                       0
scripts/generate_report.sh: line 278: printf: 0
0: invalid number
  home/star/dev                                        0
```

## 10. tsk_recover log summary

```
Last 30 lines of /mnt/ext/logs/tsk-recover.log:
Files Recovered: 285
```

## 11. File type breakdown in rescued directories

### allocated (/mnt/ext/rescued-allocated)

```
Top 20 file extensions by count:
  41407 go
   2766 txt
   1859 json
   1800 yml
   1498 golden
   1357 toml
   1357 md
   1130 txtar
    717 s
    562 xml
    341 mod
    321 expected
    321 actual
    299 test
    298 so
    275 sum
    269 gitignore
    256 jar
    223 yaml
    222 gox

Total files: 73062
Total size:  4.1G
```

### deleted (/mnt/ext/rescued-deleted)

```
Top 20 file extensions by count:
awk: cmd. line:1: (FILENAME=- FNR=74) warning: Invalid multibyte data detected. There may be a mismatch between your data and your locale
     58 rst
     58 gz
     37 so
     35 sig
     34 zst
     22 go
     15 (none)
     12 pyi
      5 ttf
      2 gir
      1 sdk/analyzers/build/config/�^8
      1 platform/x86_64/48/96298e7709cbcd531a61ea647b7a5a91db15582daa2423e8ed4ebec48778735d/files/share/bash-completion/completions/�^^
      1 local/share/trash/files/android/sdk/platforms/android-35/data/res/^
      1 fabric/processedmods/^^h
      1 cache/google-chrome/default/cache/cache_data/328b7e93071aa75f_0
      1 3

Total files: 284
Total size:  9.2G
```

## 12. Recommendations checklist (for my own reference)

- [ ] Did critical dirs survive in allocated? If yes: most of the fight is done.
- [ ] Did tsk_recover pull anything useful for critical dirs? If yes: merge with allocated.
- [ ] How much free space on $EXT_MOUNT remaining? Photorec needs ~same size as source at worst.
- [ ] Photorec --free mode or --whole mode based on completeness of passes 1+2.
- [ ] Photorec file types to narrow if strongly biased toward one content type (audio).

---

_Report generated by generate_report.sh — commit to repo and share for analysis_
