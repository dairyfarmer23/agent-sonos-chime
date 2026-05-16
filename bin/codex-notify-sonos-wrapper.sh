#!/usr/bin/env bash

set -u

CODEX_DESKTOP_NOTIFY="${CODEX_DESKTOP_NOTIFY:-}"

if [[ -n "$CODEX_DESKTOP_NOTIFY" && -x "$CODEX_DESKTOP_NOTIFY" ]]; then
  "$CODEX_DESKTOP_NOTIFY" turn-ended "$@" >/dev/null 2>&1 || true
fi

"${HOME}/.local/bin/codex-sonos-chime.sh" >/dev/null 2>&1 || true
