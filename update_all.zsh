#!/usr/bin/env zsh -li


TODAY="$(date +%Y%m%d_%H%M%S)"
LOGFILE="/private/tmp/update_all-${TODAY}.log"
GITS=(
#    "/Users/x/.oh-my-zsh/custom/themes/agkozak/"
#    "/Users/x/.oh-my-zsh/custom/themes/spaceship-prompt/"
#    "/Users/x/.zgenom"
    "$HOME/git/Flex/"
    "$HOME/git/MacOS-All-In-One-Update-Script/"
    "$HOME/git/Scripts/"
    "$HOME/git/lum7671blog/"
    "$HOME/git/pelican-plugins/"
#    "$HOME/git/prelude/"
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
#    "$HOME/git/emacs-mac/"
#    "$HOME/git/doomemacs/"
    "$HOME/git/minutes_diff/"
)

(
    echo "==================================> update all rust packages"
    cargo install-update -a

    echo "==================================> update git repository"
    for gp in "${GITS[@]}"
    do
        echo "$gp updating..."
        cd $gp
        git pull
        git fetch --all --prune --jobs=10
    done

    echo "==================================> run update-all.sh"
    # [andmpel/MacOS-All-In-One-Update-Script: Mac update shell script (Appstore, macOS, Homebrew and others)](https://github.com/andmpel/MacOS-All-In-One-Update-Script)
    /usr/local/bin/zsh $HOME/git/MacOS-All-In-One-Update-Script/update-all.sh

    echo "==================================> Update_All.command"
    # [albinoz/Update_All: macOS Applications & System Update](https://github.com/albinoz/Update_All)
    TERM=xterm bash "$HOME/git/Update_All/Update_All.command"
    # echo "==================================> update"
    # TERM=xterm bash "$HOME/git/update/bin/update"

    # echo "==================================> JoplinBackup.zsh"
    # /usr/local/bin/zsh $HOME/git/Scripts/JoplinBackup.zsh

    echo "==================================> The End !!!"
) > $LOGFILE 2>&1
