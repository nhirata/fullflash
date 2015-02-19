function run_adb()
{
    # TODO: Bug 875534 - Unable to direct ADB forward command to inari devices due to colon (:) in serial ID
    # If there is colon in serial number, this script will have some warning message.
    adb ${ADB_FLAGS} $@
}

function root_remount()
{
    run_adb root
    run_adb wait-for-device
    run_adb remount
    run_adb wait-for-device
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
    cat gaia/profile/user.js | sed -e "s/user_pref/pref/" > user.js
    
    echo "Push Gaia ..."
    run_adb shell mkdir -p /system/b2g/defaults/pref
    run_adb push gaia/profile/webapps ${GAIA_DIR}/webapps
    run_adb push user.js /system/b2g/defaults/pref
    
   if [ ${Debug_Flag} ] ; then 
       if grep -q "Version=28.0" "b2g/application.ini" ; then
          echo 'Turning on Debug for v1.3'
          cat gaia/profile/settings.json | sed -e "s/devtools.debugger.remote-enabled\":false/devtools.debugger.remote-enabled\":true/" > settings.json
          run_adb push settings.json /system/b2g/defaults
          rm settings.json
       else
          echo 'Turning on Debug for v1.4+'
          cat gaia/profile/settings.json | sed -e "s/developer.menu.enabled\":false/developer.menu.enabled\":true/" > gaia/settings.json
          cat gaia/settings.json | sed -e "s/debugger.remote-mode\":\"disabled\"/debugger.remote-mode\":\"adb-only\"/" > settings.json
          run_adb push settings.json /system/b2g/defaults
          rm settings.json
          rm gaia/settings.json
       fi
    else
       run_adb push gaia/profile/settings.json /system/b2g/defaults
    fi

    if [ ! ${forcetosystem} ] ; then
    	run_adb remount
    	run_adb shell mkdir /system/b2g/webapps
    	run_adb push gaia/profile/webapps/webapps.json /system/b2g/webapps/webapps.json
    fi

    echo "Push Done."
    adb shell df /data
}

function resetphone()
{
run_adb shell rm -r /cache/* &&
run_adb shell mkdir /cache/recovery > /dev/null &&
run_adb shell 'echo "--wipe_data" > /cache/recovery/command' &&
run_adb reboot recovery
}


adb_clean_gaia
Install_Directory="/system/b2g"
echo "Installing to directory : ${Install_Directory}"
adb_push_gaia ${Install_Directory}
sleep 10
resetphone

