#!/usr/bin/env python3
"""Merge Agent Sonos Chime hooks into user-level Claude Code and Codex config."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

DEFAULT_BIN_DIR = "$HOME/.local/bin"


def claude_command(bin_dir: str) -> str:
    return f"bash -lc '{bin_dir}/claude-code-sonos-chime.sh'"


def codex_notify(bin_dir: str) -> str:
    return f'notify = ["bash", "-lc", "{bin_dir}/codex-notify-sonos-wrapper.sh"]'


def backup(path: Path) -> Optional[Path]:
    if not path.exists():
        return None
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    dest = path.with_name(f"{path.name}.bak.{stamp}")
    shutil.copy2(path, dest)
    return dest


def claude_has_command(entries: list[dict]) -> bool:
    for entry in entries:
        for hook in entry.get("hooks", []):
            if "claude-code-sonos-chime.sh" in hook.get("command", ""):
                return True
    return False


def ensure_claude_hook(data: dict, event: str, command: str) -> bool:
    hooks = data.setdefault("hooks", {})
    entries = hooks.setdefault(event, [])
    if not isinstance(entries, list):
        hooks[event] = entries = []
    if claude_has_command(entries):
        return False
    entries.insert(
        0,
        {
            "hooks": [
                {
                    "type": "command",
                    "command": command,
                    "timeout": 10,
                }
            ]
        },
    )
    return True


def configure_claude(home: Path, dry_run: bool, bin_dir: str) -> Tuple[bool, Optional[Path]]:
    path = home / ".claude" / "settings.json"
    if path.exists() and path.read_text().strip():
        data = json.loads(path.read_text())
    else:
        data = {}

    command = claude_command(bin_dir)
    changed = ensure_claude_hook(data, "Notification", command)
    changed = ensure_claude_hook(data, "Stop", command) or changed
    if not changed:
        return False, None

    backup_path = None
    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        backup_path = backup(path)
        path.write_text(json.dumps(data, indent=2) + "\n")
    return True, backup_path


def configure_codex(home: Path, dry_run: bool, bin_dir: str) -> Tuple[bool, Optional[Path]]:
    path = home / ".codex" / "config.toml"
    original = path.read_text() if path.exists() else ""
    lines = original.splitlines()
    new_lines: list[str] = []
    replaced = False
    notify_line = codex_notify(bin_dir)

    for line in lines:
        if line.lstrip().startswith("notify ="):
            if not replaced:
                new_lines.append(notify_line)
                replaced = True
            continue
        new_lines.append(line)

    if not replaced:
        if new_lines and new_lines[-1].strip():
            new_lines.append("")
        new_lines.append(notify_line)

    updated = "\n".join(new_lines).rstrip() + "\n"
    if updated == original:
        return False, None

    backup_path = None
    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        backup_path = backup(path)
        path.write_text(updated)
    return True, backup_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home(), help="home directory to patch")
    parser.add_argument("--bin-dir", default=DEFAULT_BIN_DIR, help="directory containing installed wrapper scripts")
    parser.add_argument("--dry-run", action="store_true", help="report changes without writing")
    parser.add_argument("--claude-only", action="store_true", help="only patch Claude Code settings")
    parser.add_argument("--codex-only", action="store_true", help="only patch Codex config")
    args = parser.parse_args()

    if args.claude_only and args.codex_only:
        parser.error("--claude-only and --codex-only cannot both be used")

    changes: list[str] = []
    if not args.codex_only:
        changed, backup_path = configure_claude(args.home, args.dry_run, args.bin_dir)
        changes.append(f"Claude Code: {'would update' if args.dry_run and changed else 'updated' if changed else 'already configured'}")
        if backup_path:
            changes.append(f"  backup: {backup_path}")

    if not args.claude_only:
        changed, backup_path = configure_codex(args.home, args.dry_run, args.bin_dir)
        changes.append(f"Codex: {'would update' if args.dry_run and changed else 'updated' if changed else 'already configured'}")
        if backup_path:
            changes.append(f"  backup: {backup_path}")

    print("\n".join(changes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
