NOTE:
I don't really work on this much now that we have the TW-QA flashing tool:
https://github.com/Mozilla-TWQA/B2G-flash-tool

I might work on turning on dev options as features for shallow flashing...

fullflash
=========
To use: 
copy the script with into the same folder as a b2g and gaia folders are located then run the script: flash_Gg.sh

If you have multiple devices to flash use : multiflash.sh

The following are options :
+ -d : to turn on ril debugging
+ -n : to not install comril
+ -h : for help
+ -i <device name> : image flash the device ex: -i inari
+ -s <serial device> : flash to specific device serial
+ -b : backup before flashing
+ -r : restore after flashing
+ -k : keep previous profile; backup and restore options
+ -p : do not reset phone
+ -a : do not turn on adb remote debugging"


multifullflash
=============
place this file in the b2g-distro folder of the build that you are flashing.
make sure that it has executable rights ( chmod +x multifullflash )
place devices in fastboot mode ( turn off, hold volume up, plug in, should see blue light for aries )
once you have all the devices in fastboot mode, run the script ./multifullflash
 
