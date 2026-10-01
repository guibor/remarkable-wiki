#!/bin/bash
# Reproduce the owner's approved-source demo edit; does not upload or publish.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source=${1:?Path to the October 2 2026 00.28.06 recording is required}
mkdir -p docs/media
# v0.3.2 real-device footage: live search -> download -> Open PDF -> annotate.
# Typing and text selection run at 1.25x; static waits are cut. Preserve the
# full keyboard; only later shots crop/pad the unrelated screen-share footer.
ffmpeg -hide_banner -loglevel error -i "$source" \
  -filter_complex '[0:v]split=5[a][b][c][d][e];[a]trim=start=0.5:end=14,setpts=(PTS-STARTPTS)/1.25[v0];[b]trim=start=18.5:end=21.5,setpts=PTS-STARTPTS,crop=1038:1300:0:0,pad=1038:1380:0:0:white[v1];[c]trim=start=26.5:end=30.8,setpts=PTS-STARTPTS,crop=1038:1300:0:0,pad=1038:1380:0:0:white[v2];[d]trim=start=32.5:end=36,setpts=PTS-STARTPTS,crop=1038:1300:0:0,pad=1038:1380:0:0:white[v3];[e]trim=start=41.5:end=53,setpts=(PTS-STARTPTS)/1.25,crop=1038:1300:0:0,pad=1038:1380:0:0:white[v4];[v0][v1][v2][v3][v4]concat=n=5:v=1:a=0,fps=20,format=yuv420p[out]' \
  -map '[out]' -an -map_metadata -1 -c:v libx264 -preset slow -crf 20 \
  -movflags +faststart -y docs/media/wikipedia-reddit-demo.mp4
ffmpeg -hide_banner -loglevel error -i docs/media/wikipedia-reddit-demo.mp4 \
  -filter_complex '[0:v]fps=10,scale=520:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a' \
  -loop 0 -map_metadata -1 -y docs/media/wikipedia-demo.gif
