#!/usr/bin/env bash
# https://gist.github.com/atais/9c72e469b1cbec35c7c430ce03de2a6b

(set -x; brew update;)

(set -x; brew cleanup;)

# Error: Calling `brew cask cleanup` is disabled! Use `brew cleanup` instead.
#(set -x; brew cask cleanup;)

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

casks=( $(brew cask list) )

for cask in ${casks[@]}
do
    version=$(brew cask info $cask | sed -n "s/$cask:\ \(.*\)/\1/p")
    installed=$(find "/usr/local/Caskroom/$cask" -type d -maxdepth 1 -maxdepth 1 -name "$version")

    if [[ -z $installed ]]; then
        echo "${red}${cask}${reset} requires ${red}update${reset}."
        (set -x; brew cask uninstall $cask --force;)
        (set -x; brew cask install $cask --force;)
    else
        echo "${red}${cask}${reset} is ${green}up-to-date${reset}."
    fi
done
