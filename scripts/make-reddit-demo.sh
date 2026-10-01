#!/bin/bash
# Reproduce the owner's approved-source demo edit; does not upload or publish.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source=${1:?Path to the October 1 2026 20.57.13 recording is required}
mkdir -p docs/media
# Preserve original speed. Remove the false start, trim static waiting, and
# crop the screen-sharing footer. This is v0.2.2 footage, not live-search proof.
ffmpeg -hide_banner -loglevel error -i "$source" \
  -filter_complex '[0:v]split=2[a][b];[a]trim=start=25.5:end=34.5,setpts=PTS-STARTPTS[v0];[b]trim=start=39:end=50.5,setpts=PTS-STARTPTS[v1];[v0][v1]concat=n=2:v=1:a=0,crop=1038:1310:0:0,fps=15,format=yuv420p[out]' \
  -map '[out]' -an -map_metadata -1 -c:v libx264 -preset slow -crf 20 \
  -movflags +faststart -y docs/media/wikipedia-reddit-demo.mp4
