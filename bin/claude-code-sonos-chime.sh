#!/usr/bin/env bash

export AGENT_CHIME_SOUND="${AGENT_CHIME_SOUND:-$HOME/.local/share/agent-sonos-chime/claude-code-needs-you.mp3}"
export AGENT_CHIME_SONOS_ROOM="${AGENT_CHIME_SONOS_ROOM:-all}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_script="$script_dir/agent-sonos-chime.sh"
if [[ ! -x "$default_script" ]]; then
  default_script="$(command -v agent-sonos-chime.sh 2>/dev/null || true)"
fi
if [[ -z "$default_script" ]]; then
  default_script="$HOME/.local/bin/agent-sonos-chime.sh"
fi

exec "${AGENT_CHIME_SCRIPT:-$default_script}"
