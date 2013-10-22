#!/usr/bin/env bash
echo "[1;32mPreparing...[0;0m"
rm -rvf cscope.files cscope.out
echo "[1;32mGathering files in [1;34mARM_Application[0;0m"
find ARM_Application -type f \( -name "*.[c|h]" -o -name "*.[c|h]pp" -o -name "*.java" \) -print | grep -v "obfuscated" > cscope.files
echo "[1;32mGathering files in [1;34mARM_Service[0;0m"
find ARM_Service/ -type f \( -name "*.[c|h]" -o -name "*.[c|h]pp" -o -name "*.java" \) -print | grep -v "obfuscated" >> cscope.files
echo "[1;32mRun cscope batch...[0;0m"
cscope -b
echo "[1;32mDone[0;0m"

