# Errata — fixes from doc cross-check

Issues found and corrected after cross-referencing the first-pass kit
against the official documentation for each tool.

## photorec.cfg format was wrong

The original kit shipped a `configs/photorec.cfg` with multi-line
entries like:
```
fileopt,wav,enable
fileopt,flac,enable
options,paranoid,
```

**This is not a valid photorec.cfg format.** photorec's scripted-run
syntax is a single comma-separated string passed via `/cmd`, not a
multi-line config file. The .photorec.cfg written by photorec's TUI
"Save" has its own format but uses the same flat comma-separated style.

Options like `paranoid`, `keep_corrupted_file_no`, `mode_ext2_no` are
not valid keywords in either form.

**Fix:** Replaced with `scripts/photorec_run.sh`, which invokes photorec
via `/cmd` using the documented scripted-run syntax:
```
photorec /log /d <outdir> /cmd <device> options,mode_ext2,fileopt,everything,disable,wav,enable,...,freespace,search
```

## extundelete command syntax was wrong

Original had:
```
sudo extundelete --restore-all \
    --restore-directory /home/kyle \
    -o /mnt/ext/extundelete-out \
    /dev/nvme0n1p3
```

Three issues:
1. `--restore-all` and `--restore-directory` are **alternative actions**,
   not combinable. Pick one per invocation.
2. Path must be **relative to the filesystem root with no leading slash**.
   So `home/kyle`, not `/home/kyle`.
3. `-o` flag itself is valid (my docs are correct on this), but
   double-checked against the Kali manpage for confirmation.

**Fix:** Each action is shown as its own separate example in the
corrected docs.

## ext4magic: journal backup was missing as a step

The ext4magic project's own documentation is emphatic:

> It's important to create this journal copy immediately before a new
> mount of the file system. Otherwise some journal data will be
> destroyed and lost.

The journal holds the inode snapshots that make filename-preserving
recovery possible. Every read, every find command, every background
process on the live filesystem nibbles at journal data.

**Fix:** Added `scripts/backup_journal.sh` as Step 3 (after boot and
external-drive setup). All subsequent ext4magic commands in the docs
now pass `-j /mnt/ext/journal.copy` to use the frozen snapshot.

## ext4magic path syntax not emphasized enough

ext4magic's `-f` flag takes a path **relative to the filesystem root,
with no leading slash**. If home was at `/home/kyle` on the ext4
partition, you pass `-f home/kyle`. This was correct in the original
kit but not called out as a common footgun.

**Fix:** Added explicit note near the top of RECOVERY_PLAN.md and
CHEATSHEET.md.

## ext4magic -r vs -R

Original kit used `-r` in all recovery examples. The docs describe `-R`
as a stronger form (attempts to restore hardlinks/symlinks) that may
recover additional content.

**Fix:** Documented both. Recommendation is `-r` first, then `-R` if
output is sparse.

## find_text.sh YAML detection had a bash syntax bug

Original had:
```
if echo "$head" | grep -qE '^---$' || \
   echo "$head" | grep -qcE '^[a-zA-Z_]...' | awk '{exit !($1 > 2)}'
```

`grep -qc` doesn't make sense (quiet vs. count are mutually exclusive),
and piping `grep -q`'s empty output to awk was broken.

**Fix:** Restructured as two separate checks: (a) document separator
`^---$`, or (b) at least 3 `key: value` lines at column 0.

## rename_xrns.sh XML parsing pointed at wrong element

Original used xmlstarlet query `//SongData/Name` for the song name,
but Renoise's XML uses `<RenoiseSong doc_version="NN">` as the root
element. The song name location varies by doc_version.

**Fix:** Rewrote to:
1. Check that Song.xml exists in the zip
2. Verify `<RenoiseSong` appears in the XML
3. Try several regex patterns for the name in order
4. Fall back to using the zip basename if no name found
5. Extract `doc_version` for disambiguation in filenames

Also added tolerance for partially-corrupted zips: `unzip -l` check
before attempting extraction, since photorec-carved zips often have
damaged central directories.

## rename_zip_formats.sh detection logic had a fragile pattern

The original used a regex that expected `mimetypeapplication/vnd.oasis.opendocument.text`
to match the first line of a zip listing. This only works if the `mimetype`
file (which is stored first and uncompressed in ODF formats) happens
to show up concatenated with its content in `unzip -l` output — which
it doesn't.

**Fix:** The second branch of the check (which does `unzip -p mimetype`
and inspects its content) is actually the correct path; the first
branch was redundant and misleading. The script still works because
the mimetype-inspection branch handles all ODF formats correctly, but
the code is now cleaner.

## smartctl usage clarification

NVMe devices in smartctl can be addressed as `/dev/nvme0` (controller,
broadcast to all namespaces) or `/dev/nvme0n1` (specific namespace).
For health checks, both work. The kit uses `/dev/nvme0n1` consistently.

## Things deliberately not changed

Some things the cross-check confirmed were already correct:
- `fls -r -d` for listing deleted entries
- `tsk_recover -e` for all-files extraction
- `icat` for inode-targeted extraction
- extundelete's `-o directory` flag (valid per Kali manpage)
- Path conventions for extundelete and ext4magic (both relative, no leading slash)
- Recommendation to write to a different physical device than the source
