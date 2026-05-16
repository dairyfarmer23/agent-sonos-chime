# Agent Sonos Chime

Play a synced Sonos voice alert when Codex or Claude Code finishes a turn or
needs your attention.

The scripts are local-first and avoid secrets. They only need access to your
local Sonos network and local hook configuration.

## What It Does

- Discovers Sonos speakers on the local network.
- Plays a Codex or Claude Code voice alert.
- Uses a separate "Codex run failed" alert when Codex notify payloads mention
  a failure, error, crash, timeout, or non-zero exit.
- Groups stopped rooms first so multi-room playback stays in sync.
- Skips rooms that are already playing audio.
- Restores volume and grouping after playback.
- Falls back to a Mac sound if Sonos is unavailable.

## Requirements

- macOS or Linux shell environment
- `sonos` CLI from [`sonoscli`](https://sonoscli.sh/)
- `ffmpeg`
- Optional: `edge-tts` for more natural generated voices

On macOS with Homebrew:

```bash
brew install steipete/tap/sonoscli ffmpeg
python3 -m pip install --user edge-tts
```

If `edge-tts` is not on your `PATH`, either add your Python user bin directory
or generate audio with the fallback macOS `say` voice.

## Install

```bash
git clone https://github.com/dairyfarmer23/agent-sonos-chime.git
cd agent-sonos-chime
scripts/install.sh
```

Test discovery:

```bash
sonos discover
```

Test one room:

```bash
AGENT_CHIME_COOLDOWN_SECONDS=0 \
AGENT_CHIME_SONOS_ROOM="Kitchen" \
~/.local/bin/codex-sonos-chime.sh
```

Test all stopped rooms:

```bash
AGENT_CHIME_COOLDOWN_SECONDS=0 ~/.local/bin/codex-sonos-chime.sh
```

## Configure Claude Code

Add the hook entries from [examples/claude-settings.json](examples/claude-settings.json)
to `~/.claude/settings.json`.

The important command is:

```bash
$HOME/.local/bin/claude-code-sonos-chime.sh
```

Use it for both:

- `Notification`: Claude Code needs input or permission.
- `Stop`: Claude Code finished responding.

Restart Claude Code after changing settings.

## Configure Codex

Add the notify wrapper from [examples/codex-config.toml](examples/codex-config.toml)
to `~/.codex/config.toml`.

The important command is:

```bash
$HOME/.local/bin/codex-notify-sonos-wrapper.sh
```

Restart Codex after changing settings.

The Codex desktop app's visible "waiting for you" state is most reliably covered
by `notify`:

```toml
notify = ["bash", "-lc", "$HOME/.local/bin/codex-notify-sonos-wrapper.sh"]
```

If you already have a Codex desktop notifier command, preserve it by setting
`CODEX_DESKTOP_NOTIFY` before invoking the wrapper, or edit the wrapper to call
your existing notifier first.

## Environment Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `AGENT_CHIME_SONOS_ROOM` | `all` | `all`, one room name, or comma-separated rooms |
| `AGENT_CHIME_SONOS_COORDINATOR` | `Kitchen` | Preferred room to coordinate synced playback |
| `AGENT_CHIME_VOLUME` | `35` | Temporary alert volume |
| `AGENT_CHIME_SOUND` | Codex alert MP3 | Audio file to play |
| `AGENT_CHIME_FAILURE_SOUND` | Codex failure MP3 | Audio file for failed Codex notify events |
| `AGENT_CHIME_COOLDOWN_SECONDS` | `20` | Minimum seconds between alerts |

Example:

```bash
AGENT_CHIME_SONOS_COORDINATOR="Living Room" \
AGENT_CHIME_VOLUME=40 \
~/.local/bin/codex-sonos-chime.sh
```

## Safety Notes

- The scripts do not need API keys.
- Do not publish your real `~/.claude/settings.local.json` or `~/.codex/config.toml`.
- The alert only targets rooms that are currently stopped.
- Generated voice MP3s are intentionally not committed by default; generate them
  locally with `scripts/generate-alert-audio.sh`.

## Troubleshooting

If Sonos discovery fails on macOS, check System Settings:

`Privacy & Security -> Local Network`

The terminal or app running the hook may need local-network permission.

If you hear nothing:

```bash
sonos status --name "Kitchen" --format json
AGENT_CHIME_COOLDOWN_SECONDS=0 AGENT_CHIME_SONOS_ROOM="Kitchen" ~/.local/bin/codex-sonos-chime.sh
```

If grouped playback is not synced, use `AGENT_CHIME_SONOS_ROOM=all` so the script
uses Sonos grouping before playback.
