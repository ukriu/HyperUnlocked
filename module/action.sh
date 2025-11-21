#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
. ./utils.sh

check_supported
disable_incompatible_modules
blur_choice
highend_choice
define_props
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