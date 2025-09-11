#!/usr/bin/env zsh
# 로그인 쉘 환경 초기화를 위한 설정
emulate -L zsh

# cron 환경에서 TERM 변수 설정 (terminfo 에러 방지)
export TERM=${TERM:-dumb}

source ~/.zshrc

export PATH="$HOME/opt/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# ===== CONFIGURATION =====
readonly TODAY="$(date +%Y%m%d_%H%M%S)"
readonly LOGFILE="/private/tmp/update_all-${TODAY}.log"
readonly GITS=(
    "$HOME/git/KISS/"
    "$HOME/git/Scripts/"
    "$HOME/git/minutes_diff/"
)

# ===== FUNCTIONS =====
info() {
    echo "==================================>" "$@"
}

# System Update
update() {
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required but not installed. Please install curl." >&2
        return
    fi

    # Check internet connection by pinging a reliable server
    TEST_URL="https://www.google.com"

    # Use curl to check the connection
    TEST_RESP=$(curl -Is --connect-timeout 5 --max-time 10 "${TEST_URL}" 2>/dev/null | head -n 1)

    # Check if response is empty
    if [ -z "${TEST_RESP}" ]; then
        echo "No Internet Connection!!!" >&2
        return
    fi

    # Check for "200" in the response
    if ! printf "%s" "${TEST_RESP}" | grep -q "200"; then
        echo "Internet is not working!!!" >&2
        return
    fi

    curl -fsSL https://raw.githubusercontent.com/andmpel/MacOS-All-In-One-Update-Script/HEAD/update-all.sh | zsh
}

update_git_repos() {
    info "update git repositories"
    local current_dir=$(pwd)
    
    for repo in "${GITS[@]}"; do
        if [[ -d "$repo" ]]; then
            echo "Updating $repo..."
            cd "$repo"
            git pull
            git fetch --all --prune --jobs=10
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
    ) > "$LOGFILE" 2>&1
}

main "$@"
