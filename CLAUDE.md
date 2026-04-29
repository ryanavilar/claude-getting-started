# CLAUDE.md

## Project Overview

Single-file Bash setup script that bootstraps a full Claude Code development environment. Interactive, idempotent, and works on macOS and Linux.

## Structure

```
setup-claude.sh    # The entire setup script (single entry point)
README.md          # User-facing documentation
CLAUDE.md          # This file — context for Claude Code sessions
```

## Key Design Decisions

- **Single file**: Everything lives in `setup-claude.sh`. No Makefile, no installer framework. Keep it that way.
- **Idempotent**: Running the script twice should detect existing installs and offer updates, not break things.
- **Interactive**: Every destructive or opinionated action prompts the user. GitLab and Telegram are opt-in (default no). GitHub auto-installs but skips if present.
- **Merge, don't overwrite**: Claude settings at `~/.claude/settings.json` are merged via python3 JSON manipulation, not clobbered.
- **Restart loop in tmux**: Claude runs in a `while true` loop inside the tmux session so it auto-restarts on exit/crash.

## Conventions

- Shell: Bash (`#!/usr/bin/env bash`) with `set -euo pipefail`
- Color output via ANSI escape codes — helpers: `info`, `success`, `warn`, `error`, `header`
- Interactive prompts via `prompt_yn` (first arg = question, second = default y/n)
- Platform detection: `$OS` is either `macos` or `linux`

## What the Script Installs

1. Bun runtime
2. Claude Code CLI (`@anthropic-ai/claude-code`)
3. Claude settings: `model: claude-opus-4-6`, `effort: high`
4. RTK from `rtk-ai/rtk` → `~/.local/share/rtk`
5. GitHub CLI (`gh`) — auto-install, skips if already present and authenticated
6. (Optional) GitLab CLI (`glab`) — supports gitlab.com and self-hosted instances with token or OAuth auth
7. tmux
8. (Optional) Telegram MCP plugin
9. Auto-start service (launchd on macOS, systemd on Linux)
10. Startup script at `~/.local/bin/start-claude-tmux.sh`

## When Modifying

- Test on both macOS and Linux (or at least check both code paths).
- Keep the script under 800 lines. If it grows past that, split into sourced modules.
- Don't add dependencies beyond what the script itself installs (curl, git, python3 are assumed present).
- Preserve idempotency — every install step should check-before-act.
