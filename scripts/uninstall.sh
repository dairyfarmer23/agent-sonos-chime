#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="${AGENT_CHIME_BIN_DIR:-$HOME/.local/bin}"
AUDIO_DIR="${AGENT_CHIME_AUDIO_DIR:-$HOME/.local/share/agent-sonos-chime}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURE="${AGENT_CHIME_CONFIGURE:-$SCRIPT_DIR/agent-sonos-configure-hooks}"
REMOVE_LOCAL_FILES=0
REMOVE_AUDIO=0
CONFIG_ARGS=()

usage() {
  cat <<'EOF'
Usage: agent-sonos-uninstall [options]

Removes Agent Sonos Chime Codex and Claude Code hooks.

Options:
  --remove-local-files  also remove ~/.local/bin installed scripts
  --remove-audio        also remove generated local audio files
  --help                show this help

Any other option is passed to agent-sonos-configure-hooks, for example:
  --claude-project /path/to/project
  --all-claude-projects-under /path/to/root
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-local-files)
      REMOVE_LOCAL_FILES=1
      shift
      ;;
    --remove-audio)
      REMOVE_AUDIO=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      CONFIG_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -x "$CONFIGURE" ]]; then
  CONFIGURE="$(command -v agent-sonos-configure-hooks || true)"
fi

if [[ -z "$CONFIGURE" || ! -x "$CONFIGURE" ]]; then
  echo "agent-sonos-configure-hooks not found; cannot remove hooks" >&2
  exit 1
fi

if [[ "${#CONFIG_ARGS[@]}" -gt 0 ]]; then
  "$CONFIGURE" --remove "${CONFIG_ARGS[@]}"
else
  "$CONFIGURE" --remove
fi

if [[ "$REMOVE_LOCAL_FILES" -eq 1 ]]; then
  rm -f \
    "$BIN_DIR/agent-sonos-chime.sh" \
    "$BIN_DIR/codex-sonos-chime.sh" \
    "$BIN_DIR/codex-notify-sonos-wrapper.sh" \
    "$BIN_DIR/claude-code-sonos-chime.sh" \
    "$BIN_DIR/agent-sonos-configure-hooks" \
    "$BIN_DIR/agent-sonos-diagnose" \
    "$BIN_DIR/agent-sonos-uninstall"
  echo "Removed local scripts from $BIN_DIR"
fi

if [[ "$REMOVE_AUDIO" -eq 1 ]]; then
  rm -f \
    "$AUDIO_DIR/codex-needs-you.mp3" \
    "$AUDIO_DIR/codex-run-failed.mp3" \
    "$AUDIO_DIR/claude-code-needs-you.mp3"
  rmdir "$AUDIO_DIR" 2>/dev/null || true
  echo "Removed generated audio from $AUDIO_DIR"
fi
