#!/usr/bin/env bash
set -euo pipefail

# ── Colors & helpers ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERR]${NC}   %s\n" "$*"; }
header()  { printf "\n${BOLD}${CYAN}━━━ %s ━━━${NC}\n\n" "$*"; }

prompt_yn() {
    local question="$1" default="${2:-y}"
    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$(printf "${BOLD}%s [Y/n]: ${NC}" "$question")" yn
        yn="${yn:-y}"
    else
        read -rp "$(printf "${BOLD}%s [y/N]: ${NC}" "$question")" yn
        yn="${yn:-n}"
    fi
    [[ "$yn" =~ ^[Yy] ]]
}

command_exists() { command -v "$1" &>/dev/null; }

# ── Detect OS ────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        *)      error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    info "Detected OS: $OS"
}

# ── 1. Install Bun ──────────────────────────────────────────────
install_bun() {
    header "Bun Runtime"
    if command_exists bun; then
        local current_ver
        current_ver="$(bun --version 2>/dev/null || echo 'unknown')"
        success "Bun already installed (v${current_ver})"
        if prompt_yn "Update Bun to latest?" "y"; then
            bun upgrade
            success "Bun updated to v$(bun --version)"
        fi
    else
        info "Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        success "Bun installed (v$(bun --version))"
    fi
}

# ── 2. Install / Update Claude Code ─────────────────────────────
install_claude() {
    header "Claude Code CLI"
    if command_exists claude; then
        local current_ver
        current_ver="$(claude --version 2>/dev/null || echo 'unknown')"
        success "Claude Code already installed (${current_ver})"
        info "Updating Claude Code..."
        npm install -g @anthropic-ai/claude-code@latest 2>/dev/null \
            || bun install -g @anthropic-ai/claude-code@latest 2>/dev/null \
            || warn "Could not auto-update — run: npm i -g @anthropic-ai/claude-code@latest"
    else
        info "Installing Claude Code via npm..."
        if command_exists npm; then
            npm install -g @anthropic-ai/claude-code@latest
        elif command_exists bun; then
            bun install -g @anthropic-ai/claude-code@latest
        else
            error "Neither npm nor bun found. Install Node.js or Bun first."
            exit 1
        fi
        success "Claude Code installed"
    fi
}

# ── 3. Configure Claude defaults ────────────────────────────────
configure_claude() {
    header "Claude Code Settings"
    local settings_dir="$HOME/.claude"
    local settings_file="$settings_dir/settings.json"

    mkdir -p "$settings_dir"

    if [[ -f "$settings_file" ]]; then
        info "Existing settings detected at $settings_file"
        info "Merging default model & effort settings..."
    else
        info "Creating new settings file..."
    fi

    local tmp_file
    tmp_file="$(mktemp)"

    if [[ -f "$settings_file" ]]; then
        cp "$settings_file" "$tmp_file"
    else
        echo '{}' > "$tmp_file"
    fi

    # Use python3 (available on macOS/most Linux) or bun to merge JSON
    if command_exists python3; then
        python3 -c "
import json, sys

with open('$tmp_file', 'r') as f:
    try:
        cfg = json.load(f)
    except json.JSONDecodeError:
        cfg = {}

cfg['model'] = 'claude-opus-4-6'
cfg['effort'] = 'high'

with open('$settings_file', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')

print('Settings written successfully')
"
    else
        # Fallback: write minimal settings if no python3
        if [[ ! -f "$settings_file" ]]; then
            cat > "$settings_file" <<'SETTINGS'
{
  "model": "claude-opus-4-6",
  "effort": "high"
}
SETTINGS
        else
            warn "python3 not found — please manually set model/effort in $settings_file"
        fi
    fi

    rm -f "$tmp_file"
    success "Default model: claude-opus-4-6"
    success "Default effort: high"
}

# ── 4. Install RTK ──────────────────────────────────────────────
install_rtk() {
    header "RTK (rtk-ai/rtk)"
    local rtk_dir="$HOME/.local/share/rtk"

    if [[ -d "$rtk_dir" ]]; then
        success "RTK already cloned at $rtk_dir"
        if prompt_yn "Pull latest changes?" "y"; then
            git -C "$rtk_dir" pull --ff-only
            success "RTK updated"
        fi
    else
        info "Cloning rtk-ai/rtk..."
        mkdir -p "$(dirname "$rtk_dir")"
        git clone https://github.com/rtk-ai/rtk.git "$rtk_dir"
        success "RTK cloned to $rtk_dir"
    fi

    info "Installing RTK dependencies..."
    cd "$rtk_dir"
    if [[ -f "package.json" ]]; then
        if command_exists bun; then
            bun install
        elif command_exists npm; then
            npm install
        fi
    fi

    # Check for install script or Makefile
    if [[ -f "install.sh" ]]; then
        info "Running RTK install script..."
        bash install.sh
    elif [[ -f "Makefile" ]]; then
        info "Running make install..."
        make install 2>/dev/null || warn "make install failed — check RTK docs"
    fi

    cd - >/dev/null
    success "RTK setup complete"
}

# ── 5. Install tmux ─────────────────────────────────────────────
install_tmux() {
    header "tmux"
    if command_exists tmux; then
        success "tmux already installed ($(tmux -V))"
    else
        info "Installing tmux..."
        if [[ "$OS" == "macos" ]]; then
            if command_exists brew; then
                brew install tmux
            else
                error "Homebrew not found. Install it first: https://brew.sh"
                return 1
            fi
        else
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y tmux
            elif command_exists dnf; then
                sudo dnf install -y tmux
            elif command_exists pacman; then
                sudo pacman -S --noconfirm tmux
            else
                error "No supported package manager found. Install tmux manually."
                return 1
            fi
        fi
        success "tmux installed ($(tmux -V))"
    fi
}

# ── 6. Telegram Plugin (optional) ───────────────────────────────
SETUP_TELEGRAM=false
TELEGRAM_BOT_TOKEN=""

setup_telegram() {
    header "Telegram Plugin for Claude"

    if ! prompt_yn "Set up Telegram plugin for Claude?" "n"; then
        info "Skipping Telegram setup"
        return
    fi

    SETUP_TELEGRAM=true

    # Install the telegram MCP plugin
    info "Installing Telegram MCP plugin..."

    local telegram_dir="$HOME/.claude/plugins/telegram"
    mkdir -p "$telegram_dir"

    # Check if @anthropic-ai/claude-code has a plugin install command
    if claude mcp list 2>/dev/null | grep -qi telegram; then
        success "Telegram plugin already registered"
    else
        info "Adding Telegram MCP server..."

        read -rp "$(printf "${BOLD}Enter your Telegram Bot Token: ${NC}")" TELEGRAM_BOT_TOKEN

        if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
            warn "No bot token provided — skipping Telegram setup"
            SETUP_TELEGRAM=false
            return
        fi

        read -rp "$(printf "${BOLD}Enter allowed Telegram user IDs (comma-separated, or 'all'): ${NC}")" TELEGRAM_ALLOWED_USERS

        # Install the telegram plugin package
        info "Installing telegram plugin package..."
        if command_exists bun; then
            bun add -g claude-telegram-plugin 2>/dev/null || true
        fi

        # Register MCP server for telegram
        claude mcp add telegram \
            -e TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
            -e TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-all}" \
            -- npx -y claude-telegram-plugin 2>/dev/null \
            || warn "Could not auto-register Telegram MCP. You may need to configure it manually."

        success "Telegram plugin configured"
        info "Bot token stored in Claude MCP config"
    fi
}

