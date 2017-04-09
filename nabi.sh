#!/usr/bin/env sh

export LANG=ko_KR.UTF-8
export LANGUAGE=ko:en
export LC_NUMERIC=ko_KR.UTF-8
export LC_TIME=ko_KR.UTF-8
export LC_MONETARY=ko_KR.UTF-8
export LC_PAPER=ko_KR.UTF-8
export LC_IDENTIFICATION=ko_KR.UTF-8
export LC_NAME=ko_KR.UTF-8
export LC_ADDRESS=ko_KR.UTF-8
export LC_TELEPHONE=ko_KR.UTF-8
export LC_MEASUREMENT=ko_KR.UTF-8

export XMODIFIERS="@im=nabi"
export GTK_IM_MODULE="nabi"
export QT_IM_MODULE="nabi"

nabi -wm -wait &
