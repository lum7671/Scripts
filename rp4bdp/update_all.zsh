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

# ===== TRACKING ARRAYS =====
declare -a FAILED_UPDATES=()
declare -a SKIPPED_UPDATES=()

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

# Track update result for final report
_track_result() {
    local fn_name="$1"
    local exit_code="$2"
    
    if [[ $exit_code -eq 0 ]]; then
        return 0
    elif [[ $exit_code -eq 2 ]]; then
        SKIPPED_UPDATES+=("$fn_name")
    else
        FAILED_UPDATES+=("$fn_name")
    fi
}

# Initialize NVM for Node.js operations
_init_nvm() {
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

# Manage NPM_CONFIG_PREFIX (needed for nvm compatibility)
_manage_npm_prefix() {
    local action="$1"  # "save" or "restore"
    
    if [[ "$action" = "save" ]]; then
        if [[ -n "${NPM_CONFIG_PREFIX:-}" ]]; then
            export _NPM_CONFIG_PREFIX_SAVED="$NPM_CONFIG_PREFIX"
            unset NPM_CONFIG_PREFIX
            return 0
        fi
    elif [[ "$action" = "restore" ]]; then
        if [[ -n "${_NPM_CONFIG_PREFIX_SAVED:-}" ]]; then
            export NPM_CONFIG_PREFIX="$_NPM_CONFIG_PREFIX_SAVED"
            unset _NPM_CONFIG_PREFIX_SAVED
        fi
    fi
    return 0
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

# Zig Compiler Update
update_zig() {
    info "Updating Zig compiler..."
    local manage_zig_path=""
    
    # Look for manage_zig.sh in common locations
    if [[ -x "${0:h}/manage_zig.sh" ]]; then
        manage_zig_path="${0:h}/manage_zig.sh"
    elif [[ -x "/usr/local/bin/manage_zig.sh" ]]; then
        manage_zig_path="/usr/local/bin/manage_zig.sh"
    elif [[ -x "$HOME/bin/manage_zig.sh" ]]; then
        manage_zig_path="$HOME/bin/manage_zig.sh"
    else
        skip "manage_zig.sh not found in expected locations"
        return 2
    fi
    
    # Run manage_zig.sh with skip-test for faster updates on DietPi
    # Capture output to check for success markers
    local output
    output=$("$manage_zig_path" --skip-test update 2>&1)
    local exit_code=$?
    
    # Print output from manage_zig.sh
    echo "$output"
    
    # Check if Zig is already up-to-date or was successfully updated (look for ✅ markers)
    if echo "$output" | grep -q "✅"; then
        success "Zig compiler status verified"
        return 0
    elif [[ $exit_code -eq 0 ]]; then
        success "Zig compiler updated"
        return 0
    else
        error "Zig compiler update failed"
        return 1
    fi
}

# Python (uv) Update
update_uv() {
    info "Updating uv (Python toolchain)..."
    if command -v uv >/dev/null 2>&1; then
        uv self update
        # You can add global tools to update here
        # Example:
        # if uv tool list 2>/dev/null | grep -q "httpie"; then
        #     uv tool install httpie --force
        # fi
        success "uv updated"
    else
        skip "uv not installed"
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

    # Initialize NVM using helper function
    if ! _init_nvm; then
        skip "NVM not found. Cannot update Node.js."
        return 2
    fi

    if ! command -v nvm >/dev/null 2>&1; then
        skip "NVM not found. Cannot update Node.js."
        return 2
    fi

    # Save and unset NPM_CONFIG_PREFIX for nvm compatibility
    _manage_npm_prefix "save"

    nvm install --lts || { error "Failed to install latest LTS Node.js via nvm"; _manage_npm_prefix "restore"; return 1; }
    nvm use --lts || { error "Failed to switch to latest LTS Node.js via nvm"; _manage_npm_prefix "restore"; return 1; }
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

    # Restore NPM_CONFIG_PREFIX
    _manage_npm_prefix "restore"

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
        return 2
    fi

    # Initialize NVM using helper function
    if ! _init_nvm; then
        skip "NVM not available for Gemini CLI update."
        return 2
    fi
    
    # Save and unset NPM_CONFIG_PREFIX for nvm compatibility
    _manage_npm_prefix "save"

    # Ensure we are using the default nvm environment
    if command -v nvm >/dev/null 2>&1; then
      nvm use default >/dev/null 2>&1 || true
    fi

    npm install -g @google/gemini-cli || { error "Failed to install Gemini CLI"; _manage_npm_prefix "restore"; return 1; }
    success "Gemini CLI updated."

    # Restore NPM_CONFIG_PREFIX
    _manage_npm_prefix "restore"
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

# Basic cache cleanup (safe, recommended for all systems)
clean_caches() {
    info "Cleaning up caches to free up space (safe mode)..."

    # APT Cache (DietPi system)
    if command -v apt-get >/dev/null 2>&1; then
        info "Cleaning APT cache..."
        sudo apt-get autoremove --yes >/dev/null 2>&1 || true
        sudo apt-get autoclean --yes >/dev/null 2>&1 || true
        success "APT cache cleaned."
    fi

    # Homebrew Cache
    if command -v brew >/dev/null 2>&1; then
        info "Cleaning Homebrew cache..."
        brew cleanup >/dev/null 2>&1 || true
        success "Homebrew cache cleaned."
    fi

    # NPM Cache
    if command -v npm >/dev/null 2>&1; then
        info "Cleaning NPM cache..."
        npm cache clean --force >/dev/null 2>&1 || true
        success "NPM cache cleaned."
    fi

    # Bun Cache
    if command -v bun >/dev/null 2>&1; then
        info "Cleaning Bun cache..."
        bun pm cache rm >/dev/null 2>&1 || true
        success "Bun cache cleaned."
    fi

    # Cargo Registry Cache (safe to remove, will be re-downloaded)
    if [[ -d "$HOME/.cargo/registry" ]]; then
        info "Cleaning Cargo registry cache..."
        rm -rf "$HOME/.cargo/registry/cache" "$HOME/.cargo/registry/index" >/dev/null 2>&1 || true
        success "Cargo registry cache cleaned."
    fi

    # uv caches
    if command -v uv >/dev/null 2>&1; then
        info "Cleaning uv caches..."
        uv cache clean >/dev/null 2>&1 || true
        success "uv caches cleaned."
    fi

    # Podman Images (reclaim space from container images)
    if command -v podman >/dev/null 2>&1; then
        info "Cleaning unused Podman images..."
        podman image prune --force >/dev/null 2>&1 || true
        success "Podman images cleaned."
    fi

    # Pip cache
    if [[ -d "$HOME/.cache/pip" ]]; then
        info "Cleaning pip cache..."
        rm -rf "$HOME/.cache/pip" || true
        success "Pip cache cleaned."
    fi

    # General user cache directory (safe to remove, will be recreated)
    info "Cleaning general user cache directory (~/.cache)..."
    if [[ -d "$HOME/.cache" ]]; then
        # Remove common cache directories that are safe to delete
        rm -rf "$HOME/.cache/fastfetch" 2>/dev/null || true
        rm -rf "$HOME/.cache/node-gyp" 2>/dev/null || true
        rm -rf "$HOME/.cache/uv" 2>/dev/null || true
        rm -rf "$HOME/.cache/zsh" 2>/dev/null || true
        success "Cleaned select directories from ~/.cache."
    fi

    success "Cache cleanup completed (safe mode)."
}

# Aggressive cleanup (space reclamation for DietPi/low-storage systems)
clean_caches_aggressive() {
    info "Running aggressive cache cleanup (WARNING: May affect development environment)..."
    
    # First run safe cleanup
    clean_caches
    
    info "Proceeding with aggressive cleanup steps..."
    
    # VS Code Server (downloaded binaries, will be re-downloaded on next remote connection)
    if [[ -d "$HOME/.vscode-server" ]]; then
        info "Removing VS Code Server binaries (~/.vscode-server)..."
        local vscode_size=$(du -sh "$HOME/.vscode-server" 2>/dev/null | awk '{print $1}') || vscode_size="unknown"
        info "  Size: $vscode_size (will be re-downloaded on next use)"
        rm -rf "$HOME/.vscode-server" || error "Failed to remove ~/.vscode-server"
        success "VS Code Server removed (will auto-reinstall on next connection)."
    fi

    # Gradle cache (build tool cache for Android/Java)
    if [[ -d "$HOME/.gradle/caches" ]]; then
        info "Removing Gradle build cache (~/.gradle/caches)..."
        local gradle_size=$(du -sh "$HOME/.gradle/caches" 2>/dev/null | awk '{print $1}') || gradle_size="unknown"
        info "  Size: $gradle_size (will be regenerated on next build)"
        rm -rf "$HOME/.gradle/caches" || error "Failed to remove ~/.gradle/caches"
        success "Gradle cache removed."
    fi

    # Full ~/.cache cleanup (if not already done)
    if [[ -d "$HOME/.cache" ]]; then
        info "Removing entire ~/.cache directory..."
        local cache_size=$(du -sh "$HOME/.cache" 2>/dev/null | awk '{print $1}') || cache_size="unknown"
        info "  Size: $cache_size"
        rm -rf "$HOME/.cache" || error "Failed to remove ~/.cache"
        success "Full cache directory removed (will be regenerated as needed)."
    fi

    # Old NVM versions (keep latest 2, remove older)
    if [[ -d "$HOME/.nvm/versions/node" ]]; then
        info "Cleaning old Node.js versions from NVM..."
        local versions=($(ls -1d "$HOME/.nvm/versions/node"/* 2>/dev/null | sort -V))
        if [[ ${#versions[@]} -gt 2 ]]; then
            info "  Keeping latest 2 versions, removing $((${#versions[@]} - 2)) older versions"
            for ((i=0; i < ${#versions[@]} - 2; i++)); do
                local ver_path="${versions[$i]}"
                local ver_name=$(basename "$ver_path")
                local ver_size=$(du -sh "$ver_path" 2>/dev/null | awk '{print $1}') || ver_size="unknown"
                info "  Removing $ver_name ($ver_size)"
                rm -rf "$ver_path" || error "Failed to remove $ver_path"
            done
            success "Old NVM versions cleaned."
        else
            skip "NVM has only ${#versions[@]} version(s), keeping all."
        fi
    fi

    # Old Rust toolchains (keep latest stable, remove older)
    if command -v rustup >/dev/null 2>&1; then
        info "Cleaning old Rust toolchains via rustup..."
        if rustup component list --installed >/dev/null 2>&1; then
            rustup component list --installed 2>/dev/null | head -5 || true
            success "Rustup toolchains reviewed (use 'rustup self uninstall' for full cleanup)."
        fi
    fi

    # Bun cache (more aggressive)
    if [[ -d "$HOME/.bun" ]]; then
        info "Removing Bun runtime cache (~/.bun)..."
        local bun_size=$(du -sh "$HOME/.bun" 2>/dev/null | awk '{print $1}') || bun_size="unknown"
        info "  Size: $bun_size (will be re-downloaded on next use)"
        rm -rf "$HOME/.bun" || error "Failed to remove ~/.bun"
        success "Bun cache removed."
    fi

    # npm global cache
    if [[ -d "$HOME/.npm" ]]; then
        info "Removing npm global cache (~/.npm)..."
        local npm_size=$(du -sh "$HOME/.npm" 2>/dev/null | awk '{print $1}') || npm_size="unknown"
        info "  Size: $npm_size"
        rm -rf "$HOME/.npm" || error "Failed to remove ~/.npm"
        success "npm global cache removed."
    fi

    success "Aggressive cache cleanup completed!"
    
    info ""
    info "Space reclamation suggestions:"
    info "  - Run 'df -h' to check current disk space"
    info "  - Review '$HOME/.local' for other large files"
    info "  - Consider 'podman system prune' for Docker/Podman (with confirmation)"
    info "  - DietPi-Backup can be run to optimize system backup"
}

# Summarize log and send email with upsum
run_upsum() {
    info "Summarizing log and sending email with upsum..."
    local upsum_dir="/home/dietpi/git/upsum"

    if [[ ! -d "$upsum_dir" ]]; then
        error "upsum directory not found at $upsum_dir"
        return 1
    fi

    if ! command -v uv >/dev/null 2>&1; then
        error "uv command not found, cannot run upsum"
        return 1
    fi

    local current_dir
    current_dir=$(pwd)
    cd "$upsum_dir"
    info "Running upsum..."
    uv run upsum --log-file "$LOGFILE"
    success "upsum run completed."
    cd "$current_dir"
}

# ===== MAIN ORCHESTRATION =====

# Print summary report of update results
print_update_summary() {
    local total_failed=${#FAILED_UPDATES[@]}
    local total_skipped=${#SKIPPED_UPDATES[@]}
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║               UPDATE SUMMARY REPORT                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ $total_failed -gt 0 ]]; then
        echo "❌ FAILED UPDATES ($total_failed):"
        for update in "${FAILED_UPDATES[@]}"; do
            echo "   - $update"
        done
        echo ""
    fi
    
    if [[ $total_skipped -gt 0 ]]; then
        echo "↩️  SKIPPED UPDATES ($total_skipped):"
        for update in "${SKIPPED_UPDATES[@]}"; do
            echo "   - $update"
        done
        echo ""
    fi
    
    if [[ $total_failed -eq 0 && $total_skipped -eq 0 ]]; then
        echo "✅ All updates completed successfully!"
    else
        echo "📊 Status: $total_failed failures, $total_skipped skipped"
    fi
    
    echo ""
}

# Comprehensive update function
run_all_updates() {
    info "Starting comprehensive system update..."
    FAILED_UPDATES=()
    SKIPPED_UPDATES=()

    if ! check_internet; then
        return 1
    fi

    # System updates
    update_apt; _track_result "update_apt" $?
    update_dietpi; _track_result "update_dietpi" $?
    update_homebrew; _track_result "update_homebrew" $?

    # Development tools (Zig before Cargo/uv/NPM for C compiler availability)
    update_zig; _track_result "update_zig" $?
    update_uv; _track_result "update_uv" $?
    update_cargo; _track_result "update_cargo" $?
    update_npm; _track_result "update_npm" $?

    # Shell environment
    update_zsh; _track_result "update_zsh" $?

    # Specific applications (Gemini CLI depends on NPM)
    update_opencode; _track_result "update_opencode" $?
    update_gemini_cli; _track_result "update_gemini_cli" $?

    # User Git Repos
    update_git_repos; _track_result "update_git_repos" $?

    # Final Cleanup
    clean_caches; _track_result "clean_caches" $?

    print_update_summary
    info "All updates completed!"
}

main() {
    local ONLY_CLEAN=false
    local AGGRESSIVE_CLEAN=false
    local SKIP_ZIG_TEST=false
    local no_mail=false

    # Parse command-line arguments
    for arg in "$@"; do
        case "$arg" in
            --only-all-clean)
                ONLY_CLEAN=true
                shift
                ;;
            --aggressive-clean)
                AGGRESSIVE_CLEAN=true
                shift
                ;;
            --skip-zig-test)
                SKIP_ZIG_TEST=true
                shift
                ;;
            --no-mail)
                no_mail=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --only-all-clean        Run only cache cleanup (basic + caches)"
                echo "  --aggressive-clean      Run aggressive cleanup (reclaim max space, slower)"
                echo "  --skip-zig-test         Skip Zig compiler build test (faster)"
                echo "  --no-mail               Skip sending email summary"
                echo "  --help, -h              Show this help message"
                echo ""
                echo "Environment variables:"
                echo "  UPDATE_ONLY             Comma-separated function names to run (e.g., 'update_apt,update_npm')"
                echo "  TODAY_OVERRIDE          Override date in log filename"
                echo "  LOGFILE_OVERRIDE        Override full log file path"
                exit 0
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
        elif [[ "$AGGRESSIVE_CLEAN" = true ]]; then
            info "Running aggressive cache cleanup (--aggressive-clean)..."
            clean_caches_aggressive || error "clean_caches_aggressive failed"
            info "Aggressive cache cleanup completed."
        elif [[ -n "${UPDATE_ONLY:-}" ]]; then
            info "Selective update mode: $UPDATE_ONLY"
            FAILED_UPDATES=()
            SKIPPED_UPDATES=()
            local IFS=','
            for fn in $UPDATE_ONLY;
            do
                if typeset -f "$fn" >/dev/null 2>&1;
                then
                    info "Running $fn ..."
                    "$fn" || error "$fn failed"
                    _track_result "$fn" $?
                else
                    error "Unknown function: $fn"
                fi
            done
            print_update_summary
            info "Selective update completed"
        else
            run_all_updates
            if [[ "$no_mail" = false ]]; then
                run_upsum
            else
                info "Skipping email summary (--no-mail specified)."
            fi
        fi
        info "Log file created at: $LOGFILE"
    ) >"$LOGFILE" 2>&1

    # Print the log file path to stdout for the user
    echo "Update process finished. Log file is at: $LOGFILE"
}

main "$@"
