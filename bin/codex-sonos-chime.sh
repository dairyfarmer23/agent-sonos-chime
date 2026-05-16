#!/usr/bin/env bash

export AGENT_CHIME_SOUND="${AGENT_CHIME_SOUND:-$HOME/.local/share/agent-sonos-chime/codex-needs-you.mp3}"
export AGENT_CHIME_SONOS_ROOM="${AGENT_CHIME_SONOS_ROOM:-all}"

exec "${AGENT_CHIME_SCRIPT:-$HOME/.local/bin/agent-sonos-chime.sh}"
