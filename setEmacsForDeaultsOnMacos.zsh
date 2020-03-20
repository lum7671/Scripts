#!/usr/bin/env zsh

EXTENSIONS=(.log .viennastyle .rb .py .sql .xml .toml .crontab .emacs .gitconfig .bash_profile .zsh .sh .md .txt .profile .bashrc .zshrc)


for x in $EXTENSIONS
do
    m=$( echo "${x}" | sed -e "s/^\ *//g" -e "s/\ *$//g")
    [[ ! -z $m ]] &&  duti -vs org.gnu.Emacs $m all;
done

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
