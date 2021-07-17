#!/usr/bin/env zsh

TODAY="$(date +%Y%m%d_%H%M%S)"
LOGFILE="/private/tmp/update_all-${TODAY}.log"
GITS=(
    "/Users/x/.oh-my-zsh/custom/themes/agkozak/"
    "/Users/x/.oh-my-zsh/custom/themes/spaceship-prompt/"
    "/Users/x/.zgenom"
)

(
    echo "==================================> Update_All.command"
    TERM=xterm bash /Users/x/git/Update_All/Update_All.command
    # echo "==================================> update"
    # TERM=xterm bash /Users/x/git/update/bin/update
    for gp in "${GITS[@]}"
    do
        echo "$gp updating..."
        cd $gp
        git pull
        git fetch --all --prune --jobs=10
    done
    echo "==================================> The End !!!"
) > $LOGFILE 2>&1
