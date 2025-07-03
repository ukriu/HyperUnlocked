#!/bin/sh
if ! $BOOTMODE; then
    ui_print "*********************************************************"
    ui_print "Installing from recovery is not recommended!"
    ui_print "The installation will continue, but it is recommened to click the action button in the manager to finish the setup!"
    ui_print "*********************************************************"
fi

. $MODPATH/utils.sh

set_variables
MODDIR=$MODPATH
initalise
check_supported
for file in "$MODPATH/system/product/etc/device_features/"*.xml; do
    filename=$(basename "$file")
    if [ "$filename" != "$DEVICE_CODENAME.xml" ]; then
        rm -f "$file"
    fi
done
disable_incompatible_modules
save_deviceLevelList
blur_choice
highend_choice
XML_DIR=$MODPATH/product/etc/device_features/
update_desc
warning
credits

# EOF