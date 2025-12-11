#!/usr/bin/env zsh
#
# Comprehensive update script for DietPi, adapted for this system.
# Updates system packages, development tools, and shell environment.
#

# Ensure we're in a login shell environment
emulate -L zsh

# Set TERM for non-interactive sessions like cron
export TERM=${TERM:-dumb}

# Source zshrc to get the full PATH and environment, but suppress output
# to avoid polluting logs or command output.
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc" >/dev/null 2>&1 || true
fi

# ===== CONFIGURATION =====
TODAY="${TODAY_OVERRIDE:-$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"
LOGFILE="${LOGFILE_OVERRIDE:-${LOG_DIR}/update_all-${TODAY}.log}"

# Add paths to local git repositories you want to automatically pull updates for.
# Example:
# readonly GITS=(
#     "$HOME/git/my-project"
#     "$HOME/Work/another-repo"
# )
readonly GITS=()

# ===== HELPER FUNCTIONS =====
info() {
    echo "==================================>" "$@"
}

error() {
    echo "ERROR:" "$@" >&2
}

success() {
    echo "SUCCESS:" "$@"
}

skip() {
    echo "SKIP:" "$@"
}

# ===== CORE FUNCTIONS =====

# Check internet connection
check_internet() {
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed."
        return 1
    fi

    if ! curl -Is --connect-timeout 5 --max-time 10 "https://www.google.com" 2>/dev/null | head -n 1 | grep -q "200"; then
        error "No internet connection. Aborting updates."
        return 1
    fi
    return 0
}

# DietPi System Update (APT)
update_apt() {
    info "Updating APT packages (DietPi system)..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get --yes upgrade
        sudo apt-get --yes autoremove
        sudo apt-get --yes autoclean
        success "APT packages updated"
    else
        skip "apt-get command not found"
    fi
}

# DietPi Software Update
update_dietpi() {
    info "Checking for DietPi software updates..."
    if command -v dietpi-update >/dev/null 2>&1; then
        # The '1' argument attempts a non-interactive update.
        sudo /boot/dietpi/dietpi-update 1
        success "DietPi update check completed."
    else
        skip "dietpi-update command not found."
    fi
}

# Homebrew Update
update_homebrew() {
    info "Updating Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        brew update
        brew upgrade
        brew cleanup
        # Run doctor but continue even if it reports issues
        brew doctor || true
        success "Homebrew update completed"
    else
        skip "Homebrew not installed"
    fi
}

# Python (Rye) Update
update_rye() {
    info "Updating Rye (Python toolchain)..."
    if command -v rye >/dev/null 2>&1; then
        rye self update
        # You can add global tools to update here
        # Example:
        # if rye list 2>/dev/null | grep -q "httpie"; then
        #     rye install httpie --force
        # fi
        success "Rye updated"
    else
        skip "Rye not installed"
    fi
}

# Rust/Cargo Update
update_cargo() {
    info "Updating Rust and Cargo packages..."
    if command -v cargo >/dev/null 2>&1; then
        if command -v rustup >/dev/null 2>&1; then
            rustup update --no-self-update
        fi

        if command -v cargo-install-update >/dev/null 2>&1;
        then
            cargo install-update -a
        else
            info "Consider installing cargo-install-update for easier package updates: cargo install cargo-update"
        fi
        success "Rust/Cargo updated"
    else
        skip "Cargo not installed"
    fi
}

