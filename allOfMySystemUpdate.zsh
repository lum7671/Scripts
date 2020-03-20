#!/usr/bin/env zsh -l
# -*- coding: utf-8 -*-

export ALL_PROXY=pug.synology.me:3128

export PATH=$HOME/bin:$PATH
LANG=ko_KR.UTF-8
NVM_DIR=$HOME/.nvm

CURDATE=$(date '+%Y-%m-%d_%H:%M:%S')
LOG_FILE=$HOME/log/allOfMySystemUpdate_$CURDATE.log
# exec > >(while read -r line; do printf '%s %s\n' "$(date '+%y/%M/%d %T %Z')" "$line" | tee -a $LOG_FILE; done)
# exec 2> >(while read -r line; do printf '%s %s\n' "$(date '+%y/%M/%d %T %Z')" "$line" | tee -a $LOG_FILE; done >&2)
exec &> $LOG_FILE


# set -x

# Firewall Error 처리, 업데이트 동안 BSD pf disable 시킴.
sudo pfctl -d

sync
sleep 3
sync

# rvm-update
rvm get latest
# rvm 


echo $PATH

# for ruby
# source /Users/1001028/.rvm/scripts/rvm

# for python
export VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python3
source /usr/local/bin/virtualenvwrapper.sh # 각종 PATH 등을 설정해줌.
workon myenv


which python
which ruby

python --version
ruby --version


CURDATE=$(date '+%Y%m%d %H:%M')

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


function do_cmd {
    printf -- "${RED}${*}${NORMAL}\n"
    $*
}


printf -- "${YELLOW}%s${NORMAL}\n" ">> RUBY's GEM - UPDATE START <<"

# rvm get head
gem update # --system
sync
gem cleanup
sync




# nvm
(
  cd "$NVM_DIR"
  git fetch --tags origin
  git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
) && \. "$NVM_DIR/nvm.sh"




printf -- "${YELLOW}%s${NORMAL}\n" ">> BREW - UPDATE START <<"
# (cd $(brew --repo) && git fetch && git reset --hard origin/master && brew update && git gc)

# echo "#1"
brew update
sync

# echo "#2"
brew upgrade
# brew upgrade --cleanup
# brew-cask-upgrade.sh
sync

# https://github.com/buo/homebrew-cask-upgrade
#
# ALL_PROXY=socks5://127.0.0.1:9050 brew cu -ayq --cleanup
# http_proxy=pug.synology.me:3128 https_proxy=pug.synology.me:3128 brew cask reinstall tor-browser
#
# echo "#3"
# brew cu -ayq
brew cask upgrade
# brew cask upgrade --greedy
# brew-cask-upgrade -u
brew cu -ay --cleanup

sync

# homebrew cask upgrade
# brew cask outdated | xargs brew cask reinstall
# sync

# echo "#4"
brew cleanup -s
sync

# homebrew cleanup

# echo "#5"
# brew cask cleanup
# sync

# echo "#6"
#brew prune
#sync

# echo "#7"
rm -rf $(brew --cache)
sync



printf -- "==============================================================================\n"
printf -- "- $CURDATE -------------------------------------------------------------\n"
printf -- "${YELLOW}%s${NORMAL}\n" ">> APPLE - UPDATE START <<"

# exit 0

sudo softwareupdate -i -a
sync
# https://github.com/argon/mas
 mas account
 mas outdated
 mas upgrade
sync

sleep 3
sync


printf -- "${YELLOW}%s${NORMAL}\n" ">> Python's Anaconda  - UPDATE START <<"
echo "Nothing..."
# conda update --prefix /usr/local/anaconda3 anaconda
# conda update -n base conda -y
# conda upgrade -y --all --update-deps
# sync


# printf -- "${YELLOW}%s${NORMAL}\n" ">> Python's PIP  - UPDATE START <<"
# workon_upgrade.sh
# sync


printf -- "${YELLOW}%s${NORMAL}\n" ">> UpdateCommand/update - UPDATE START <<"

# https://github.com/UpdateCommand/update
(cd /Users/x/update;git checkout -- .;git pull;git fetch --all --prune)
# /Users/x/update/bin/update



#
# For Emacs
#

# EMACS="/Volumes/PDS/Homebrew-Caskroom/emacs/24.5-1/Emacs.app/Contents/MacOS/Emacs"
# EMACSLOADPATH="/usr/local/share/emacs/site-lisp"
#if [ -f "$HOME/Library/Preferences/Aquamacs Emacs/Packages/Cask" ]; then
#	printf -- "${YELLOW}%s${NORMAL}\n" ">> Emacs Cask( Aquamacs ) - UPDATE START <<"
#	cd "$HOME/Library/Preferences/Aquamacs Emacs/Packages"
#	cask upgrade-cask --verbose
#	cask update --verbose
#	cask install --verbose
#	sync
#fi

if [ -f "$HOME/.emacs.d/Cask" ]; then
	printf -- "${YELLOW}%s${NORMAL}\n" ">> Emacs Cask( .emacs.d/Cask ) - UPDATE START <<"
	cd "$HOME/.emacs.d"
	cask upgrade-cask --verbose
	cask install --verbose
	cask update --verbose
	cask clean-elc
	cask build
	sync
fi

# for Emacs's org-mode
(cd /Users/x/Works/org-mode; ./update.zsh)

### Added by Zplugin's installer
source '/Users/x/.zplugin/bin/zplugin.zsh'
autoload -Uz _zplugin
(( ${+_comps} )) && _comps[zplugin]=_zplugin

zplugin self-update
zplugin update


(cd /Users/x/.oh-my-zsh/custom/themes/agkozak;git pull)
(cd /Users/x/.oh-my-zsh/custom/themes/spaceship-prompt;git pull)

printf -- "${YELLOW}%s${NORMAL}\n" ">> Oh My Zsh - UPDATE START <<"

# /bin/sh ~/.oh-my-zsh/tools/upgrade.sh
# upgrade_oh_my_zsh

# env ZSH=$ZSH /bin/sh $ZSH/tools/upgrade.sh
upgrade_ohmyzsh.zsh

# antigen update

sync
printf -- "- $CURDATE -------------------------------------------------------------\n"


# https://welcomattic.github.io/kymsu/
kymsu cleanup

# Firewall Error 처리, 업데이트 후 BSD pf enable 시킴.
sudo pfctl -e
