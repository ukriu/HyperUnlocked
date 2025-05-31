#!/bin/sh
if ! $BOOTMODE; then
    ui_print "*********************************************************"
    ui_print "Installing from recovery is not supported!"
    ui_print "Please install from the Magisk / KernelSU / APatch app!"
    abort    "*********************************************************"
fi

. $MODPATH/utils.sh

set_variables
check_supported
disable_incompatible_modules
save_deviceLevelList
set_highend
warning
credits

# EOF