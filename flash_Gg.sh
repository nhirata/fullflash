#!/bin/bash -e
#
# ====================================================
# credit : 
# - mwu ( for original flash script Gecko/Gaia )
# - askeing
# - nhirata
# - JohanLorenzo   

Shallow_Flag=1
Backup_Flag=""
Recover_Flag=""
Reset_Flag=1
rildebug=""
nocomril=""
keepdata=""
installedonsystem=""
specificdevice=""
Debug_Flag=1
Install_Directory="/system/b2g"

FASTBOOT=${FASTBOOT:-fastboot}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function helper(){
    echo -e "
    -d : to turn on ril debugging
    -n : to not install comril
    -h : for help
    -i <device name> : image flash the device ex: -i inari
    -s <serial device> : flash to specific device serial
    -b : backup before flashing
    -r : restore after flashing
    -k : keep previous profile; backup and restore options
    -p : do not reset phone"
}

function backupdevice(){
    if [ ! -d "mozilla-profile" ]; then
        echo "no backup folder, creating..."
        mkdir mozilla-profile
    fi
    echo -e "Backup your profiles..."
    run_adb shell stop b2g 2> "$SCRIPT_DIR/mozilla-profile/backup.log"
    rm -rf "$SCRIPT_DIR/mozilla-profile/*"
    mkdir -p "$SCRIPT_DIR/mozilla-profile/profile"
    run_adb pull /data/b2g/mozilla "$SCRIPT_DIR/mozilla-profile/profile" 2> "$SCRIPT_DIR/mozilla-profile/backup.log"
    mkdir -p "$SCRIPT_DIR/mozilla-profile/data-local"
    run_adb pull /data/local "$SCRIPT_DIR/mozilla-profile/data-local" 2> "$SCRIPT_DIR/mozilla-profile/backup.log"
    rm -rf "$SCRIPT_DIR/mozilla-profile/data-local/webapps"
    run_adb shell start b2g 2> "$SCRIPT_DIR/mozilla-profile/backup.log"
    echo -e "Backup done."
}

function restoredevice(){
    echo -e "Recover your profiles..."
    if [ ! -d mozilla-profile/profile ] || [ ! -d mozilla-profile/data-local ]; then
        echo "no recover files."
        exit -1
    fi
    run_adb shell stop b2g 2> "$SCRIPT_DIR/mozilla-profile/recover.log"
    run_adb shell rm -r /data/b2g/mozilla 2> "$SCRIPT_DIR/mozilla-profile/recover.log"
    run_adb push "$SCRIPT_DIR/mozilla-profile/profile" /data/b2g/mozilla 2> "$SCRIPT_DIR/mozilla-profile/recover.log"
    run_adb push "$SCRIPT_DIR/mozilla-profile/data-local" /data/local 2> "$SCRIPT_DIR/mozilla-profile/recover.log"
    run_adb reboot
    sleep 30
    echo -e "Recover done."
}

function run_adb()
{
    # TODO: Bug 875534 - Unable to direct ADB forward command to inari devices due to colon (:) in serial ID
    # If there is colon in serial number, this script will have some warning message.
    adb ${ADB_FLAGS} "$@"
}

function run_fastboot()
{
    if [ "$1" = "devices" ]; then
        ${FASTBOOT} "$@"
    else
        ${FASTBOOT} ${FASTBOOT_FLAGS} "$@"
    fi
    return $?
}

function root_remount()
{
    run_adb root
    run_adb wait-for-device
    run_adb remount
    run_adb wait-for-device
}

function flash_gecko() {
    root_remount
    echo + Check how much space is taken
    run_adb shell df /system
    echo + removing old system
    run_adb shell rm -r /system/b2g
    echo + Check how much is removed afterwards
    adb shell df /system
    run_adb push "$SCRIPT_DIR/b2g" /system/b2g
    echo + Check how much is placed on after system install
    adb shell df /system
}

function flash_comril() {
    root_remount
    echo + Installing new RIL
    run_adb push "$SCRIPT_DIR/ril" /system/b2g/distribution/bundles/
    echo + Done installing RIL!
}

