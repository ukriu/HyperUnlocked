#!/bin/sh
set_variables() {
  RESDIR=/data/adb/HyperUnlocked
  mkdir -p $RESDIR
  DEVICE_CODENAME=$(getprop ro.product.device)
  CUR_DEVICE_LEVEL_LIST=$(su -c "settings get system deviceLevelList")
  SAV_DEVICE_LEVEL_LIST=$(cat "$RESDIR/default_deviceLevelList.txt")
  HIGH_END="v:1,c:3,g:3"
  MODDIR=/data/adb/modules/HyperUnlocked
  XML_DIR=$MODDIR/product/etc/device_features/
  DEVICE_CODENAME=$(getprop ro.product.device)
}

check_supported() {
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
    
    if [ -z "$CUR_DEVICE_LEVEL_LIST" ] || [ "$CUR_DEVICE_LEVEL_LIST" = "null" ]; then
        echo "- Failed to retrieve deviceLevelList."
        echo "- Continuing without backup value."
    else
        echo "$CUR_DEVICE_LEVEL_LIST" > "$RESDIR/default_deviceLevelList.txt"
        echo "- The default value of deviceLevelList is: \`$(cat "$RESDIR/default_deviceLevelList.txt")\`"
    fi
}

set_highend() {
    echo "-"
    echo "- New deviceLevelList value: \`$HIGH_END\`"
    if su -c "settings put system deviceLevelList $HIGH_END"; then
        echo "- Successfully spoofed as a high-end device."
    else
        echo "- Failed to spoof as a high-end device."
    fi
}

restore_deviceLevelList() {
    echo "-"
    if [ -f "$RESDIR/default_deviceLevelList.txt" ]; then
        echo "- Restoring deviceLevelList to: \`$SAV_DEVICE_LEVEL_LIST\`."
        if su -c "settings put system deviceLevelList $SAV_DEVICE_LEVEL_LIST"; then
            echo "- Successfully restored deviceLevelList to: \`$SAV_DEVICE_LEVEL_LIST\`"
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

swichDeviceLevel() {
  echo "-"
  if [ "$CUR_DEVICE_LEVEL_LIST" = "$HIGH_END" ]; then
    echo "- Device currently marked as high-end."
    restore_deviceLevelList
  elif [ "$CUR_DEVICE_LEVEL_LIST" = "$SAV_DEVICE_LEVEL_LIST"]; then
    echo "- Device currently not marked as high-end."
    if su -c "settings put system deviceLevelList $HIGH_END"; then
      echo "- Successfully spoofed device as high-end."
    else
      echo "- Failed to set deviceLevelList"
    fi
  else
    echo "N/A"
  fi
}

update_desc() {
  echo "-"
  DEFAULT_DESC="Unlock high-end xiaomi features on all of your xiaomi devices!"
  if [ "find ${XML_DIR} -type f 2>/dev/null)" ]; then
    xml=" ✅ XML "
  else
    xml=" ❌ XML "
  fi
  if [ "$CUR_DEVICE_LEVEL_LIST" = "$HIGH_END" ]; then
    high=" ✅ High-End "
  else
    high=" ❌ High-End "
  fi
  NEW_DESC="[${DEVICE_CODENAME}][${xml}][${high}] ${DEFAULT_DESC}"
  
  # workaround for bindhosts/bindhosts/issues/108
  sed "s/^description=.*/${NEW_DESC}/g" $MODDIR/module.prop > $MODDIR/module.prop.tmp
  cat $MODDIR/module.prop.tmp > $MODDIR/module.prop
  rm -f $MODDIR/module.prop.tmp
}

# EOF