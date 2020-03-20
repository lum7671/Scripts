#!/usr/bin/env zsh
free

TOTAL=`free | grep ^Mem | awk '{print $2}'`
USED1=`free | grep ^Mem | awk '{print $3}'`
USED2=`free | grep ^-/+ | awk '{print $3}'`
NOMINAL=`echo "100*$USED1/$TOTAL" | bc -l`
ACTUAL=`echo "100*$USED2/$TOTAL" | bc -l`
echo NOMINAL=${NOMINAL:0:5}% ACTUAL=${ACTUAL:0:5}%
