#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# 작성자 : 장두현 <ring0320@sk.com>
# 버  전 : 1.0
# 작성일 : 2012-03-08
# 수정일 : 
#
# * 맥 GUI용 : ImageOptim ( http://imageoptim.com/ )
#
# 사용법 :
#  ./RunImageOptim.sh [directory]
#  - 디렉토리를 지정하면 해당 디렉토리 이하(Recursive) 모든 png 를 변환한다.
#  - 디렉토리를 지정하지 않으면 현재 디렉토리 이하 모든 png 를 변환한다.
#
# 참고 : https://github.com/scribd/Xcode-OptimizePNG
#


usage ()
{
    echo -e "Usage :\n$0 [directory]"
    exit 0
}


cust_echo() 
{
    echo "[1;34m$1 [1;32m$2[0;0m"
}

if [ $# -gt 1 ];then
    usage
fi

APP_IMAGEOPTIM="/Applications/ImageOptim.app"

if [ ! -d "$APP_IMAGEOPTIM" ];then
    echo "에러! ImageOptim.app 이 /Applications 디렉토리에 없습니다."
    exit 0
fi

process_png()
{
    cd $1
    open -a ImageOptim.app *.png
}

DIR_PWD=$(pwd)

for directory in $(find $DIR_PWD -type d -print)
do
    process_png $directory
done
