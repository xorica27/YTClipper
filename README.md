# YTClipper

A small macOS SwiftUI utility for downloading a full YouTube video, or clipping a time range from a YouTube video you own or have permission to archive.

The app shells out to:

- `yt-dlp` for retrieving the public video stream
- `ffmpeg` for merging streams and accurate clip cuts

It does not bypass DRM, paywalls, or private access controls.

## Features

- Download the full video or a selected clip duration
- Select a max video resolution, from 360p through 4K
- Track active download progress with a progress bar
- Stop an active download from inside the app
- Toggle between light and dark mode
- Choose the output folder

## Install Helpers

```sh
brew install yt-dlp ffmpeg
```

`ffmpeg` is already present on this Mac at `/opt/homebrew/bin/ffmpeg`; `yt-dlp` still needs to be installed.

## Run

```sh
cd "/Users/charlie/Documents/YTClipper"
swift run YTClipper
```

## Package as a macOS App

```sh
cd "/Users/charlie/Documents/YTClipper"
./Scripts/package-app.sh
open .build/release/YTClipper.app
```

## Time Format

Use `SS`, `MM:SS`, or `HH:MM:SS`.

Examples:

- Start: `01:15`
- Duration: `00:30`
- Full video: enable `Download full video`
