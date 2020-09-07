#!/usr/bin/env zsh

head $* | iconv -f euc-kr -t utf-8
