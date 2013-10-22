#!/usr/bin/env bash
# -*- coding: euc-kr -*-
#
# sonic 과 sonic2 싱크 시키는 스크립트.
#
# author      : 장두현 <ring0320@skcomms.co.kr>
# create date : 2011-03-16
#
# 사용한 rsync option
# -v, --verbose               increase verbosity
# -a, --archive               archive mode; equals -rlptgoD (no -H,-A,-X)
# -u, --update                skip files that are newer on the receiver
# -C, --cvs-exclude           auto-ignore files the same way CVS does
# -P                          same as --partial --progress

# rsync -vauCP --exclude="masterd.properties" --exclude="logs/*" --exclude="layout.xml" --exclude="err.out" --exclude="sdb/*" sonic/* sonic2/

# 줄이 길어서 filter 파일로 바꿈.
rsync -vauCP --exclude-from=./filter sonic/* sonic2/

