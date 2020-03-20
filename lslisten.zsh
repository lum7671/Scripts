#!/usr/bin/env zsh
#

# lsof -PiTCP -sTCP:LISTEN
# netstat -ap tcp | grep -i "listen"


lsof -i TCP -n -P -sTCP:LISTEN