function adb_clean_gaia() {
    root_remount
    
    adb shell df /data
    echo "Clean Gaia and profiles ..."
    echo + Deleting any old cache
    run_adb shell rm -r /data/local/OfflineCache
    run_adb shell rm -r /cache/*

    echo + Deleting Profile data
    run_adb shell rm -r /data/b2g/*
    run_adb shell rm -r /data/local/user.js
    run_adb shell rm -r /data/local/indexedDB
    run_adb shell rm -r /data/local/debug_info_trigger
    run_adb shell rm -r /data/local/permissions.sqlite*

    adb shell df /data
    run_adb reboot
    run_adb wait-for-device
    root_remount
    
    run_adb shell stop b2g
    run_adb shell rm -r /data/local/storage/persistent/*
    echo + Deleting any old gaia
    run_adb shell rm -r /system/b2g/webapps
    run_adb shell rm -r /data/local/webapps
    run_adb shell rm -r /data/local/svoperapps
    echo "Clean Done."
    adb shell df /data
}

function adb_push_gaia() {
    GAIA_DIR=$1
    
    ## Adjusting user.js
    cat "$SCRIPT_DIR/gaia/profile/user.js" | sed -e "s/user_pref/pref/" > "$SCRIPT_DIR/user.js"
    
    echo "Push Gaia ..."
    run_adb shell mkdir -p /system/b2g/defaults/pref
    run_adb push "$SCRIPT_DIR/gaia/profile/webapps" ${GAIA_DIR}/webapps
    run_adb push "$SCRIPT_DIR/user.js" /system/b2g/defaults/pref
    run_adb push "$SCRIPT_DIR/gaia/profile/settings.json" /system/b2g/defaults

    if [ ! ${forcetosystem} ] ; then
    	run_adb remount
    	run_adb shell mkdir /system/b2g/webapps
        run_adb push "$SCRIPT_DIR/gaia/profile/webapps/webapps.json" /system/b2g/webapps/webapps.json
    fi

    echo "Push Done."
    adb shell df /data
}

function resetphone()
{
run_adb shell mkdir /cache/recovery &&
run_adb shell 'echo "--wipe_data" > /cache/recovery/command' &&
run_adb reboot recovery
}

function shallowflash()
{

if [ ! ${nocomril} ] ; then
  if ! [ -f "ril" ]; then
        echo "Cannot found ril folder.  Skipping ril"
        echo + COM RIL not installed
  else 
  flash_comril
  fi
else
  echo + COM RIL not installed
fi

if [ ! ${rildebug} ] ; then
  echo + Ril Debug pref turned on
  cat "$SCRIPT_DIR/gaia/profile/user.js" | sed -e "s/user_pref/pref/" > "$SCRIPT_DIR/gaia/user.js"
  cat "$SCRIPT_DIR/gaia/user.js" | sed -e "s/ril.debugging.enabled\", false/ril.debugging.enabled\", true/" > "$SCRIPT_DIR/user.js"
else
  if [ ${keepdata} ] ; then
    echo + RIL debug pref not turned on
    cat "$SCRIPT_DIR/gaia/profile/user.js" | sed -e "s/user_pref/pref/" > "$SCRIPT_DIR/user.js"
  else 
    echo + user.js pref not touched
  fi
fi

flash_gecko
adb_clean_gaia

echo "Installing to directory : ${Install_Directory}"
adb_push_gaia ${Install_Directory}
}

function fastboot_flash_image()
{
    # $1 = {userdata,boot,system}
    imgpath="out/target/product/$DEVICE/$1.img"
    out="$(run_fastboot flash "$1" "$imgpath" 2>&1)"
    rv="$?"
    echo "$out"

    if [[ "$rv" != "0" ]]; then
        # Print a nice error message if we understand what went wrong.
        if grep -q "too large" <(echo "$out"); then
            echo ""
            echo "Flashing $imgpath failed because the image was too large."
            echo "Try re-flashing after running"
            echo "  \$ rm -rf $(dirname "$imgpath")/data && $SCRIPT_DIR/build.sh"
        fi
        return ${rv}
    fi
}

function flash_fastboot()
{
    run_adb reboot bootloader &&
    run_fastboot devices &&
    run_fastboot erase cache &&
    fastboot_flash_image userdata &&
    ([ ! -e out/target/product/$DEVICE/boot.img ] || fastboot_flash_image boot) &&
    fastboot_flash_image system &&
    run_fastboot reboot
}

update_time()
{
    if [ `uname` = Darwin ]; then
        OFFSET=`date +%z`
        OFFSET=${OFFSET:0:3}
        TIMEZONE=`date +%Z$OFFSET|tr +- -+`
    else
        TIMEZONE=`date +%Z%:::z|tr +- -+`
    fi
    echo Attempting to set the time on the device
    run_adb wait-for-device
    run_adb shell toolbox date `date +%s`
    run_adb shell setprop persist.sys.timezone ${TIMEZONE}
}

## Main
## Switch
while getopts :apbdsfkirnh opt; do
  case $opt in
    b) Backup_Flag=1; 
    ;;
    d)
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
      esac
      specificdevice=$2
    ;;
    f) 
    echo "Force install to data partition"
    forcetosystem=""
    Install_Directory="/data/local"
    Reset_Flag=""
    ;;
    h|help) helper;
    exit 0
    ;;
    r)
    Recover_Flag=1
    ;;
    k)
    echo "keep previous Profile"
    Backup_Flag=1
    Recover_Flag=1
    ;;
    i) 
      Shallow_Flag=""
      case "$2" in
        "") shift 2;;
        *) DEVICE=$2
      esac
    ;;
    p)
    Reset_Flag=""
    ;;
    *)
    ;;
  esac
done

if [ `run_adb get-state` = "unknown" ]; then
    echo "Cannot adb access the device.  Please allow for adb access to the device."
    exit 1
fi

#Backup
if [ ${Backup_Flag} ]; then
    backupdevice
fi

if [ ${Shallow_Flag} ]; then
    echo "Shallowflag = $Shallow_Flag"
    shallowflash
else
    flash_fastboot
fi

# giving a pause before the phone reset to see if that helps
sleep 10;

if [ ${Reset_Flag} ]; then
  DEVICE=`adb shell getprop ro.product.model`
  DEVICE=`echo ${DEVICE}|tr -ds '\r\n' %1`
  if [ "${DEVICE}" != "sp6821a" ]; then
    echo "Reseting the phone"
    resetphone
  else
    echo "Did not reset the phone"
  fi
fi

#Restore
if [ ${Recover_Flag} ]; then
    restoredevice
fi

update_time

echo + Rebooting
run_adb shell sync
run_adb shell reboot

echo + Done: Completed flashing the device
