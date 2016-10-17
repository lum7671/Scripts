#!/usr/bin/env bash

if [ ! -e "$1" ]
then
	echo -e "Usage :\n$0 xxx.apk"
	exit 0
fi

cp -vf "$1" "tmp_$1"
rm -vf "$1"
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore ~/.android/pug.keystore -storepass jang01 -keypass jang01 "tmp_$1" pug
zipalign -v 4 "tmp_$1" "$1"
rm -vf "tmp_$1"
