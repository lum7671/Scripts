#!/usr/bin/env zsh

ID=lum7671@me.com
PW=RqUkUJC8vq
HOSTS=("oh.mypi.co" "for.64-b.it")
LOG=/tmp/update_dns.log

(
    for h in "${HOSTS[@]}"
    do
        echo -e "DNS Update : $h"
        curl -u $ID:$PW "https://now-dns.com/update?hostname=$h"
        echo -e "\n=============================="
    done
) >> $LOG 2>&1
