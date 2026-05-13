#!/usr/bin/env zsh
#
# New modular entrypoint for system updates.
# Keeps behavior compatible with update_all.zsh while loading shared functions
# from upall_lib.zsh.
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

# Resolve script directory for sourcing library and helper scripts.
readonly UPALL_SCRIPT_DIR="${0:A:h}"
readonly UPALL_LIB_PATH="${UPALL_SCRIPT_DIR}/upall_lib.zsh"
readonly UPALL_CMD_NAME="${0:t}"

if [[ ! -r "$UPALL_LIB_PATH" ]]; then
    echo "ERROR: Library not found: $UPALL_LIB_PATH" >&2
    exit 1
fi

source "$UPALL_LIB_PATH"

# Add paths to local git repositories you want to automatically pull updates for.
readonly GIT_CHECK_LIST_FILE="$HOME/git/check.lst"
typeset -a _GIT_CHECK_ENTRIES=()

if [[ -r "$GIT_CHECK_LIST_FILE" ]]; then
    for repo_rel_path in "${(@f)$(<"$GIT_CHECK_LIST_FILE")}"; do
        # Normalize CRLF and trim surrounding whitespace from each line.
        repo_rel_path="${repo_rel_path//$'\r'/}"
        repo_rel_path="${repo_rel_path#"${repo_rel_path%%[![:space:]]*}"}"
        repo_rel_path="${repo_rel_path%"${repo_rel_path##*[![:space:]]}"}"

        [[ -z "$repo_rel_path" || "$repo_rel_path" == \#* ]] && continue

        if [[ "$repo_rel_path" == /* ]]; then
            _GIT_CHECK_ENTRIES+=("$repo_rel_path")
        else
            _GIT_CHECK_ENTRIES+=("$HOME/git/$repo_rel_path")
        fi
    done
fi

readonly GITS=(
    "${_GIT_CHECK_ENTRIES[@]}"
    "www-data:/opt/FreshRSS"
    "www-data:/opt/FreshRSS/extensions"
    "www-data:/opt/FreshRSS/extensions/git/freshrss-extensions"
    "www-data:/opt/FreshRSS/extensions/FreshRSS---Auto-Refresh-Extension"
    "www-data:/opt/FreshRSS/extensions/FreshRSS-AutoTTL"
    "root:/etc/.pihole"
)

# ===== TRACKING ARRAYS =====
typeset -a FAILED_UPDATES=()
typeset -a SKIPPED_UPDATES=()

main() {
    local ONLY_CLEAN=false
    local AGGRESSIVE_CLEAN=false
    local SKIP_ZIG_TEST=false
    local no_mail=false

    # Parse command-line arguments
    while (( $# > 0 )); do
        case "$1" in
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
                echo "Usage: $UPALL_CMD_NAME [options]"
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
                shift
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
                info "Running $fn ..."
                run_step "$fn"
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
