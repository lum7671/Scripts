#!/usr/bin/env zsh

du -d 1 -h | egrep "^([0-9]\.\ )+[GM]" | gsort -h