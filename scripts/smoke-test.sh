#!/usr/bin/env bash

set -euo pipefail

TMP_HOME="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

HOME="$TMP_HOME" bash -c 'curl -fsSL https://raw.githubusercontent.com/dairyfarmer23/agent-sonos-chime/main/scripts/install-remote.sh | bash' >/tmp/agent-sonos-smoke-install.out

test -x "$TMP_HOME/.local/bin/agent-sonos-chime.sh"
test -x "$TMP_HOME/.local/bin/codex-notify-sonos-wrapper.sh"
test -x "$TMP_HOME/.local/bin/claude-code-sonos-chime.sh"
test -x "$TMP_HOME/.local/bin/agent-sonos-configure-hooks"
test -x "$TMP_HOME/.local/bin/agent-sonos-diagnose"
test -x "$TMP_HOME/.local/bin/agent-sonos-uninstall"

test -f "$TMP_HOME/.local/share/agent-sonos-chime/codex-needs-you.mp3"
test -f "$TMP_HOME/.local/share/agent-sonos-chime/codex-run-failed.mp3"
test -f "$TMP_HOME/.local/share/agent-sonos-chime/claude-code-needs-you.mp3"

HOME="$TMP_HOME" "$TMP_HOME/.local/bin/agent-sonos-configure-hooks" >/tmp/agent-sonos-smoke-config-1.out
HOME="$TMP_HOME" "$TMP_HOME/.local/bin/agent-sonos-configure-hooks" >/tmp/agent-sonos-smoke-config-2.out
grep -q "already configured" /tmp/agent-sonos-smoke-config-2.out
grep -q "codex-notify-sonos-wrapper.sh" "$TMP_HOME/.codex/config.toml"
grep -q "claude-code-sonos-chime.sh" "$TMP_HOME/.claude/settings.json"

HOME="$TMP_HOME" "$TMP_HOME/.local/bin/agent-sonos-diagnose" >/tmp/agent-sonos-smoke-diagnose.out
grep -q "Codex notify wrapper" /tmp/agent-sonos-smoke-diagnose.out
grep -q "Claude user hook" /tmp/agent-sonos-smoke-diagnose.out

HOME="$TMP_HOME" "$TMP_HOME/.local/bin/agent-sonos-uninstall" >/tmp/agent-sonos-smoke-uninstall.out
grep -q "Claude Code: removed" /tmp/agent-sonos-smoke-uninstall.out
grep -q "Codex: removed" /tmp/agent-sonos-smoke-uninstall.out
! grep -q "claude-code-sonos-chime.sh" "$TMP_HOME/.claude/settings.json"
! grep -q "codex-notify-sonos-wrapper.sh" "$TMP_HOME/.codex/config.toml"

echo "smoke-test-ok"
