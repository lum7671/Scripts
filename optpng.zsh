#!/usr/bin/env zsh

CNT=1
TARGET_PATH=.

if [[ ! -z $1 ]]; then
      CNT=$1
fi 

echo "BEFORE :"
du -sh $TARGET_PATH
echo "-------------------------------"
for i in {1..$CNT}
do     
    pngquant -f -s1 -Q 70-95 --ext .png -- $TARGET_PATH/**/*.png
    du -sh $TARGET_PATH
done
echo "AFTER :"
du -sh $TARGET_PATH
echo "-------------------------------"
