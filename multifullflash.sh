#!/bin/bash

List=`fastboot devices | grep -v "List" | awk '{print $1}'`
for DEVICE in ${List}
do 
  echo "flashing ${DEVICE}"
  ./flash.sh -s ${DEVICE} 
done

