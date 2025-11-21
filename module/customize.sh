#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
if ! $BOOTMODE; then
    ui_print "*********************************************************"
    ui_print "Installing from recovery is not recommended!"
    ui_print "The installation will continue, but it is recommened to click the action button in the manager to finish the setup!"
    ui_print "*********************************************************"
fi

export MODPATH
. $MODPATH/utils.sh

check_supported
disable_incompatible_modules
save_deviceLevelList
blur_choice
highend_choice
define_props
qs_tiles
xml_init
update_desc
warning
credits

# EOF