#!/usr/bin/env zsh

MYID=$(whoami)
echo "I am '$MYID'"
sudo chown -R $MYID $HOME
