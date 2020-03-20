#!/usr/bin/env zsh

SAVE_DIR=$HOME/Downloads

if [ $# -eq 3 ]; then
    SAVE_DIR=$3
fi

echo $SAVE_DIR
ffmpeg -version
ffmpeg -stats -loglevel quiet -i "$1" -acodec copy -vcodec copy "$SAVE_DIR/$2.mp4"
# ffmpeg -stats -loglevel verbose -i "$1" -acodec copy -vcodec copy "$SAVE_DIR/$2.mp4"
