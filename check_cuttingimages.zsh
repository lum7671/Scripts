#!/usr/bin/env zsh

fn() {
    pngs01=( ${(f)"$(find pickat_v2/ImagesForV3.xcassets -type f -name '*.png')"} )
    pngs02=( ${(f)"$(find ~/Dropbox/\#\#_02_Syrup\ Table/\#\#_Syrup\ Table\ 3.0_201506/\#\#_배포용GUID_JPG/\#\#_IOS/@@_png@2x -type f -name '*.png')"} )

    count=0
    for png02 in $pngs02; do
        count=$(expr $count + 1)
        if [[ $1 != 'summary' ]]; then
            print "Finding file : ${png02:t}"
        fi
        
        foundFile=''
        for png01 in $pngs01; do
            if [[ ${png02:t} = ${png01:t} ]]; then
                if [[ $1 != 'summary' ]]; then
                    print ">>> File Found!!! : ${png01}"
                fi
                
                foundFile=$png01
                diff -q $png02 $png01
                break
            fi
        done
        if [[ $foundFile = '' ]]; then
            print ">>> File  * Not *  Found : ${png01}"
        fi
    done

    print "TOTAL FILE COUNT : $count"
}

fn $@
