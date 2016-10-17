#!/usr/bin/env sh
/usr/bin/rsync -az 192.168.0.14::aosp /Volumes/PDS/android
sync
sleep 30
cd /Volumes/PDS/android
./mkgtag.sh
sync
sleep 30
