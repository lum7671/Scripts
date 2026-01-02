#!/usr/bin/env zsh
# 로그인 쉘 환경 초기화를 위한 설정
emulate -L zsh

# cron 환경에서 TERM 변수 설정 (terminfo 에러 방지)
export TERM=${TERM:-dumb}

# 로그인 쉘 환경 로드 (PATH 포함)
# 비대화(non-interactive) 실행 시 ~/.zshrc 내에서 터미널 제목(escape sequence) 등을 출력하는
# 구성이 stdout 으로 섞여 나와 로그파일 경로 캡처를 오염시키는 문제가 있으므로 출력은 억제
if [[ -f "$HOME/.zshrc" ]]; then
    # stdout/stderr 모두 무시 (PATH, 함수 정의는 환경에 남음)
    source "$HOME/.zshrc" >/dev/null 2>&1 || true
fi

# 로그인 쉘 환경의 PATH를 그대로 사용
# $HOME 우선 순위 PATH가 .zshrc에서 이미 설정됨

# ===== CONFIGURATION =====
# 날짜/시간 태그. 필요 시 외부에서 TODAY_OVERRIDE 로 강제 지정 가능
TODAY="${TODAY_OVERRIDE:-$(date +%Y%m%d_%H%M%S)}"
# 로그 파일 경로. LOGFILE_OVERRIDE 로 사용자 지정 가능
LOGFILE="${LOGFILE_OVERRIDE:-/private/tmp/update_all-${TODAY}.log}"
readonly GITS=(
    "$HOME/git/KISS/"
    "$HOME/git/Scripts/"
    "$HOME/git/minutes_diff/"
    "$HOME/git/lsr/"
)

# 실패한 업데이트 추적용 배열
FAILED_UPDATES=()

# ===== FUNCTIONS =====
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

# Check internet connection
check_internet() {
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed. Please install curl."
        return 1
    fi

    local test_url="https://www.google.com"
    local test_resp=$(curl -Is --connect-timeout 5 --max-time 10 "${test_url}" 2>/dev/null | head -n 1)

    if [ -z "${test_resp}" ]; then
        error "No Internet Connection!!!"
        return 1
    fi

    if ! printf "%s" "${test_resp}" | grep -q "200"; then
        error "Internet is not working!!!"
        return 1
    fi

    return 0
}

# macOS System Update
update_macos() {
    info "Updating macOS system..."
    if command -v softwareupdate >/dev/null 2>&1; then
        # --agree-to-license 옵션으로 라이선스 동의 자동화
        if sudo softwareupdate -ia --agree-to-license --verbose; then
            success "macOS system update completed"
        else
            error "macOS system update failed"
            FAILED_UPDATES+=("macOS")
        fi
    else
        skip "softwareupdate command not found"
    fi
}

# Homebrew Update
update_homebrew() {
    info "Updating Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        if brew update && brew upgrade && brew upgrade --cask --greedy && brew cleanup; then
            # doctor 결과에서 에러가 있어도 계속 진행
            brew doctor || true
            success "Homebrew update completed"
        else
            error "Homebrew update failed"
            FAILED_UPDATES+=("Homebrew")
        fi
    else
        skip "Homebrew not installed"
    fi
}

# Mac App Store Update
update_mas() {
    info "Updating Mac App Store apps..."
    if command -v mas >/dev/null 2>&1; then
        mas upgrade
        success "Mac App Store apps updated"
    else
        skip "mas (Mac App Store CLI) not installed"
    fi
}

# Python (Rye) Update
update_rye() {
    info "Updating Rye (Python toolchain)..."
    if command -v rye >/dev/null 2>&1; then
        rye self update
        # Update global tools installed via rye (force reinstall without prompts)
        if rye list 2>/dev/null | grep -q "httpie"; then
            rye install httpie --force
        fi
        success "Rye updated"
    else
        skip "Rye not installed"
    fi
}

