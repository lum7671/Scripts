#!/usr/bin/env zsh
# 로그인 쉘 환경 초기화를 위한 설정
emulate -L zsh

# cron 환경에서 TERM 변수 설정 (terminfo 에러 방지)
export TERM=${TERM:-dumb}

# 로그인 쉘 환경 로드 (PATH 포함)
source ~/.zshrc

# 로그인 쉘 환경의 PATH를 그대로 사용
# $HOME 우선 순위 PATH가 .zshrc에서 이미 설정됨

# ===== CONFIGURATION =====
readonly TODAY="$(date +%Y%m%d_%H%M%S)"
readonly LOGFILE="/private/tmp/update_all-${TODAY}.log"
readonly GITS=(
    "$HOME/git/KISS/"
    "$HOME/git/Scripts/"
    "$HOME/git/minutes_diff/"
    "$HOME/git/lsr/"
)

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
        sudo softwareupdate -ia --agree-to-license --verbose
        success "macOS system update completed"
    else
        skip "softwareupdate command not found"
    fi
}

# Homebrew Update
update_homebrew() {
    info "Updating Homebrew..."
    if command -v brew >/dev/null 2>&1; then
        brew update
        brew upgrade
        # --greedy 옵션으로 모든 cask 업데이트, --no-quarantine으로 확인 건너뛰기
        brew upgrade --cask --greedy --no-quarantine
        brew cleanup
        # doctor 결과에서 에러가 있어도 계속 진행
        brew doctor || true
        success "Homebrew update completed"
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

    # Initialize NVM (handles lazy loading)
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
        source "$NVM_DIR/bash_completion" 2>/dev/null || true
    fi

    # Try to use npm (this will trigger lazy loading if configured)
    if npm --version >/dev/null 2>&1; then
        # Update npm itself with --silent flag
        npm install -g npm@latest --silent

        # Update global packages with --silent flag
        npm update -g --silent

        # Update to latest LTS Node.js if nvm is available
        if command -v nvm >/dev/null 2>&1; then
            nvm install --lts --silent
            nvm use --lts --silent
            nvm alias default lts/* --silent
        fi

        success "Node.js/NPM updated"
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
        # Update global .NET tools
        dotnet tool list -g | tail -n +3 | awk '{print $1}' | xargs -I {} dotnet tool update -g {}
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
        $python_cmd -m pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 $python_cmd -m pip install -U --quiet 2>/dev/null || true
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

# ===== MAIN =====
main() {
    (
        update
        update_git_repos
        info "The End !!!"
    ) >"$LOGFILE" 2>&1
}

main "$@"
