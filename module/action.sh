#!/bin/sh
. ./utils.sh

set_variables
check_supported
disable_incompatible_modules
swichDeviceLevel
update_desc
credits
exit 0

# EOF