#!/bin/sh
MODDIR=$MODPATH
if ! $BOOTMODE; then
    ui_print "*********************************************************"
    ui_print "Installing from recovery is not recommended!"
    ui_print "The installation will continue, but it is recommened to click the action button in the manager to finish the setup!"
    ui_print "*********************************************************"
fi

. $MODPATH/utils.sh

set_variables
initalise
check_supported
if [ -n "$supported" ]; then
    xml_patch $DEVICE_CODENAME $DEVICE_CODENAME
elif [ -n "$partial" ]; then
    xml_patch generic $DEVICE_CODENAME
fi
disable_incompatible_modules
save_deviceLevelList
blur_choice
highend_choice
update_desc
warning
credits
cleanup
# EOF