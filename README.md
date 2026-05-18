# YTClipper

<p align="center">
  <img src="Resources/YTClipperIcon.png" alt="YTClipper app icon" width="128">
</p>

YTClipper is a simple Mac app for saving full YT videos or precise clip ranges from content you own or have permission to archive.

It is built for quick personal workflows: paste a link, choose full video or clip, pick a resolution, and save the result to your Mac.

## What You Can Do

- Save a full YT video
- Save only a selected clip range
- Download multiple YT videos sequentially from a pasted or imported URL list
- Choose the maximum resolution, from 360p up to 4K
- Watch download progress in the app
- Stop an active download
- Choose where files are saved
- Switch between light and dark mode from `YTClipper > Settings...`
- Run agent-friendly batch downloads from the command line with JSON input and NDJSON output

## Getting Started

Download the latest DMG from Releases, open it, then drag `YTClipper.app` into `Applications`.

The DMG includes first-launch help for unsigned builds. If macOS blocks the first open, use the included security-settings shortcut and help file in the mounted installer window.

Open YTClipper, paste one or more YT video links, then choose either:

- `Full Video` to save the whole video
- `Clip` to save only part of the video

For bulk downloads, paste one URL per line or click `Import` to load a plain-text list. YTClipper applies the same mode, resolution, clip range, and destination folder to every URL in the list. Downloads run sequentially; if one item fails, the app continues with the remaining URLs and shows a final summary.

If YTClipper needs extra helper tools, it will show an `Install` button. Click it and follow the Terminal window. When it finishes, return to YTClipper and click `Recheck Helpers`.

## Saving a Clip

Switch the mode to `Clip`, then enter a start time.

You can choose either:

- `Duration`: save from the start time for a set length
- `End Time`: save from the start time until a specific end time

Examples:

- Start: `01:15`
- Duration: `00:30`
- End Time: `01:45`

Time can be entered as `SS`, `MM:SS`, or `HH:MM:SS`.

## Important Note

Use YTClipper only with YT content you own or have permission to archive. The app does not bypass DRM, paywalls, private access controls, or platform restrictions.

## Agent CLI

The package also builds `ytclipper-cli` for non-interactive automation.

```bash
swift run ytclipper-cli run --manifest manifest.json
```

Use `-` to read the manifest from stdin:

```bash
cat manifest.json | swift run ytclipper-cli run --manifest -
```

Example manifest:

```json
{
  "version": 1,
  "outputDirectory": "/Users/charlie/Downloads",
  "mode": "full",
  "resolution": "best",
  "continueOnFailure": true,
  "jobs": [
    { "url": "https://www.youtube.com/watch?v=VIDEO_ID_1" },
    { "url": "https://youtu.be/VIDEO_ID_2" }
  ]
}
```

Clip manifest:

```json
{
  "version": 1,
  "outputDirectory": "/Users/charlie/Downloads",
  "mode": "clip",
  "resolution": "p1080",
  "clip": {
    "start": "00:01:15",
    "duration": "00:00:30"
  },
  "continueOnFailure": true,
  "jobs": [
    { "url": "https://www.youtube.com/watch?v=VIDEO_ID_1" }
  ]
}
```

The CLI writes newline-delimited JSON events to stdout. It exits with `0` when every job succeeds, `1` when the batch completes with failed jobs, `2` for invalid CLI usage or invalid manifests, `3` for missing helper tools, and `130` when cancelled.