# ── 7. Create tmux startup service ──────────────────────────────
setup_tmux_autostart() {
    header "tmux Auto-Start on Boot"

    local claude_cmd="claude"
    if [[ "$SETUP_TELEGRAM" == true ]]; then
        claude_cmd="claude --mcp telegram"
        info "Claude will start with Telegram plugin"
    fi

    local startup_script="$HOME/.local/bin/start-claude-tmux.sh"
    mkdir -p "$(dirname "$startup_script")"

    # Resolve full path to claude so the startup script doesn't depend on PATH at boot
    local claude_bin
    claude_bin="$(command -v claude 2>/dev/null || echo "claude")"

    cat > "$startup_script" <<'OUTER'
#!/usr/bin/env bash
# Auto-generated by setup-claude.sh — starts Claude in a tmux session

export PATH="$HOME/.bun/bin:$HOME/.nvm/versions/node/current/bin:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
export HOME="${HOME:-$(eval echo ~$(whoami))}"

CLAUDE_BIN="__CLAUDE_BIN__"
CLAUDE_ARGS="__CLAUDE_ARGS__"

# Wait for system to settle on boot
sleep 3

# Verify claude exists
if ! command -v "$CLAUDE_BIN" &>/dev/null && [[ ! -x "$CLAUDE_BIN" ]]; then
    echo "[claude-tmux] ERROR: claude not found at $CLAUDE_BIN" >&2
    exit 1
fi

# Kill existing session if present
tmux kill-session -t claude 2>/dev/null || true

# Create new detached tmux session that runs claude in a restart loop.
# If claude exits (user types /exit, crash, etc.) it waits 2s and relaunches.
tmux new-session -d -s claude "while true; do $CLAUDE_BIN $CLAUDE_ARGS; echo '── Claude exited. Restarting in 2s... (Ctrl-C to stop) ──'; sleep 2; done"
OUTER

    # Patch in the resolved values
    local claude_args=""
    if [[ "$SETUP_TELEGRAM" == true ]]; then
        claude_args="--mcp telegram"
    fi
    sed -i.bak "s|__CLAUDE_BIN__|${claude_bin}|g" "$startup_script"
    sed -i.bak "s|__CLAUDE_ARGS__|${claude_args}|g" "$startup_script"
    rm -f "${startup_script}.bak"

    chmod +x "$startup_script"
    success "Startup script created at $startup_script"

    if [[ "$OS" == "macos" ]]; then
        setup_launchd_plist "$startup_script"
    else
        setup_systemd_service "$startup_script"
    fi
}

