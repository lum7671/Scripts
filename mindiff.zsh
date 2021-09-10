#!/usr/bin/env zsh

PRJ_ROOT=$HOME/Util/minutes_diff/
cd $PRJ_ROOT
pdm run python minutes_diff.py $1
