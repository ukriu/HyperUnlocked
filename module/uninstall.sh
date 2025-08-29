#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
. ./utils.sh

set_variables
restore_deviceLevelList
rm -r /data/adb/HyperUnlocked/xml
settings put secure background_blur_enable 0
exit 0

# EOF