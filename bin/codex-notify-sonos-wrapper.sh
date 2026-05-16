#!/usr/bin/env bash

set -u

CODEX_DESKTOP_NOTIFY="${CODEX_DESKTOP_NOTIFY:-}"
FAILURE_SOUND="${AGENT_CHIME_FAILURE_SOUND:-$HOME/.local/share/agent-sonos-chime/codex-run-failed.mp3}"
LOG_FILE="${TMPDIR:-/tmp}/codex-sonos-notify.log"
payload="$(cat 2>/dev/null || true)"
signal_text="$* $payload ${CODEX_RUN_STATUS:-} ${CODEX_EXIT_CODE:-} ${CODEX_ERROR:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
codex_chime="$script_dir/codex-sonos-chime.sh"
if [[ ! -x "$codex_chime" ]]; then
  codex_chime="$(command -v codex-sonos-chime.sh 2>/dev/null || true)"
fi
if [[ -z "$codex_chime" ]]; then
  codex_chime="${HOME}/.local/bin/codex-sonos-chime.sh"
fi

debug_log() {
  if [[ "${AGENT_CHIME_DEBUG:-}" == "1" ]]; then
    printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

debug_log "codex notify fired args=$* status=${CODEX_RUN_STATUS:-} exit=${CODEX_EXIT_CODE:-} error=${CODEX_ERROR:-}"
if [[ -n "$CODEX_DESKTOP_NOTIFY" && -x "$CODEX_DESKTOP_NOTIFY" ]]; then
  "$CODEX_DESKTOP_NOTIFY" turn-ended "$@" >/dev/null 2>&1 || true
fi

if printf '%s' "$signal_text" | /usr/bin/grep -Eiq '(^|[^a-z])(fail|failed|failure|error|errored|crash|crashed|exception|timeout|timed out|cancelled|aborted|exit[^0-9]*[1-9][0-9]*)([^a-z]|$)'; then
  debug_log "playing failure sound"
  AGENT_CHIME_SOUND="$FAILURE_SOUND" "$codex_chime" >/dev/null 2>&1 || true
else
  debug_log "playing normal sound"
  "$codex_chime" >/dev/null 2>&1 || true
fi
