#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${AGENT_CHIME_AUDIO_DIR:-$HOME/.local/share/agent-sonos-chime}"
mkdir -p "$OUT_DIR"

generate_with_edge_tts() {
  local voice="$1"
  local text="$2"
  local out="$3"
  local raw
  raw="$(mktemp -t agent-chime-raw.XXXXXX.mp3)"

  edge-tts --voice "$voice" --rate=-14% --volume=+20% --text "$text" --write-media "$raw"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$raw" \
    -f lavfi -i "sine=frequency=659:duration=0.22" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100:duration=0.18" \
    -filter_complex "[1:a]volume=0.24,aresample=44100,pan=stereo|c0=c0|c1=c0[tone];[0:a]aresample=44100,pan=stereo|c0=c0|c1=c0,volume=1.2[voice];[2:a][tone][2:a][voice]concat=n=4:v=0:a=1[out]" \
    -map "[out]" -ar 44100 -ac 2 -b:a 192k "$out"
  rm -f "$raw"
}

generate_with_macos_say() {
  local voice="$1"
  local text="$2"
  local out="$3"
  local raw
  raw="$(mktemp -t agent-chime-raw.XXXXXX.aiff)"

  say -v "$voice" -r 145 -o "$raw" "$text"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$raw" \
    -f lavfi -i "sine=frequency=659:duration=0.22" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100:duration=0.18" \
    -filter_complex "[1:a]volume=0.24,aresample=44100,pan=stereo|c0=c0|c1=c0[tone];[0:a]aresample=44100,pan=stereo|c0=c0|c1=c0,volume=1.4[voice];[2:a][tone][2:a][voice]concat=n=4:v=0:a=1[out]" \
    -map "[out]" -ar 44100 -ac 2 -b:a 192k "$out"
  rm -f "$raw"
}

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required" >&2
  exit 1
fi

if command -v edge-tts >/dev/null 2>&1; then
  generate_with_edge_tts "en-US-GuyNeural" "Codex needs you. Please check in when you have a moment." "$OUT_DIR/codex-needs-you.mp3"
  generate_with_edge_tts "en-US-AvaNeural" "Claude Code needs you. Please check in when you have a moment." "$OUT_DIR/claude-code-needs-you.mp3"
elif command -v say >/dev/null 2>&1; then
  generate_with_macos_say "Daniel" "Codex needs you. Please check in when you have a moment." "$OUT_DIR/codex-needs-you.mp3"
  generate_with_macos_say "Samantha" "Claude Code needs you. Please check in when you have a moment." "$OUT_DIR/claude-code-needs-you.mp3"
else
  echo "Install edge-tts or use macOS say to generate alert audio" >&2
  exit 1
fi

echo "Generated alert audio in $OUT_DIR"
