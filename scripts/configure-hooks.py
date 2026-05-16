#!/usr/bin/env python3
"""Merge Agent Sonos Chime hooks into Claude Code and Codex config."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Iterable, Optional, Tuple

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


def remove_claude_hook(data: dict, event: str) -> bool:
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return False
    entries = hooks.get(event)
    if not isinstance(entries, list):
        return False

    changed = False
    kept_entries = []
    for entry in entries:
        entry_hooks = entry.get("hooks", [])
        kept_hooks = [
            hook
            for hook in entry_hooks
            if "claude-code-sonos-chime.sh" not in hook.get("command", "")
        ]
        if len(kept_hooks) != len(entry_hooks):
            changed = True
        if kept_hooks:
            next_entry = dict(entry)
            next_entry["hooks"] = kept_hooks
            kept_entries.append(next_entry)

    if changed:
        hooks[event] = kept_entries
    return changed


def configure_claude_file(path: Path, dry_run: bool, bin_dir: str, remove: bool = False) -> Tuple[bool, Optional[Path]]:
    if path.exists() and path.read_text().strip():
        data = json.loads(path.read_text())
    else:
        data = {}

    if remove:
        changed = remove_claude_hook(data, "Notification")
        changed = remove_claude_hook(data, "Stop") or changed
    else:
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


def configure_claude(home: Path, dry_run: bool, bin_dir: str, remove: bool = False) -> Tuple[bool, Optional[Path]]:
    return configure_claude_file(home / ".claude" / "settings.json", dry_run, bin_dir, remove)


def project_settings_path(project: Path) -> Path:
    return project / ".claude" / "settings.json"


def iter_claude_projects(root: Path) -> Iterable[Path]:
    for path in root.rglob(".claude/settings.json"):
        if ".git" in path.parts:
            continue
        yield path.parent.parent


def configure_codex(home: Path, dry_run: bool, bin_dir: str, remove: bool = False) -> Tuple[bool, Optional[Path]]:
    path = home / ".codex" / "config.toml"
    original = path.read_text() if path.exists() else ""
    lines = original.splitlines()
    new_lines: list[str] = []
    replaced = False
    notify_line = codex_notify(bin_dir)

    for line in lines:
        if line.lstrip().startswith("notify ="):
            if remove:
                if "codex-notify-sonos-wrapper.sh" in line:
                    replaced = True
                    continue
                new_lines.append(line)
                continue
            if not replaced:
                new_lines.append(notify_line)
                replaced = True
            continue
        new_lines.append(line)

    if not remove and not replaced:
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
    parser.add_argument("--remove", action="store_true", help="remove Agent Sonos Chime hooks instead of adding them")
    parser.add_argument("--claude-only", action="store_true", help="only patch Claude Code settings")
    parser.add_argument("--codex-only", action="store_true", help="only patch Codex config")
    parser.add_argument("--claude-project", type=Path, action="append", default=[], help="patch .claude/settings.json in this project")
    parser.add_argument("--all-claude-projects-under", type=Path, action="append", default=[], help="patch every .claude/settings.json under this root")
    args = parser.parse_args()

    if args.claude_only and args.codex_only:
        parser.error("--claude-only and --codex-only cannot both be used")

    changes: list[str] = []
    action = "remove" if args.remove else "update"
    if not args.codex_only:
        changed, backup_path = configure_claude(args.home, args.dry_run, args.bin_dir, args.remove)
        status = f"would {action}" if args.dry_run and changed else "removed" if args.remove and changed else "updated" if changed else "already configured"
        changes.append(f"Claude Code: {status}")
        if backup_path:
            changes.append(f"  backup: {backup_path}")

        project_paths = list(args.claude_project)
        for root in args.all_claude_projects_under:
            project_paths.extend(iter_claude_projects(root))
        seen: set[Path] = set()
        for project in project_paths:
            project = project.expanduser().resolve()
            if project in seen:
                continue
            seen.add(project)
            path = project_settings_path(project)
            changed, backup_path = configure_claude_file(path, args.dry_run, args.bin_dir, args.remove)
            status = f"would {action}" if args.dry_run and changed else "removed" if args.remove and changed else "updated" if changed else "already configured"
            changes.append(f"Claude project {project}: {status}")
            if backup_path:
                changes.append(f"  backup: {backup_path}")

    if not args.claude_only:
        changed, backup_path = configure_codex(args.home, args.dry_run, args.bin_dir, args.remove)
        status = f"would {action}" if args.dry_run and changed else "removed" if args.remove and changed else "updated" if changed else "already configured"
        changes.append(f"Codex: {status}")
        if backup_path:
            changes.append(f"  backup: {backup_path}")

    print("\n".join(changes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
