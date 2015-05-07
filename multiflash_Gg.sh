#!/bin/bash

List=`adb devices | grep -v "List" | awk '{print $1}'`
for DEVICE in ${List}
do 
  echo "flashing ${DEVICE}"
  ./flash_Gg.sh -s ${DEVICE} 
done
