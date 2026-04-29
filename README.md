# claude-getting-started

One-command interactive setup for a Claude Code development environment.

Installs and configures **Claude Code CLI**, **Bun**, **RTK**, **GitHub CLI**, **GitLab CLI**, **tmux**, and an optional **Telegram plugin** — then auto-starts Claude inside a persistent tmux session on every login.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ryanavilar/claude-getting-started/main/setup-claude.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/ryanavilar/claude-getting-started.git
cd claude-getting-started
./setup-claude.sh
```

## What It Does

| Step | Tool | Details |
|------|------|---------|
| 1 | **Bun** | Installs or updates the Bun JavaScript runtime |
| 2 | **Claude Code** | Installs the Anthropic CLI via npm/bun |
| 3 | **Claude Settings** | Sets default model to `claude-opus-4-6` and effort to `high` |
| 4 | **RTK** | Clones [rtk-ai/rtk](https://github.com/rtk-ai/rtk) and installs deps |
| 5 | **GitHub CLI** | Installs `gh` and runs `gh auth login` — skips if already set up |
| 6 | **GitLab CLI** | *(optional)* Installs `glab` with support for self-hosted instances |
| 7 | **tmux** | Installs via Homebrew (macOS) or apt/dnf/pacman (Linux) |
| 8 | **Telegram** | *(optional)* Registers a Telegram bot as a Claude MCP server |
| 9 | **Auto-start** | Creates a launchd agent (macOS) or systemd service (Linux) that runs `tmux new -s claude` with Claude on login |

## Interactive Prompts

The script asks before each major action. You can skip anything:

```
Continue with setup? [Y/n]
Update Bun to latest? [Y/n]
Pull latest RTK changes? [Y/n]
Set up GitLab CLI (glab)? [y/N]             # opt-in
  Choose: 1) gitlab.com  2) Self-hosted     # if yes
  Auth: 1) Browser/OAuth  2) Access Token   # for self-hosted
Set up Telegram plugin for Claude? [y/N]    # opt-in
Start Claude in tmux session now? [Y/n]
Attach to the session now? [Y/n]
```

## Defaults

- **Model:** `claude-opus-4-6`
- **Effort:** `high`
- Existing `~/.claude/settings.json` is preserved — only `model` and `effort` keys are merged.

## tmux Session

After setup, Claude runs inside a tmux session named `claude` with an auto-restart loop:

```bash
tmux attach -t claude     # attach to the session
# Ctrl-B D                # detach (Claude keeps running)
tmux kill-session -t claude  # stop it
```

If Claude exits (`/exit`, crash), it automatically restarts after 2 seconds. Press `Ctrl-C` inside the session to break the loop.

## Auto-Start on Boot

| OS | Mechanism | Config Path |
|----|-----------|-------------|
| macOS | LaunchAgent | `~/Library/LaunchAgents/com.claude.tmux.plist` |
| Linux | systemd user service | `~/.config/systemd/user/claude-tmux.service` |

To disable:

```bash
# macOS
launchctl unload ~/Library/LaunchAgents/com.claude.tmux.plist

# Linux
systemctl --user disable claude-tmux.service
```

## Requirements

- macOS or Linux
- `git`
- `curl`
- One of: `npm`, `bun` (bun is installed by the script if missing)
- Homebrew (macOS) for tmux, or apt/dnf/pacman (Linux)

## License

MIT
