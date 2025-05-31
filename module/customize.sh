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
if [ "$supported" = "true" ]; then
    for file in "$MODDIR/system/product/etc/device_features/"*.xml; do
        filename=$(basename "$file")
        if [ "$filename" != "$DEVICE_CODENAME.xml" ]; then
            rm -f "$file"
        fi
    done
fi
disable_incompatible_modules
save_deviceLevelList
set_highend
warning
credits

# EOF