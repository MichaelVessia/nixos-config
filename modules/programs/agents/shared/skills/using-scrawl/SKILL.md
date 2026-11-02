---
name: using-scrawl
description: Open a scrawl capture (screen recording with marks and voice notes) that Michael pasted into a chat, including when the capture lives on another machine. Use when a message starts with `[scrawl ...]` or names a `.scrawl` capture folder.
---

# Using scrawl captures

A scrawl paste looks like this:

```
[scrawl 0:20 · Brave Browser · /Users/michael.vessia/Library/Application Support/scrawl/captures/1793656416427.scrawl]
Open contact-sheet.png and frames/ in that folder before changing anything: ...
- #1 (0:12) "transcribed voice note"
```

The text is only the transcript. The marks (circles, arrows, numbers) are on
the images, and they often name the exact thing the voice note means. Look at
the images before you investigate or change anything.

## Find the capture

The bracket line ends with the capture folder path. That path is on the
machine that recorded it, which is often not the machine you run on.

| Path prefix                | Machine  | SSH alias |
| -------------------------- | -------- | --------- |
| `/Users/michael.vessia/`   | flomac   | `flomac`  |

1. If the folder exists locally, use it in place.
2. If not, copy it from the machine in the table over Tailscale SSH. Do not
   search the local disk for it, and do not substitute an older capture.

## Copy a remote capture

The path contains a space (`Application Support`), and `scp` mangles it. Use
`tar` over `ssh`. Copy into your scratchpad (or another temp directory that
belongs to this session):

```bash
CAP='/Users/michael.vessia/Library/Application Support/scrawl/captures/<id>.scrawl'
DEST="<scratchpad>/scrawl-<id>"
mkdir -p "$DEST"
ssh -o BatchMode=yes -o ConnectTimeout=10 flomac \
  "cd \"$CAP\" && tar cf - contact-sheet.png frames summary.md capture.json" \
  | tar xf - -C "$DEST"
```

Add `contact-sheet-full.png frames-full` when the paste says the frames are
cropped and you need the surrounding screen. Skip `recording.mp4` and
`audio.wav` unless the images and transcript are not enough. They are large.

## Read it

1. Read `contact-sheet.png`, then each image in `frames/`.
2. Match each numbered mark on a frame to the voice note with the same number.
3. Note the time zone of any chart axis in the frames. The browser shows the
   recording machine's local time, which can differ from yours and from the
   data source's.

## When access fails

- `Permission denied (publickey)`: this machine's key is not in the recording
  machine's `openssh.authorizedKeys.keys` in nixos-config
  (`hosts/<machine>/default.nix`). Report that blocker.
- Timeout or `Could not resolve hostname`: the recording machine is asleep or
  off Tailscale. Check `tailscale status`, then report it.

Do not continue from the transcript alone without saying that you could not
see the images.
