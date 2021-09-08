#!/usr/bin/env zsh


TODAY="$(date +%Y%m%d_%H%M%S)"
LOGFILE="/private/tmp/update_all-${TODAY}.log"
GITS=(
#    "/Users/x/.oh-my-zsh/custom/themes/agkozak/"
#    "/Users/x/.oh-my-zsh/custom/themes/spaceship-prompt/"
#    "/Users/x/.zgenom"
    "$HOME/git/MacOS-All-In-One-Update-Script/"
    "$HOME/git/Scripts/"
    "$HOME/git/prelude/"
)

(
    echo "==================================> update git repository"
    for gp in "${GITS[@]}"
    do
        echo "$gp updating..."
        cd $gp
        git pull
        git fetch --all --prune --jobs=10
    done
    echo "==================================> run update-all.sh"
    /usr/local/bin/zsh $HOME/git/MacOS-All-In-One-Update-Script/update-all.sh
    # echo "==================================> Update_All.command"
    # TERM=xterm bash /Users/x/git/Update_All/Update_All.command
    # echo "==================================> update"
    # TERM=xterm bash /Users/x/git/update/bin/update
    echo "==================================> The End !!!"
) > $LOGFILE 2>&1
