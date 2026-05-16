#!/usr/bin/env bash

set -euo pipefail

REPO="${AGENT_CHIME_REPO:-dairyfarmer23/agent-sonos-chime}"
REF="${AGENT_CHIME_REF:-main}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

archive_url="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"
if [[ "$REF" == v* ]]; then
  archive_url="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz"
fi

archive="$TMP_DIR/agent-sonos-chime.tar.gz"
curl -fsSL "$archive_url" -o "$archive"
tar -xzf "$archive" -C "$TMP_DIR"

repo_dir="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'agent-sonos-chime-*' | head -1)"
if [[ -z "$repo_dir" || ! -x "$repo_dir/scripts/install.sh" ]]; then
  echo "Could not locate installer in downloaded archive" >&2
  exit 1
fi

"$repo_dir/scripts/install.sh"
