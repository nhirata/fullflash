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

function flash_gecko() {
    root_remount
    run_adb shell stop b2g
    echo + Check how much space is taken
    run_adb shell df /system
    echo + removing old system
    run_adb shell rm -r /system/b2g
    echo + Check how much is removed afterwards
    adb shell df /system
    run_adb push b2g /system/b2g
    echo + Check how much is placed on after system install
    adb shell df /system
}

flash_gecko
