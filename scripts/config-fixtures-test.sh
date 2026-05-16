#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

BIN_DIR="$TMP_HOME/bin"
mkdir -p "$BIN_DIR"

"$ROOT/scripts/configure-hooks.py" --home "$TMP_HOME" --bin-dir "$BIN_DIR" >/tmp/agent-sonos-config-fixture-1.out
grep -q "claude-code-sonos-chime.sh" "$TMP_HOME/.claude/settings.json"
grep -q "codex-notify-sonos-wrapper.sh" "$TMP_HOME/.codex/config.toml"

"$ROOT/scripts/configure-hooks.py" --home "$TMP_HOME" --bin-dir "$BIN_DIR" >/tmp/agent-sonos-config-fixture-2.out
grep -q "Claude Code: already configured" /tmp/agent-sonos-config-fixture-2.out
grep -q "Codex: already configured" /tmp/agent-sonos-config-fixture-2.out

PROJECT_ONE="$TMP_HOME/projects/one"
PROJECT_TWO="$TMP_HOME/projects/two"
mkdir -p "$PROJECT_ONE/.claude" "$PROJECT_TWO/.claude"
cat >"$PROJECT_ONE/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo existing",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
JSON
printf '{}\n' >"$PROJECT_TWO/.claude/settings.json"

"$ROOT/scripts/configure-hooks.py" \
  --home "$TMP_HOME" \
  --bin-dir "$BIN_DIR" \
  --claude-project "$PROJECT_ONE" \
  --all-claude-projects-under "$TMP_HOME/projects" \
  >/tmp/agent-sonos-config-fixture-project-1.out

grep -q "echo existing" "$PROJECT_ONE/.claude/settings.json"
grep -q "claude-code-sonos-chime.sh" "$PROJECT_ONE/.claude/settings.json"
grep -q "claude-code-sonos-chime.sh" "$PROJECT_TWO/.claude/settings.json"

"$ROOT/scripts/configure-hooks.py" \
  --home "$TMP_HOME" \
  --bin-dir "$BIN_DIR" \
  --claude-project "$PROJECT_ONE" \
  --all-claude-projects-under "$TMP_HOME/projects" \
  >/tmp/agent-sonos-config-fixture-project-2.out

grep -q "Claude project .*projects/one: already configured" /tmp/agent-sonos-config-fixture-project-2.out
grep -q "Claude project .*projects/two: already configured" /tmp/agent-sonos-config-fixture-project-2.out

"$ROOT/scripts/diagnose.py" --home "$TMP_HOME" --claude-project "$PROJECT_ONE" >/tmp/agent-sonos-config-fixture-diagnose.out
grep -q "Claude user hook" /tmp/agent-sonos-config-fixture-diagnose.out
grep -q "Claude project hook" /tmp/agent-sonos-config-fixture-diagnose.out
grep -q "Codex notify wrapper" /tmp/agent-sonos-config-fixture-diagnose.out

"$ROOT/scripts/configure-hooks.py" \
  --home "$TMP_HOME" \
  --bin-dir "$BIN_DIR" \
  --claude-project "$PROJECT_ONE" \
  --remove \
  >/tmp/agent-sonos-config-fixture-remove.out

grep -q "Claude Code: removed" /tmp/agent-sonos-config-fixture-remove.out
grep -q "Claude project .*projects/one: removed" /tmp/agent-sonos-config-fixture-remove.out
grep -q "Codex: removed" /tmp/agent-sonos-config-fixture-remove.out
! grep -q "claude-code-sonos-chime.sh" "$TMP_HOME/.claude/settings.json"
! grep -q "claude-code-sonos-chime.sh" "$PROJECT_ONE/.claude/settings.json"
! grep -q "codex-notify-sonos-wrapper.sh" "$TMP_HOME/.codex/config.toml"
grep -q "claude-code-sonos-chime.sh" "$PROJECT_TWO/.claude/settings.json"

HOME="$TMP_HOME" AGENT_CHIME_CONFIGURE="$ROOT/scripts/configure-hooks.py" \
  "$ROOT/scripts/uninstall.sh" \
  --all-claude-projects-under "$TMP_HOME/projects" \
  >/tmp/agent-sonos-config-fixture-uninstall.out

grep -q "Claude project .*projects/two: removed" /tmp/agent-sonos-config-fixture-uninstall.out
! grep -q "claude-code-sonos-chime.sh" "$PROJECT_TWO/.claude/settings.json"

echo "config-fixtures-ok"
