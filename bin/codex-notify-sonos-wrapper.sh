#!/usr/bin/env bash

set -u

CODEX_DESKTOP_NOTIFY="${CODEX_DESKTOP_NOTIFY:-}"
FAILURE_SOUND="${AGENT_CHIME_FAILURE_SOUND:-$HOME/.local/share/agent-sonos-chime/codex-run-failed.mp3}"
payload="$(cat 2>/dev/null || true)"
signal_text="$* $payload ${CODEX_RUN_STATUS:-} ${CODEX_EXIT_CODE:-} ${CODEX_ERROR:-}"

if [[ -n "$CODEX_DESKTOP_NOTIFY" && -x "$CODEX_DESKTOP_NOTIFY" ]]; then
  "$CODEX_DESKTOP_NOTIFY" turn-ended "$@" >/dev/null 2>&1 || true
fi

if printf '%s' "$signal_text" | /usr/bin/grep -Eiq '(^|[^a-z])(fail|failed|failure|error|errored|crash|crashed|exception|timeout|timed out|cancelled|aborted|exit[^0-9]*[1-9][0-9]*)([^a-z]|$)'; then
  AGENT_CHIME_SOUND="$FAILURE_SOUND" "${HOME}/.local/bin/codex-sonos-chime.sh" >/dev/null 2>&1 || true
else
  "${HOME}/.local/bin/codex-sonos-chime.sh" >/dev/null 2>&1 || true
fi
