#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
AUDIO_DIR="${HOME}/.local/share/agent-sonos-chime"

mkdir -p "$BIN_DIR" "$AUDIO_DIR"
install -m 0755 "$ROOT/bin/agent-sonos-chime.sh" "$BIN_DIR/agent-sonos-chime.sh"
install -m 0755 "$ROOT/bin/codex-sonos-chime.sh" "$BIN_DIR/codex-sonos-chime.sh"
install -m 0755 "$ROOT/bin/codex-notify-sonos-wrapper.sh" "$BIN_DIR/codex-notify-sonos-wrapper.sh"
install -m 0755 "$ROOT/bin/claude-code-sonos-chime.sh" "$BIN_DIR/claude-code-sonos-chime.sh"
install -m 0755 "$ROOT/scripts/configure-hooks.py" "$BIN_DIR/agent-sonos-configure-hooks"

if [[ ! -f "$AUDIO_DIR/codex-needs-you.mp3" || ! -f "$AUDIO_DIR/codex-run-failed.mp3" || ! -f "$AUDIO_DIR/claude-code-needs-you.mp3" ]]; then
  AGENT_CHIME_AUDIO_DIR="$AUDIO_DIR" "$ROOT/scripts/generate-alert-audio.sh"
fi

cat <<EOF
Installed agent Sonos chime scripts:
  $BIN_DIR/agent-sonos-chime.sh
  $BIN_DIR/codex-sonos-chime.sh
  $BIN_DIR/codex-notify-sonos-wrapper.sh
  $BIN_DIR/claude-code-sonos-chime.sh
  $BIN_DIR/agent-sonos-configure-hooks

Audio files:
  $AUDIO_DIR/codex-needs-you.mp3
  $AUDIO_DIR/codex-run-failed.mp3
  $AUDIO_DIR/claude-code-needs-you.mp3

Next: run $BIN_DIR/agent-sonos-configure-hooks to patch Codex and Claude Code config.
EOF
