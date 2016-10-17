#!/usr/local/bin/zsh -li

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
tput=$(which tput)
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

printf "${YELLOW}%s${NORMAL}\n" ">> APPLE - UPDATE START <<"

sudo softwareupdate -i -a
sync

printf "${YELLOW}%s${NORMAL}\n" ">> BREW - UPDATE START <<"
(cd $(brew --repo) && git fetch && git reset --hard origin/master && brew update && git gc)
brew update
brew upgrade
sync
brew cleanup -s
brew cask cleanup
sync

# https://github.com/argon/mas
mas account
mas outdated
mas upgrade

printf "${YELLOW}%s${NORMAL}\n" ">> EMACS's CASK - UPDATE START <<"

EMACS="/Volumes/PDS/Homebrew-Caskroom/emacs/24.5-1/Emacs.app/Contents/MacOS/Emacs"
EMACSLOADPATH="/usr/local/share/emacs/site-lisp"

cd $HOME/.emacs.d
cask
cask update
# cask upgrade-cask
sync

printf "${YELLOW}%s${NORMAL}\n" ">> RUBY's GEM - UPDATE START <<"

gem update
sync
gem cleanup
sync

printf "${YELLOW}%s${NORMAL}\n" ">> Python's PIP  - UPDATE START <<"
pip install --upgrade pip
pip freeze --local | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U
sync

printf "${YELLOW}%s${NORMAL}\n" ">> BREW - UPDATE START <<"

# /bin/sh ~/.oh-my-zsh/tools/upgrade.sh
# upgrade_oh_my_zsh
env ZSH=$ZSH /bin/sh $ZSH/tools/upgrade.sh

sync