# Node.js/NPM Update
update_npm() {
    info "Updating Node.js and NPM packages..."

    # Initialize NVM (handles lazy loading from .zshrc)
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
    fi

    if ! command -v nvm >/dev/null 2>&1; then
        skip "NVM not found. Cannot update Node.js."
        return 1
    fi

    # Temporarily unset NPM_CONFIG_PREFIX if it exists, as it can interfere with nvm
    local _had_prefix=""
    if [[ -n "${NPM_CONFIG_PREFIX:-}" ]]; then
        info "Temporarily unsetting NPM_CONFIG_PREFIX for nvm compatibility"
        _had_prefix="$NPM_CONFIG_PREFIX"
        unset NPM_CONFIG_PREFIX
    fi

    nvm install --lts || { error "Failed to install latest LTS Node.js via nvm"; return 1; }
    nvm use --lts || { error "Failed to switch to latest LTS Node.js via nvm"; return 1; }
    nvm alias default 'lts/*' 2>/dev/null || true

    # Clear nvm cache
    info "Cleaning NVM cache..."
    nvm cache clear >/dev/null 2>&1
    success "NVM cache cleared."

    # Now that we're on the latest LTS, update npm itself and global packages
    if command -v npm >/dev/null 2>&1; then
        npm install -g npm@latest --quiet 2>/dev/null || true
        npm update -g --quiet 2>/dev/null || true
    fi

    # Restore NPM_CONFIG_PREFIX if it was set
    if [[ -n "$_had_prefix" ]]; then
        export NPM_CONFIG_PREFIX="$_had_prefix"
    fi

    success "Node.js/NPM updated (via nvm)"
}

# Oh My Zsh & Zgenom Update
update_zsh() {
    info "Updating Zsh environment (Oh My Zsh, zgenom)..."

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        (cd "$HOME/.oh-my-zsh" && git pull)
    fi

    if [[ -d "$HOME/.zgenom" ]]; then
        (cd "$HOME/.zgenom" && git pull)
        # Reset zgenom to force plugin updates on next shell start
        zgenom reset 2>/dev/null || true
    fi

    success "Zsh environment updated"
}

# Opencode Update
update_opencode() {
    info "Updating Opencode..."
    if command -v opencode >/dev/null 2>&1; then
        opencode upgrade
        success "Opencode updated."
    else
        skip "opencode not found."
    fi
}

# Gemini CLI Update
update_gemini_cli() {
    info "Updating Gemini CLI..."
    if ! command -v npm >/dev/null 2>&1; then
        skip "npm not found, cannot update Gemini CLI."
        return 1
    fi

    # Initialize NVM if it exists, as it controls the npm version
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        source "$HOME/.nvm/nvm.sh"
    fi
    
    # Temporarily unset NPM_CONFIG_PREFIX if it exists, as it can interfere with nvm
    local _had_prefix=""
    if [[ -n "${NPM_CONFIG_PREFIX:-}" ]]; then
        info "Temporarily unsetting NPM_CONFIG_PREFIX for nvm compatibility"
        _had_prefix="$NPM_CONFIG_PREFIX"
        unset NPM_CONFIG_PREFIX
    fi

    # Ensure we are using the default nvm environment
    if command -v nvm >/dev/null 2>&1; then
      nvm use default >/dev/null 2>&1
    fi

    npm install -g @google/gemini-cli
    success "Gemini CLI updated."

    # Restore NPM_CONFIG_PREFIX if it was set
    if [[ -n "$_had_prefix" ]]; then
        export NPM_CONFIG_PREFIX="$_had_prefix"
    fi
}