# Rust/Cargo Update
update_cargo() {
    info "Updating Rust and Cargo packages..."
    if command -v cargo >/dev/null 2>&1; then
        # Update Rust toolchain with --no-self-update to avoid prompts
        if command -v rustup >/dev/null 2>&1; then
            rustup update --no-self-update
        fi

        # Update cargo packages
        if command -v cargo-install-update >/dev/null 2>&1; then
            cargo install-update -a
        else
            echo "Consider installing cargo-install-update for easier package updates: cargo install cargo-update"
        fi
        success "Rust/Cargo updated"
    else
        skip "Cargo not installed"
    fi
}

# Node.js/NPM Update
update_npm() {
    info "Updating Node.js and NPM packages..."

    # Handle NPM_CONFIG_PREFIX incompatibility with nvm BEFORE loading nvm
    local _had_prefix=""
    if [[ -n "${NPM_CONFIG_PREFIX:-}" ]]; then
        info "Detected NPM_CONFIG_PREFIX=${NPM_CONFIG_PREFIX}; temporarily unsetting for nvm compatibility"
        _had_prefix="$NPM_CONFIG_PREFIX"
        unset NPM_CONFIG_PREFIX
    fi

    # Initialize NVM (handles lazy loading)
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh" 2>/dev/null
        source "$NVM_DIR/bash_completion" 2>/dev/null || true
    fi

    # If nvm is available, prefer managing Node via nvm
    if command -v nvm >/dev/null 2>&1; then
        # Install & switch to latest LTS (remove unsupported --silent flags)
        nvm install --lts || {
            error "Failed to install latest LTS via nvm"; return 1;
        }
        nvm use --lts || {
            error "Failed to switch to latest LTS via nvm"; return 1;
        }
        # Quote pattern to avoid zsh glob expansion error (was: lts/*)
        nvm alias default 'lts/*' 2>/dev/null || true

        # Now npm is the one bundled with LTS; upgrade npm & globals
        if command -v npm >/dev/null 2>&1; then
            npm install -g npm@latest --quiet 2>/dev/null || true
            npm update -g --quiet 2>/dev/null || true
        fi

        # Restore prefix if it existed
        if [[ -n "$_had_prefix" ]]; then
            export NPM_CONFIG_PREFIX="$_had_prefix"
        fi

        success "Node.js/NPM updated (via nvm)"
        return 0
    fi

    # Fallback: no nvm, but maybe npm exists globally
    if command -v npm >/dev/null 2>&1; then
        npm install -g npm@latest --quiet 2>/dev/null || true
        npm update -g --quiet 2>/dev/null || true
        success "NPM global packages updated (nvm not found)"
    else
        skip "NPM not available or not properly configured"
    fi
}

# Ruby (rbenv) Update
update_ruby() {
    info "Updating Ruby environment..."

    # Try to use rbenv (this will trigger lazy loading if configured)
    if rbenv --version >/dev/null 2>&1; then
        # Update rbenv
        if [[ -d "$HOME/.rbenv" ]]; then
            local current_dir=$(pwd)
            cd "$HOME/.rbenv" && git pull
            cd "$current_dir"
        fi

        # Update ruby-build
        if [[ -d "$HOME/.rbenv/plugins/ruby-build" ]]; then
            local current_dir=$(pwd)
            cd "$HOME/.rbenv/plugins/ruby-build" && git pull
            cd "$current_dir"
        fi

        success "Ruby environment updated"
    else
        skip "rbenv not available or not properly configured"
    fi
}

# Java (jenv) Update
update_java() {
    info "Updating Java environment..."

    # Try to use jenv (this will trigger lazy loading if configured)
    if jenv --version >/dev/null 2>&1; then
        # Update jenv
        if [[ -d "$HOME/.jenv" ]]; then
            local current_dir=$(pwd)
            cd "$HOME/.jenv" && git pull
            cd "$current_dir"
        fi

        success "Java environment updated"
    else
        skip "jenv not available or not properly configured"
    fi
}

