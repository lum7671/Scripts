#!/usr/local/bin/zsh -li

CURDATE=$(date '+%Y%m%d')

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
tput=$(which tput)


if [ "$1" = "nocolor" ]; then
    tput=""
fi

if [ -n "$tput" ]; then
    ncolors=$(tput colors)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NORMAL=""
fi

printf -- "=========================================================================\n"
printf -- "- $CURDATE --------------------------------------------------------------\n"
printf -- "${YELLOW}%s${NORMAL}\n" ">> APPLE - UPDATE START <<"

# exit 0

sudo softwareupdate -i -a
sync
# https://github.com/argon/mas
mas account
mas outdated
mas upgrade

printf -- "${YELLOW}%s${NORMAL}\n" ">> BREW - UPDATE START <<"
(cd $(brew --repo) && git fetch && git reset --hard origin/master && brew update && git gc)
brew upgrade
brew update
sync
brew prune
brew cleanup -s
brew cask cleanup
rm -rf $(brew --cache)
sync

printf -- "${YELLOW}%s${NORMAL}\n" ">> EMACS's CASK - UPDATE START <<"
# EMACS="/Volumes/PDS/Homebrew-Caskroom/emacs/24.5-1/Emacs.app/Contents/MacOS/Emacs"
# EMACSLOADPATH="/usr/local/share/emacs/site-lisp"
cd "$HOME/Library/Preferences/Aquamacs Emacs/Packages"
cask
cask update
cask upgrade-cask
sync

printf -- "${YELLOW}%s${NORMAL}\n" ">> RUBY's GEM - UPDATE START <<"

sudo gem update # --system
sync
sudo gem cleanup
sync

printf -- "${YELLOW}%s${NORMAL}\n" ">> Python's PIP  - UPDATE START <<"
pip install --upgrade pip
# pip freeze --local | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U
for i in `pip list -o --format legacy|awk '{print $1}'` ; do pip install --upgrade $i; done
sync

printf -- "${YELLOW}%s${NORMAL}\n" ">> BREW - UPDATE START <<"

# /bin/sh ~/.oh-my-zsh/tools/upgrade.sh
# upgrade_oh_my_zsh
env ZSH=$ZSH /bin/sh $ZSH/tools/upgrade.sh

sync
printf -- "- $CURDATE --------------------------------------------------------------\n"