setup_launchd_plist() {
    local startup_script="$1"
    local plist_path="$HOME/Library/LaunchAgents/com.claude.tmux.plist"

    cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.tmux</string>
    <key>ProgramArguments</key>
    <array>
        <string>${startup_script}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.claude/logs/tmux-autostart.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.claude/logs/tmux-autostart.err</string>
</dict>
</plist>
PLIST

    mkdir -p "$HOME/.claude/logs"

    info "Loading launchd agent..."
    launchctl unload "$plist_path" 2>/dev/null || true
    launchctl load "$plist_path"

    success "LaunchAgent installed at $plist_path"
    success "Claude tmux session will auto-start on login"
}

setup_systemd_service() {
    local startup_script="$1"
    local service_dir="$HOME/.config/systemd/user"
    local service_path="$service_dir/claude-tmux.service"

    mkdir -p "$service_dir"

    cat > "$service_path" <<SERVICE
[Unit]
Description=Claude Code in tmux session
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${startup_script}
ExecStop=/usr/bin/tmux kill-session -t claude

[Install]
WantedBy=default.target
SERVICE

    systemctl --user daemon-reload
    systemctl --user enable claude-tmux.service

    success "Systemd user service installed at $service_path"
    success "Claude tmux session will auto-start on login"
}

# ── 8. Launch now ────────────────────────────────────────────────
launch_now() {
    header "Launch"

    if prompt_yn "Start Claude in tmux session now?" "y"; then
        local claude_bin
        claude_bin="$(command -v claude 2>/dev/null || echo "claude")"
        local claude_args=""
        if [[ "$SETUP_TELEGRAM" == true ]]; then
            claude_args="--mcp telegram"
        fi

        tmux kill-session -t claude 2>/dev/null || true

        # Run claude inside tmux with a restart loop
        tmux new-session -d -s claude \
            "while true; do $claude_bin $claude_args; echo '── Claude exited. Restarting in 2s... (Ctrl-C to stop) ──'; sleep 2; done"

        success "Claude is running in tmux session 'claude'"

        if prompt_yn "Attach to the session now?" "y"; then
            print_summary
            exec tmux attach -t claude
        else
            info "Attach later with: tmux attach -t claude"
        fi
    else
        info "Skipped. Start manually with: tmux new -s claude 'claude'"
    fi
}

# ── Summary ──────────────────────────────────────────────────────
print_summary() {
    header "Setup Complete"

    echo -e "${BOLD}Installed:${NC}"
    command_exists bun    && echo -e "  ${GREEN}✓${NC} Bun $(bun --version 2>/dev/null)"
    command_exists claude && echo -e "  ${GREEN}✓${NC} Claude Code"
    command_exists tmux   && echo -e "  ${GREEN}✓${NC} tmux $(tmux -V 2>/dev/null | awk '{print $2}')"
    [[ -d "$HOME/.local/share/rtk" ]] && echo -e "  ${GREEN}✓${NC} RTK (rtk-ai/rtk)"
    [[ "$SETUP_TELEGRAM" == true ]]   && echo -e "  ${GREEN}✓${NC} Telegram plugin"

    echo ""
    echo -e "${BOLD}Claude defaults:${NC}"
    echo -e "  Model:  claude-opus-4-6"
    echo -e "  Effort: high"

    echo ""
    echo -e "${BOLD}Quick commands:${NC}"
    echo -e "  tmux attach -t claude    ${CYAN}# attach to running session${NC}"
    echo -e "  tmux kill-session -t claude  ${CYAN}# stop the session${NC}"
    echo -e "  claude                   ${CYAN}# start Claude directly${NC}"

    if [[ "$SETUP_TELEGRAM" == true ]]; then
        echo ""
        echo -e "${BOLD}Telegram:${NC}"
        echo -e "  Send a message to your bot to start chatting with Claude"
    fi
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    header "Claude Code Environment Setup"
    echo -e "This script will install and configure:"
    echo -e "  1. ${BOLD}Bun${NC} — JavaScript runtime"
    echo -e "  2. ${BOLD}Claude Code${NC} — Anthropic CLI (model: opus 4.6, effort: high)"
    echo -e "  3. ${BOLD}RTK${NC} — rtk-ai/rtk toolkit"
    echo -e "  4. ${BOLD}tmux${NC} — terminal multiplexer"
    echo -e "  5. ${BOLD}Telegram plugin${NC} — (optional) chat with Claude via Telegram"
    echo -e "  6. ${BOLD}Auto-start${NC} — tmux + Claude on login"
    echo ""

    if ! prompt_yn "Continue with setup?" "y"; then
        info "Setup cancelled"
        exit 0
    fi

    detect_os
    install_bun
    install_claude
    configure_claude
    install_rtk
    install_tmux
    setup_telegram
    setup_tmux_autostart
    launch_now
    print_summary
}

main "$@"