# Git Repositories Update
update_git_repos() {
    if [ ${#GITS[@]} -eq 0 ]; then
        skip "No git repositories configured for update."
        return
    fi

    info "Updating configured git repositories..."
    local current_dir=$(pwd)

    for repo in "${GITS[@]}"; do
        if [[ -d "$repo" ]]; then
            info "Updating $repo..."
            (
              cd "$repo" && \
              git pull --no-edit --rebase && \
              git fetch --all --prune --jobs=10
            ) || {
                error "Failed to update $repo"
            }
        else
            error "Directory not found: $repo"
        fi
done

    cd "$current_dir"
    success "Git repositories updated."
}

# ===== CLEANUP =====

clean_caches() {
    info "Cleaning up caches to free up space..."

    # APT Cache (already in update_apt, but good for a dedicated run)
    if command -v apt-get >/dev/null 2>&1; then
        info "Cleaning APT cache..."
        sudo apt-get autoremove --yes >/dev/null 2>&1
        sudo apt-get autoclean --yes >/dev/null 2>&1
        success "APT cache cleaned."
    fi

    # Homebrew Cache
    if command -v brew >/dev/null 2>&1; then
        info "Cleaning Homebrew cache..."
        brew cleanup >/dev/null 2>&1
        success "Homebrew cache cleaned."
    fi

    # NPM Cache
    if command -v npm >/dev/null 2>&1; then
        info "Cleaning NPM cache..."
        npm cache clean --force >/dev/null 2>&1
        success "NPM cache cleaned."
    fi

    # Bun Cache
    if command -v bun >/dev/null 2>&1; then
        info "Cleaning Bun cache..."
        bun pm cache rm >/dev/null 2>&1
        success "Bun cache cleaned."
    fi

    # Cargo Cache
    if command -v cargo-cache >/dev/null 2>&1; then
        info "Cleaning Cargo cache..."
        cargo-cache -a >/dev/null 2>&1
        success "Cargo cache cleaned."
    else
        skip "cargo-cache not installed. Consider 'cargo install cargo-cache'."
    fi

    # Rye caches
    if command -v rye >/dev/null 2>&1; then
        info "Cleaning Rye caches..."
        rye tools clean >/dev/null 2>&1
        success "Rye caches cleaned."
    fi

    # Podman Images
    if command -v podman >/dev/null 2>&1; then
        info "Cleaning Podman images..."
        # Use --force for non-interactive pruning
        podman image prune --force >/dev/null 2>&1
        success "Podman images cleaned."
    fi

    # General user cache directory
    info "Cleaning general user cache directory (~/.cache)..."
    if [ -d "$HOME/.cache" ]; then
        # Be specific and careful. Remove contents of common cache producers.
        rm -rf "$HOME/.cache/pip"
        rm -rf "$HOME/.cache/fastfetch"
        rm -rf "$HOME/.cache/node-gyp"
        rm -rf "$HOME/.cache/uv"
        rm -rf "$HOME/.cache/zsh"
        success "Cleaned select directories from ~/.cache."
    fi

    success "Cache cleanup completed."

    info "Manual cleanup suggestions:"
    info "  - Review '$HOME/.local' for large, unnecessary files or applications."
    info "  - Consider 'podman system prune' for more aggressive Podman cleanup (requires confirmation)."
}

# ===== MAIN ORCHESTRATION =====

# Comprehensive update function
run_all_updates() {
    info "Starting comprehensive system update..."

    if ! check_internet; then
        return 1
    fi

    # System updates
    update_apt
    update_dietpi
    update_homebrew

    # Development tools
    update_rye
    update_cargo
    update_npm

    # Shell environment
    update_zsh

    # Specific applications
    update_opencode
    update_gemini_cli

    # User Git Repos
    update_git_repos

    # Final Cleanup
    clean_caches

    info "All updates completed!"
}

main() {
    local ONLY_CLEAN=false

    # Parse command-line arguments
    for arg in "$@"; do
        case "$arg" in
            --only-all-clean)
                ONLY_CLEAN=true
                shift
                ;;
            *)
                # Unknown argument, pass it through or handle as needed
                ;;
        esac
    done

    # Ensure log file is writable
    if ! : >"$LOGFILE" 2>/dev/null; then
        echo "ERROR: Cannot create log file at $LOGFILE" >&2
        LOGFILE=$(mktemp /tmp/update_all-fallback-XXXXXX.log)
        echo "INFO: Using fallback log file: $LOGFILE" >&2
    fi

    # Execute updates, redirecting all output to the log file
    (
        if [[ "$ONLY_CLEAN" = true ]]; then
            info "Running only cache cleanup (--only-all-clean)..."
            clean_caches || error "clean_caches failed"
            info "Cache cleanup completed."
        elif [[ -n "${UPDATE_ONLY:-}" ]]; then
            info "Selective update mode: $UPDATE_ONLY"
            local IFS=','
            for fn in $UPDATE_ONLY;
            do
                if typeset -f "$fn" >/dev/null 2>&1;
                then
                    info "Running $fn ..."\
                    "$fn" || error "$fn failed"
                else
                    error "Unknown function: $fn"
                fi
            done
            info "Selective update completed"
        else
            run_all_updates
        fi
        info "Log file created at: $LOGFILE"
    ) >"$LOGFILE" 2>&1

    # Print the log file path to stdout for the user
    echo "Update process finished. Log file is at: $LOGFILE"
}

main "$@"
