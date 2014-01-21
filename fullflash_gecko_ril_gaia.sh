#!/bin/bash
Shallow_Flag=1
Backup_Flag=0
Recover_Flag=0
rildebug=0
nocomril=0
keepdata=0
forcetosystem=0
installedonsystem=0
specificdevice=0

function helper(){
    echo -e "
    -r : to turn on ril debugging
    -n : to not install comril
    -f : force install to system partition
    -h : for help
    -i : image flash
    -s : flash to specific device serial
    -b : backup only
    -r : restore only
    -k : keep previous profile; backup and restore
    "
    exit 0
}

function backup(){
    if [ ! -d mozilla-profile ]; then
        echo "no backup folder, creating..."
        mkdir mozilla-profile
    fi
    echo -e "Backup your profiles..."
    adb shell stop b2g 2> ./mozilla-profile/backup.log &&\
    rm -rf ./mozilla-profile/* &&\
    mkdir -p mozilla-profile/profile &&\
    adb pull /data/b2g/mozilla ./mozilla-profile/profile 2> ./mozilla-profile/backup.log &&\
    mkdir -p mozilla-profile/data-local &&\
    adb pull /data/local ./mozilla-profile/data-local 2> ./mozilla-profile/backup.log &&\
    rm -rf mozilla-profile/data-local/webapps
    adb shell start b2g 2> ./mozilla-profile/backup.log
    echo -e "Backup done."
    exit 0
}

function restore(){
    echo -e "Recover your profiles..."
    if [ ! -d mozilla-profile/profile ] || [ ! -d mozilla-profile/data-local ]; then
        echo "no recover files."
        exit -1
    fi
    adb shell stop b2g 2> ./mozilla-profile/recover.log &&\
    adb shell rm -r /data/b2g/mozilla 2> ./mozilla-profile/recover.log &&\
    adb push ./mozilla-profile/profile /data/b2g/mozilla 2> ./mozilla-profile/recover.log &&\
    adb push ./mozilla-profile/data-local /data/local 2> ./mozilla-profile/recover.log &&\
    adb reboot
    sleep 30
    echo -e "Recover done."
    exit 0
}

function run_adb()
{
    # TODO: Bug 875534 - Unable to direct ADB forward command to inari devices due to colon (:) in serial ID
    # If there is colon in serial number, this script will have some warning message.
	adb $ADB_FLAGS $@
}

function flash_gecko() {
    run_adb root
    run_adb wait-for-device &&
    run_adb remount
    run_adb wait-for-device &&
    echo + Check how much space is taken &&
    run_adb shell df /system &&
    echo + removing old system &&
    run_adb shell rm -r /system/b2g &&
    echo + Check how much is removed afterwards &&
    adb shell df /system &&
    run_adb push b2g /system/b2g &&
    echo + Check how much is placed on after system install&&
    adb shell df /system &&
}
function flash_comril() {
  echo + Installing new RIL &&
  run_adb push ril /system/b2g/distribution/bundles/
  echo + Done installing RIL!
}

function adb_clean_gaia() {
    echo "Clean Gaia and profiles ..."
    echo + Deleting Profile data &&
    run_adb shell rm -r /data/b2g/* &&
    run_adb shell rm -r /data/local/user.js &&
    run_adb shell rm -r /data/local/indexedDB &&
    run_adb shell rm -r /data/local/debug_info_trigger &&
    run_adb shell rm -r /data/local/storage/persistent/* &&
    run_adb shell rm -r /data/local/permissions.sqlite* &&
    echo + Deleting any old gaia and cache &&
    run_adb shell rm -r /system/b2g/webapps &&
    run_adb shell rm -r /data/local/webapps &&
    run_adb shell rm -r /data/local/svoperapps &&
    run_adb shell rm -r /data/local/OfflineCache &&
    run_adb shell rm -r /cache/* &&
    echo "Clean Done."
}

function adb_push_gaia() {
    GAIA_DIR=$1
    
    ## Adjusting user.js
    cat gaia/profile/user.js | sed -e "s/user_pref/pref/" > user.js
    
    echo "Push Gaia ..."
    run_adb shell mkdir -p $GAIA_DIR/system/b2g/defaults/pref &&
    run_adb push gaia/profile/webapps $GAIA_DIR/webapps &&
    run_adb push user.js $GAIA_DIR/defaults/pref &&
    run_adb push gaia/profile/settings.json $GAIA_DIR/defaults &&
    echo "Push Done."
}

function flash_gaia() {
    adb_clean_gaia &&
    adb_push_gaia
}

## Switches
while getopts :rnh opt; do
  case $opt in
    b) Backup_Flag=1; 
    r)
    echo "Turning on RIL Debugging"
    rildebug=1
    ;;
    n)
    echo "Not installing Commercial Ril, should be using mozril"
    nocomril=1
    ;;
    s)
      case "$2" in
        "") shift 2;;
        *) ADB_DEVICE=$2; ADB_FLAGS+="-s $2"; shift 2;;
      esac ;;
      specificdevice=$2
    f) 
    echo "Force install to system"
    forcetosystem=1 
    ;;
    h|help) helper;
    exit 0
    ;;
    k)
    echo "keep previous Profile"
    Backup_Flag=1
    Recover_Flag=1
    ;;
    *)
    ;;
  esac
done

#Backup
if [ $Backup_Flag ]; then
  backup
fi

if [ ! $nocomril ] ; then
  flash_comril
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

echo + Installing new gaia webapps &&
if [ $forcetosystem -o $installedonsystem ] ; then
  echo + installing to system
  $install_directory="/system/b2g"
else
  echo + installing to data/local
    $install_directory="/data/local"
fi

adb_push_gaia $install_directory

#Restore
if [ $RecoverOnly_Flag == true ]; then
  restore
fi

echo + Rebooting &&
adb shell sync &&
adb shell reboot &&

echo + Done


