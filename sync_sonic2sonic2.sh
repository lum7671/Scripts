#!/usr/bin/env bash
# -*- coding: euc-kr -*-
#
# sonic �� sonic2 ��ũ ��Ű�� ��ũ��Ʈ.
#
# author      : ����� <ring0320@skcomms.co.kr>
# create date : 2011-03-16
#
# ����� rsync option
# -v, --verbose               increase verbosity
# -a, --archive               archive mode; equals -rlptgoD (no -H,-A,-X)
# -u, --update                skip files that are newer on the receiver
# -C, --cvs-exclude           auto-ignore files the same way CVS does
# -P                          same as --partial --progress

# rsync -vauCP --exclude="masterd.properties" --exclude="logs/*" --exclude="layout.xml" --exclude="err.out" --exclude="sdb/*" sonic/* sonic2/

# ���� �� filter ���Ϸ� �ٲ�.
rsync -vauCP --exclude-from=./filter sonic/* sonic2/

