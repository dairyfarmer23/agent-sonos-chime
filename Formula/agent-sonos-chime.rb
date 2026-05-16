class AgentSonosChime < Formula
  desc "Synced Sonos alerts for Codex and Claude Code hooks"
  homepage "https://github.com/dairyfarmer23/agent-sonos-chime"
  url "https://github.com/dairyfarmer23/agent-sonos-chime.git", tag: "v0.2.1"
  license "MIT"

  depends_on "ffmpeg"

  def install
    bin.install "bin/agent-sonos-chime.sh"
    bin.install "bin/codex-sonos-chime.sh"
    bin.install "bin/codex-notify-sonos-wrapper.sh"
    bin.install "bin/claude-code-sonos-chime.sh"
    bin.install "scripts/configure-hooks.py" => "agent-sonos-configure-hooks"
    bin.install "scripts/diagnose.py" => "agent-sonos-diagnose"
    pkgshare.install "scripts/generate-alert-audio.sh"
    pkgshare.install "examples"
  end

  def caveats
    <<~EOS
      Required separately:
        brew install steipete/tap/sonoscli

      Optional, for more natural generated voices:
        python3 -m pip install --user edge-tts

      Generate alert audio:
        AGENT_CHIME_AUDIO_DIR="$HOME/.local/share/agent-sonos-chime" #{opt_pkgshare}/generate-alert-audio.sh

      Configure hooks:
        agent-sonos-configure-hooks --bin-dir #{HOMEBREW_PREFIX}/bin

      Diagnose setup:
        agent-sonos-diagnose
    EOS
  end

  test do
    system "bash", "-n", "#{bin}/agent-sonos-chime.sh"
    system "python3", "-m", "py_compile", "#{bin}/agent-sonos-configure-hooks"
    system "python3", "-m", "py_compile", "#{bin}/agent-sonos-diagnose"
  end
end
