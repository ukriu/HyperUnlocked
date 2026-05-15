#!/bin/sh
# Copyright (C) 2025-2026 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
. ./utils.sh

check_supported
bypass_hyperos_restrict true
disable_incompatible_modules
blur_choice
highend_choice

# only add island props if already enabled
case "$(getprop persist.sys.feature.island)" in
    ""|0|false)
        CHOICE_ISLAND=false
        ;;
    *)
        CHOICE_ISLAND=true
        ;;
esac

define_props
ssblur_choice
qs_choice
xml_init
update_desc
warning
credits

echo
echo "[!!] A reboot is required for some changes."
echo
sleep 1 # let the masses read
exit 0

# EOF