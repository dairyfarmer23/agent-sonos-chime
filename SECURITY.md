# Security

This project is intentionally local-first.

It does not need API tokens, browser cookies, local browser profiles, SSH keys,
Claude/Codex transcripts, or private workspace files.

Do not commit:

- `~/.claude/settings.local.json`
- `~/.codex/config.toml`
- generated logs from `/tmp`
- environment files containing tokens
- private audio files or user recordings

The scripts call `sonos` on your local network and may generate alert audio with
either local macOS voices or `edge-tts`. Review generated audio and hook behavior
before enabling it globally.
