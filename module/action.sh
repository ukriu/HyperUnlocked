#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
. ./utils.sh

set_variables
check_supported
disable_incompatible_modules
blur_choice
highend_choice
xml_init
update_desc
warning
credits
echo
echo "[!!] A reboot is required for changes to blur."
echo
sleep 3 # let the masses read
exit 0

# EOF