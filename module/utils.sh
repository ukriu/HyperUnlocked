#!/bin/sh
set_variables() {
  RESDIR=/data/adb/HyperUnlocked
  mkdir -p $RESDIR
}

check_supported() {
    DEVICE_CODENAME=$(getprop ro.product.device)
    codenames="gold iron malachite beryl citrine sapphire sapphiren pipa"

    for codename in $codenames; do
        if [ "$DEVICE_CODENAME" = "$codename" ]; then
            supported=true
            echo "- Supported device!"
            return 0
        fi
    done

    echo "- Your device is not fully supported and might lack some features."
}

disable_incompatible_modules() {
    echo "-"
    echo "- Checking for incompatible modules..."
    found_incompatible=false
    
    for dir in /data/adb/modules/*; do
        if [ -d "$dir" ]; then
            module_name=$(basename "$dir")
            [ "$module_name" = "HyperUnlocked" ] && continue
            if [ -f "${dir}/system/product/etc/device_features/${DEVICE_CODENAME}.xml" ]; then
                found_incompatible=true
                echo "- Incompatible module: \`$module_name\`"
                if touch "$dir/disable"; then
                    echo "- Disabled: \`$module_name\`"
                else
                    echo "- Failed to disable \`$module_name\`"
                    echo "- Please uninstall the module to prevent issues."
                    sleep 0.3
                fi
            fi
        fi
    done
    
    if [ "$found_incompatible" = false ]; then
        echo "- No incompatible modules found."
    else
        echo "- Please uninstall the disabled modules later!"
    fi
}

save_deviceLevelList() {
    echo "-"
    if [ -s "$RESDIR/default_deviceLevelList.txt" ]; then
        echo "- The deviceLevelList backup file already exists and is not empty."
        echo "- Skipping creating backup."
        return
    fi
    
    device_level_list=$(su -c "settings get system deviceLevelList")
    if [ -z "$device_level_list" ] || [ "$device_level_list" = "null" ]; then
        echo "- Failed to retrieve deviceLevelList."
        echo "- Continuing without backup value."
    else
        echo "$device_level_list" > "$RESDIR/default_deviceLevelList.txt"
        echo "- The default value of deviceLevelList is: \`$(cat "$RESDIR/default_deviceLevelList.txt")\`"
    fi
}

set_highend() {
    echo "-"
    new_value="v:1,c:3,g:3"
    echo "- New deviceLevelList value: \`$new_value\`"
    if su -c "settings put system deviceLevelList $new_value"; then
        echo "- Successfully spoofed as a high-end device."
    else
        echo "- Failed to spoof as a high-end device."
    fi
}

restore_deviceLevelList() {
    echo "-"
    if [ -f "$RESDIR/default_deviceLevelList.txt" ]; then
        saved_value=$(cat "$RESDIR/default_deviceLevelList.txt")
        echo "- Restoring deviceLevelList to: \`$saved_value\`."
        if su -c "settings put system deviceLevelList $saved_value"; then
            echo "- Successfully restored deviceLevelList to: \`$saved_value\`"
            if rm -rf "$RESDIR"; then
                echo "- Successfully deleted saved backups."
            else
                echo "- Failed to delete saved backups."
            fi
        else
            echo "- Failed to restore deviceLevelList."
        fi
    else
        echo "- No saved deviceLevelList found. Nothing to restore."
    fi
}

warning() {
    echo "-"
    if [ "$DEVICE_CODENAME" = "gold" ] || [ "$DEVICE_CODENAME" = "iron" ]; then
        echo "- It is recommended to turn on \`Advanced Textures\`,"
        echo "- and to switch to 90Hz or 60Hz refresh rates if you are experiencing lag."
    elif [ "$DEVICE_CODENAME" = "malachite" ]; then
        echo "- Make sure to turn OFF \`Advanced Textures\`."
    elif [ "$DEVICE_CODENAME" = "beryl" ] || [ "$DEVICE_CODENAME" = "citrine" ]; then
        echo "- Turn OFF \`Advanced Textures\` to help with lag!"
    fi
}

credits() {
    echo "-"
    echo "- HyperUnlocked by ukriu"
    echo "- Check me out at \`https://ukriu.com/\`!"
    echo "—— Ɛ: Thank you for using HyperUnlocked! :3 ——"
}

# EOF