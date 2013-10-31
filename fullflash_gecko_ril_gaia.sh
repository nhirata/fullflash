#!/bin/bash

rildebug=0
nocomril=0
keepdata=0
forcetosystem=0
installedonsystem=0

while getopts :rnh opt; do
  case $opt in
    r)
    echo "Turning on RIL Debugging"
    rildebug=1
    ;;
    n)
    echo "Not installing Commercial Ril, should be using mozril"
    nocomril=1
    ;;
    s) 
    echo "Force install to system"
    forcetosystem=1 
    ;;
    h) 
    echo "
    -k : keep previous profile
    -r : to turn on ril debugging
    -n : to not install comril
    -s : force install to system partition
    -h : for help
    "
    exit
    ;;
    k)
    echo "keep previous Profile"
    keepdata=1
    ;;
    *)
    ;;
  esac
done

echo + gaining root access &&
adb root &&

echo + Waiting for adb to come back up &&
adb wait-for-device &&

echo + remounting the system partition &&
adb remount &&
adb shell mount -o remount,rw /system &&

echo + Waiting for adb to come back up &&
adb wait-for-device &&

echo + Stopping b2g &&
adb shell stop b2g &&

echo + Check how much space is taken &&
adb shell df /system &&

echo + removing old system &&
adb shell rm -r /system/b2g &&

echo + Check how much is removed afterwards &&
adb shell df /system &&

echo + Installing new b2g &&
adb push b2g /system/b2g &&

echo + Done installing Gecko! &&

if [ ! $nocomril ] ; then
  echo + Installing new RIL &&
  adb push ril /system/b2g/distribution/bundles/
  echo + Done installing RIL!
else
  echo + COM RIL not installed
fi

if [ ! $rildebug ] ; then
  echo + Ril Debug pref turned on
  cat gaia/profile/user.js | sed -e "s/user_pref/pref/" > gaia/user.js 
  cat gaia/user.js | sed -e "s/ril.debugging.enabled\", false/ril.debugging.enabled\", true/" > user.js
else
  if [ $keepdata ] ; then
    echo + RIL debug pref not turned on
    cat gaia/profile/user.js | sed -e "s/user_pref/pref/" > user.js 
  else 
    echo + user.js pref not touched
  fi
fi

if adb shell cat /data/local/webapps/webapps.json | grep -m 1 '"basePath": "/system' ; then
  installedonsystem=1
else
  installedonsystem=0
fi

echo "installedonsystem = ${installedonsystem}" &&

echo + Deleting any old gaia and cache &&
adb shell rm -r /cache/* &&
adb shell rm -r /data/local/webapps &&
adb shell rm -r /data/local/svoperapps &&
adb shell rm -r /data/local/OfflineCache &&
adb shell rm -r /system/b2g/webapps &&

if [ $keepdata ] ; then
  echo + Deleting Profile data &&
  adb shell rm -r /data/b2g/* &&
  adb shell rm -r /data/local/storage/persistent/*
  adb shell rm -r /data/local/user.js &&
  adb shell rm -r /data/local/permissions.sqlite* &&
  adb shell rm -r /data/local/indexedDB &&
  adb shell rm -r /data/local/debug_info_trigger
else
  echo + keeping data profile
fi

echo + Installing new gaia webapps &&
if [ $forcetosystem -o $installedonsystem ] ; then
  echo + installing to system
  echo "force to system : $forcetosystem ; installed onsystem : $installedonsystem"
  adb shell mkdir -p /system/b2g/defaults/pref &&
  adb push gaia/profile/webapps /system/b2g/webapps
  adb push user.js /system/b2g/defaults/pref &&
  adb push gaia/profile/settings.json /system/b2g/defaults
else
  echo + installing to data/local
  echo "force to system : $forcetosystem ; installed onsystem : $installedonsyste
m"
  adb shell mkdir -p /system/b2g/defaults/pref &&
  adb push user.js /system/b2g/defaults/pref &&
  adb push gaia/profile/webapps /data/local/webapps
  adb push gaia/profile/settings.json /system/b2g/defaults 
fi
echo + Rebooting &&
adb shell sync &&
adb shell reboot &&

echo + Done


