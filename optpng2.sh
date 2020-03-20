#!/usr/bin/env sh

find /var/www/ -type f -name '*.[pP][nN][gG]' -print0 | xargs -L 1 -n 1 -P 8 -0 optipng -preserve -quiet -o7 -f4 -strip all
