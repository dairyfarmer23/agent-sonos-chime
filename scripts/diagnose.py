#!/usr/bin/env python3
"""Read-only diagnostics for Agent Sonos Chime."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import Optional


def status(ok: bool, label: str, detail: str = "", fix: str = "") -> str:
    prefix = "OK" if ok else "WARN"
    line = f"[{prefix}] {label}{': ' + detail if detail else ''}"
    if not ok and fix:
        line += f"\n  fix: {fix}"
    return line


def run(args: list[str], timeout: int = 8) -> tuple[int, str]:
    try:
        proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    except Exception as exc:
        return 1, str(exc)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def has_text(path: Path, text: str) -> bool:
    try:
        return text in path.read_text()
    except Exception:
        return False


def check_audio(home: Path) -> list[str]:
    audio_dir = home / ".local" / "share" / "agent-sonos-chime"
    expected = ["codex-needs-you.mp3", "codex-run-failed.mp3", "claude-code-needs-you.mp3"]
    homebrew_generator = Path("/opt/homebrew/opt/agent-sonos-chime/share/agent-sonos-chime/generate-alert-audio.sh")
    generator = str(homebrew_generator) if homebrew_generator.exists() else "scripts/generate-alert-audio.sh"
    generate = f"AGENT_CHIME_AUDIO_DIR={shlex.quote(str(audio_dir))} {generator}"
    return [status((audio_dir / name).is_file(), f"audio {name}", str(audio_dir / name), generate) for name in expected]


def check_claude(home: Path, project: Optional[Path]) -> list[str]:
    lines = []
    user_settings = home / ".claude" / "settings.json"
    lines.append(status(has_text(user_settings, "claude-code-sonos-chime.sh"), "Claude user hook", str(user_settings), "agent-sonos-configure-hooks --claude-only"))
    if project:
        project_settings = project / ".claude" / "settings.json"
        lines.append(status(has_text(project_settings, "claude-code-sonos-chime.sh"), "Claude project hook", str(project_settings), f"agent-sonos-configure-hooks --claude-project {project}"))
    return lines


def check_codex(home: Path) -> list[str]:
    config = home / ".codex" / "config.toml"
    return [status(has_text(config, "codex-notify-sonos-wrapper.sh"), "Codex notify wrapper", str(config), "agent-sonos-configure-hooks --codex-only")]


def check_logs() -> list[str]:
    lines = []
    for path in [Path(os.environ.get("TMPDIR", "/tmp")) / "agent-sonos-chime.log", Path(os.environ.get("TMPDIR", "/tmp")) / "codex-sonos-notify.log"]:
        if path.exists():
            tail = "\n".join(path.read_text(errors="replace").splitlines()[-5:])
            lines.append(status(True, f"log {path}", tail.replace("\n", " | ")))
        else:
            lines.append(status(False, f"log {path}", "missing", "set AGENT_CHIME_DEBUG=1 before running the agent hook"))
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--room", default="Kitchen")
    parser.add_argument("--claude-project", type=Path)
    parser.add_argument("--play-test", action="store_true", help="play a test alert through the configured wrapper")
    args = parser.parse_args()

    lines: list[str] = []
    command_fixes = {
        "sonos": "brew install steipete/tap/sonoscli",
        "ffmpeg": "brew install ffmpeg",
    }
    for command in ["sonos", "ffmpeg"]:
        lines.append(status(shutil.which(command) is not None, f"command {command}", shutil.which(command) or "not found", command_fixes[command]))
    lines.append(status(shutil.which("edge-tts") is not None, "command edge-tts", shutil.which("edge-tts") or "optional; macOS say fallback can be used", "python3 -m pip install --user edge-tts"))
    lines.extend(check_audio(args.home))
    lines.extend(check_claude(args.home, args.claude_project))
    lines.extend(check_codex(args.home))

    if shutil.which("sonos"):
        code, output = run(["sonos", "discover"], timeout=12)
        lines.append(status(code == 0 and bool(output), "Sonos discovery", output.replace("\n", " | ")[:500], "allow Local Network access for the terminal or agent app, then run sonos discover"))
        code, output = run(["sonos", "status", "--name", args.room, "--format", "json"], timeout=12)
        if code == 0:
            try:
                data = json.loads(output)
                detail = f"state={data.get('transport', {}).get('State')} volume={data.get('volume')}"
            except Exception:
                detail = output[:300]
            lines.append(status(True, f"Sonos room {args.room}", detail))
        else:
            lines.append(status(False, f"Sonos room {args.room}", output[:300], "run sonos discover and pass an exact room name with --room"))
    lines.extend(check_logs())

    if args.play_test:
        home_wrapper = args.home / ".local" / "bin" / "codex-sonos-chime.sh"
        path_wrapper = shutil.which("codex-sonos-chime.sh")
        wrapper = str(home_wrapper) if home_wrapper.exists() else path_wrapper
        if wrapper:
            env = os.environ.copy()
            env["AGENT_CHIME_COOLDOWN_SECONDS"] = "0"
            env["AGENT_CHIME_SONOS_ROOM"] = args.room
            proc = subprocess.run([wrapper], env=env, check=False)
            lines.append(status(proc.returncode == 0, "play test", f"exit={proc.returncode}"))
        else:
            lines.append(status(False, "play test", "missing codex-sonos-chime.sh"))

    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
