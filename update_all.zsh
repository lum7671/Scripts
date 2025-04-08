#!/usr/bin/env zsh
# 로그인 쉘 환경 초기화를 위한 설정
emulate -L zsh
source ~/.zshrc

export PATH="$HOME/opt/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# ===== CONFIGURATION =====
readonly TODAY="$(date +%Y%m%d_%H%M%S)"
readonly LOGFILE="/private/tmp/update_all-${TODAY}.log"
readonly GITS=(
    "$HOME/git/Flex/"
    "$HOME/git/MacOS-All-In-One-Update-Script/"
    "$HOME/git/Scripts/"
    "$HOME/git/lum7671blog/"
    "$HOME/git/pelican-plugins/"
    "$HOME/git/python-language-server/"
    "$HOME/git/Update_All/"
    "$HOME/git/Hyperpipe/"
    "$HOME/git/dotfiles/"
    "$HOME/git/ff2mpv/"
    "$HOME/git/mopster/"
    "$HOME/git/my-dotfiles/"
    "$HOME/git/org-mode/"
    "$HOME/git/worg/"
    "$HOME/git/ytfzf/"
    "$HOME/git/minutes_diff/"
)

# ===== FUNCTIONS =====
info() {
    echo "==================================>" "$@"
}

update_rust_packages() {
    info "update all rust packages"
    cargo install-update -a
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

run_system_updates() {
    info "run update-all.sh"
    source "$HOME/git/MacOS-All-In-One-Update-Script/update-all.sh"
    update-brew
    update-atom
    update-npm
    update-gem
    update-pip3
    update-app_store
    update-macos

    info "Update_All.command"
    TERM=xterm bash "$HOME/git/Update_All/Update_All.command"
}

# ===== MAIN =====
main() {
    (
        update_rust_packages
        update_git_repos
        run_system_updates
        info "The End !!!"
    ) > "$LOGFILE" 2>&1
}

main "$@"
