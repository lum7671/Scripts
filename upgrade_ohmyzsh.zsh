#!/usr/bin/env zsh

{
    cd $HOME/.oh-my-zsh
    git checkout -- .
    sh tools/upgrade.sh
}

# {
#     cd $HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting
#     git checkout -- .
#     git pull
# }

#{
#    cd $HOME/.zplugin/bin
#    git checkout -- .
#    git pull
#}