# .NET Update
update_dotnet() {
    info "Updating .NET..."

    if command -v dotnet >/dev/null 2>&1; then
        # Update global .NET tools with error handling
        # Force English locale to avoid Korean messages
        local tools=$(LANG=en_US.UTF-8 dotnet tool list -g 2>/dev/null | tail -n +3 | awk '{print $1}')
        if [[ -n "$tools" ]]; then
            local updated=0
            local failed=0
            echo "$tools" | while IFS= read -r tool; do
                if LANG=en_US.UTF-8 DOTNET_CLI_UI_LANGUAGE=en dotnet tool update -g "$tool" 2>/dev/null; then
                    ((updated++))
                else
                    ((failed++))
                    echo "  Warning: Failed to update $tool (skipping)" >&2
                fi
            done
            info "Updated $updated .NET tools ($failed failed)"
        else
            info "No .NET global tools installed"
        fi
        success ".NET tools updated"
    else
        skip ".NET not installed"
    fi
}

# Python pip packages update
update_pip() {
    info "Updating pip packages..."

    # Use the python3 from PATH (prioritizes $HOME versions)
    local python_cmd
    if [[ -x "$HOME/.rye/shims/python3" ]]; then
        python_cmd="$HOME/.rye/shims/python3"
    else
        python_cmd=$(which python3 2>/dev/null)
    fi

    if [[ -n "$python_cmd" ]]; then
        info "Using Python: $python_cmd"

        # Update pip itself
        $python_cmd -m pip install --upgrade pip --quiet

        # Update outdated packages with --quiet flag to reduce output
        $python_cmd -m pip list --outdated | tail -n +3 | awk '{print $1}' | xargs -n1 $python_cmd -m pip install -U --quiet 2>/dev/null || true
        success "Pip packages updated"
    else
        skip "python3 not found in PATH"
    fi
}

# Oh My Zsh Update
update_ohmyzsh() {
    info "Updating Oh My Zsh and plugins..."

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        cd "$HOME/.oh-my-zsh" && git pull
    fi

    # Update zgenom if available
    if [[ -d "$HOME/.zgenom" ]]; then
        cd "$HOME/.zgenom" && git pull
        # Reset zgenom to force plugin updates
        zgenom reset 2>/dev/null || true
    fi

    success "Zsh environment updated"
}

# Emacs packages update (if Doom Emacs is installed)
update_emacs() {
    info "Updating Emacs packages..."

    if [[ -d "$HOME/.config/emacs" ]] && command -v doom >/dev/null 2>&1; then
        doom upgrade -!
        doom sync
        success "Doom Emacs updated"
    elif command -v emacs >/dev/null 2>&1; then
        skip "Emacs found but no specific package manager detected"
    else
        skip "Emacs not installed"
    fi
}

# Comprehensive update function
update() {
    info "Starting comprehensive system update..."

    # Check internet connection first
    if ! check_internet; then
        error "Internet connection required for updates"
        return 1
    fi

    # System updates
    update_macos
    update_homebrew
    update_mas

    # Development tools
    update_rye
    update_cargo
    update_npm
    update_ruby
    update_java
    update_dotnet
    update_pip

    # Shell and editor
    update_ohmyzsh
    update_emacs

    info "All updates completed!"
}

update_git_repos() {
    info "update git repositories"
    local current_dir=$(pwd)

    for repo in "${GITS[@]}"; do
        if [[ -d "$repo" ]]; then
            echo "Updating $repo..."
            cd "$repo"
            
            # Check if directory is a git repository
            if ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo "Warning: Not a git repository - $repo"
                continue
            fi
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo "Warning: Uncommitted changes in $repo - skipping pull"
                git fetch --all --prune --jobs=10 2>/dev/null || {
                    echo "Warning: Failed to fetch $repo"
                }
                continue
            fi
            
            # --no-edit 옵션으로 merge 커밋 메시지 편집기 열리지 않게 방지
            git pull --no-edit 2>/dev/null || {
                echo "Warning: Failed to pull $repo (possible conflicts or network issues)"
            }
            git fetch --all --prune --jobs=10 2>/dev/null || {
                echo "Warning: Failed to fetch $repo"
            }
        else
            echo "Warning: Directory not found - $repo"
        fi
    done

    cd "$current_dir"
}

