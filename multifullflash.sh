#!/bin/bash

List=`fastboot devices | grep -v "List" | awk '{print $1}'`
for DEVICE in ${List}
do 
  echo "flashing ${DEVICE}"
  ./b2g-distro/flash.sh -s ${DEVICE} 
done
