#!/usr/bin/env zsh
adb shell screencap -p /mnt/sdcard/sc.png
adb pull /mnt/sdcard/sc.png
