#!/usr/bin/env zsh
rm -rf $(find pickat_v2/ImagesForV3.xcassets -type d | egrep -v "nateonmac001.imageset$")
