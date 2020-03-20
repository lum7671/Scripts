#!/usr/bin/env zsh
#
# du -ahx . | sort -rh | head -20
#

du -d 1 -h $1 | egrep "^([0-9]|\.|\ )+[M|G]" | gsort -h
