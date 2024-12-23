#!/usr/bin/env zsh

PRJ_ROOT=$HOME/git/minutes_diff/
cd $PRJ_ROOT
pdm run python src/minutes_diff/minutes_diff.py $1
