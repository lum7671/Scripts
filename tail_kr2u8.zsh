#!/usr/bin/env zsh

tail $* | iconv -f euc-kr -t utf-8