# Summarize log and send email with upsum
run_upsum() {
    info "Summarizing log and sending email with upsum..."
    # Use macOS-compatible path
    local upsum_dir="$HOME/git/Scripts/macos/upsum"

    if [[ ! -d "$upsum_dir" ]]; then
        error "upsum directory not found at $upsum_dir"
        FAILED_UPDATES+=("upsum")
        return 1
    fi

    if ! command -v rye >/dev/null 2>&1; then
        error "rye command not found, cannot run upsum"
        FAILED_UPDATES+=("upsum")
        return 1
    fi

    local current_dir
    current_dir=$(pwd)
    cd "$upsum_dir"
    info "Running upsum..."
    if rye run upsum --log-file "$LOGFILE"; then
        success "upsum run completed."
    else
        error "upsum run failed"
        FAILED_UPDATES+=("upsum")
    fi
    cd "$current_dir"
}

# ===== MAIN =====
main() {
    local no_mail=0
    for arg in "$@"; do
        if [[ "$arg" == "--no-mail" ]]; then
            no_mail=1
        fi
    done

    # 로그 파일이 확실히 존재하도록 사전 생성 (퍼미션/경로 문제 감지)
    if ! : >"$LOGFILE" 2>/dev/null; then
        echo "ERROR: Cannot create log file at $LOGFILE" >&2
        # mktemp fallback
        LOGFILE=$(mktemp /private/tmp/update_all-fallback-XXXXXX.log 2>/dev/null || mktemp /tmp/update_all-fallback-XXXXXX.log)
        echo "INFO: Using fallback log file: $LOGFILE" >&2
        : >"$LOGFILE" || true
    fi
    (
        if [[ -n "${UPDATE_ONLY:-}" ]]; then
            info "Selective update mode: $UPDATE_ONLY"
            local IFS=','
            for fn in $UPDATE_ONLY; do
                if typeset -f "$fn" >/dev/null 2>&1; then
                    info "Running $fn ..."
                    "$fn" || error "$fn failed"
                else
                    error "Unknown function: $fn"
                fi
            done
            info "Selective update completed"
        else
            update
            update_git_repos
            if (( ! no_mail )); then
                run_upsum
            else
                info "Skipping email summary (--no-mail specified)."
            fi
            
            # 실패한 업데이트 요약 출력
            if (( ${#FAILED_UPDATES[@]} > 0 )); then
                info "UPDATE SUMMARY: ${#FAILED_UPDATES[@]} component(s) failed"
                for component in "${FAILED_UPDATES[@]}"; do
                    echo "  - $component"
                done
            else
                info "UPDATE SUMMARY: All components updated successfully!"
            fi
            
            info "The End !!!"
        fi
    ) >"$LOGFILE" 2>&1
    # 실행 종료 후 존재 여부 재확인
    if [[ ! -f "$LOGFILE" ]]; then
        echo "ERROR: Log file unexpectedly missing: $LOGFILE" >&2
    fi
    # ESC / 제어문자가 혹시라도 섞였을 경우 제거 후 출력
    # (대부분은 위에서 ~/.zshrc 출력 억제로 필요 없지만 안전장치)
    local _clean_path
    _clean_path=$(printf '%s' "$LOGFILE" | tr -d '\033' )
    # 옵션: LOG_PATH_FILE 지정 시 파일로도 경로 저장
    if [[ -n "${LOG_PATH_FILE:-}" ]]; then
        printf '%s' "$_clean_path" >"$LOG_PATH_FILE" 2>/dev/null || true
    fi
    # 옵션: PRINT_LOG_MARKER=1 이면 마커 포함 출력 (preexec 오염 시 파싱 용이)
    if [[ -n "${PRINT_LOG_MARKER:-}" ]]; then
        echo "__UPDATE_ALL_LOG__ $_clean_path"
    else
        echo "$_clean_path"
    fi
}

main "$@"
