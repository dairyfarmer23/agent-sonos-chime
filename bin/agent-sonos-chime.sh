#!/usr/bin/env bash

# Sonos attention alert for local coding agents.
# Conservative defaults:
# - only alert stopped rooms, so active music is not interrupted
# - group eligible rooms first, so multi-room playback stays in sync
# - restore volume and grouping after playback

set -u

ROOM="${AGENT_CHIME_SONOS_ROOM:-all}"
SOUND="${AGENT_CHIME_SOUND:-$HOME/.local/share/agent-sonos-chime/codex-needs-you.mp3}"
VOLUME="${AGENT_CHIME_VOLUME:-35}"
COORDINATOR="${AGENT_CHIME_SONOS_COORDINATOR:-Kitchen}"
COOLDOWN_SECONDS="${AGENT_CHIME_COOLDOWN_SECONDS:-20}"
STAMP_FILE="${TMPDIR:-/tmp}/agent-sonos-chime-${USER:-user}.stamp"
LOG_FILE="${TMPDIR:-/tmp}/agent-sonos-chime.log"

now="$(date +%s)"
last="0"
if [[ -f "$STAMP_FILE" ]]; then
  last="$(cat "$STAMP_FILE" 2>/dev/null || echo 0)"
fi

if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < COOLDOWN_SECONDS )); then
  exit 0
fi
printf '%s\n' "$now" > "$STAMP_FILE" 2>/dev/null || true

mac_chime() {
  if command -v afplay >/dev/null 2>&1 && [[ -f "$SOUND" ]]; then
    afplay "$SOUND" >/dev/null 2>&1 &
  elif command -v afplay >/dev/null 2>&1; then
    afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
  fi
}

if ! command -v sonos >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1 || [[ ! -f "$SOUND" ]]; then
  mac_chime
  exit 0
fi

(
  original_groups_file="${TMPDIR:-/tmp}/agent-sonos-chime-groups-${USER:-user}.json"
  sonos group status --format json > "$original_groups_file" 2>/dev/null || true

  rooms=()
  if [[ "$ROOM" == "all" ]]; then
    while IFS=$'\t' read -r name _ip _udn; do
      [[ -n "$name" ]] && rooms+=("$name")
    done < <(sonos discover 2>/dev/null || true)
  else
    IFS=',' read -r -a rooms <<< "$ROOM"
  fi

  if (( ${#rooms[@]} == 0 )); then
    mac_chime
    exit 0
  fi

  eligible_rooms=()
  original_volumes=()
  for room in "${rooms[@]}"; do
    room="${room#"${room%%[![:space:]]*}"}"
    room="${room%"${room##*[![:space:]]}"}"
    [[ -z "$room" ]] && continue

    status="$(sonos status --name "$room" --format json 2>/dev/null || true)"
    state="$(printf '%s' "$status" | /usr/bin/python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("transport",{}).get("State",""))' 2>/dev/null || true)"
    original_volume="$(printf '%s' "$status" | /usr/bin/python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("volume",""))' 2>/dev/null || true)"

    if [[ "$state" != "STOPPED" ]]; then
      continue
    fi

    eligible_rooms+=("$room")
    original_volumes+=("$original_volume")
  done

  if (( ${#eligible_rooms[@]} == 0 )); then
    mac_chime
    exit 0
  fi

  coordinator=""
  for room in "${eligible_rooms[@]}"; do
    if [[ "$room" == "$COORDINATOR" ]]; then
      coordinator="$room"
      break
    fi
  done
  if [[ -z "$coordinator" ]]; then
    coordinator="${eligible_rooms[0]}"
  fi

  for room in "${eligible_rooms[@]}"; do
    sonos volume set --name "$room" "$VOLUME" >/dev/null 2>&1 || true
  done

  if (( ${#eligible_rooms[@]} > 1 )); then
    if [[ "$ROOM" == "all" && ${#eligible_rooms[@]} -eq ${#rooms[@]} ]]; then
      sonos group party --to "$coordinator" >/dev/null 2>&1 || true
      sleep 1.0
    else
      for room in "${eligible_rooms[@]}"; do
        [[ "$room" == "$coordinator" ]] && continue
        sonos group join --name "$room" --to "$coordinator" >/dev/null 2>&1 || true
        sleep 0.2
      done
      sleep 0.6
    fi
  fi

  sonos play-url --name "$coordinator" "file://$SOUND" --title "Agent ready" --timeout 30s >/dev/null 2>&1 || true

  if (( ${#eligible_rooms[@]} > 1 )); then
    sonos group dissolve --name "$coordinator" >/dev/null 2>&1 || true
    sleep 0.6
  fi

  for i in "${!eligible_rooms[@]}"; do
    original_volume="${original_volumes[$i]}"
    if [[ "$original_volume" =~ ^[0-9]+$ ]]; then
      sonos volume set --name "${eligible_rooms[$i]}" "$original_volume" >/dev/null 2>&1 || true
    fi
  done

  if [[ -s "$original_groups_file" ]]; then
    /usr/bin/python3 - "$original_groups_file" <<'PY' | while IFS=$'\t' read -r coordinator_name member_name; do
import json
import sys

try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)

for group in data.get("groups", []):
    coordinator = (group.get("coordinator") or {}).get("name")
    if not coordinator:
        continue
    for member in group.get("members", []):
        name = member.get("name")
        if name and name != coordinator:
            print(f"{coordinator}\t{name}")
PY
      [[ -z "$coordinator_name" || -z "$member_name" ]] && continue
      sonos group join --name "$member_name" --to "$coordinator_name" >/dev/null 2>&1 || true
      sleep 0.2
    done
  fi
) </dev/null >"$LOG_FILE" 2>&1 &

exit 0
