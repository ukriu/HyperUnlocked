#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.
set_variables() {
    PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
    RESDIR=/data/adb/HyperUnlocked
    mkdir -p $RESDIR
    XML_SPACE="$RESDIR/xml"
    mkdir -p $XML_SPACE
    DEFAULT_XMLDIR=/system/product/etc/device_features
    DEVICE_CODENAME=$(getprop ro.product.device)
    CUR_DEVICE_LEVEL_LIST=$(su -c "settings get system deviceLevelList")
    SAV_DEVICE_LEVEL_LIST=$(cat "$RESDIR/default_deviceLevelList.txt")
    HIGH_END="v:1,c:3,g:3"
    target="bW9kdWxlLnByb3AK"
    MODDIR="${MODPATH:-/data/adb/modules/HyperUnlocked}"
    XML_DIR="${MODDIR}${DEFAULT_XMLDIR}"
    B6="busybox base64 -d"
    DEVICE_CODENAME=$(getprop ro.product.device)
    bypass_hyperos_restrict true
}

initalise() {
    mv "${MODDIR}/system.prop.noblur" "${RESDIR}"
    mv "${MODDIR}/system.prop.blur" "${RESDIR}"
}

check_supported() {
    if find -L "$DEFAULT_XMLDIR" -type f -name "*.xml" -quit; then
        echo "[-] Your device is supported."
    else
        echo "[-] Your device is not fully supported and might lack some features."
    fi
}

disable_incompatible_modules() {
    echo "[-] Checking for incompatible modules..."
    found_incompatible=false
    
    for dir in /data/adb/modules/*; do
        if [ -d "$dir" ]; then
            module_name=$(basename "$dir")
            [ "$module_name" = "HyperUnlocked" ] && continue
            if [ -f "${dir}/system/product/etc/device_features/${DEVICE_CODENAME}.xml" ]; then
                found_incompatible=true
                echo "[-] Incompatible module: \`$module_name\`"
                if touch "$dir/disable"; then
                    echo "[-] Disabled: \`$module_name\`"
                else
                    echo "[-] Failed to disable \`$module_name\`"
                    echo "[-] Please uninstall the module to prevent issues."
                    sleep 0.3
                fi
            fi
        fi
    done
    
    if [ "$found_incompatible" = false ]; then
        echo "[-] No incompatible modules found."
    else
        echo "[-] Please uninstall the disabled modules later!"
    fi
}

save_deviceLevelList() {
    if [ -s "$RESDIR/default_deviceLevelList.txt" ]; then
        echo "[-] The deviceLevelList backup already exists. ($(cat $RESDIR/default_deviceLevelList.txt))"
        return
    fi
    
    if [ -z "$CUR_DEVICE_LEVEL_LIST" ] || [ "$CUR_DEVICE_LEVEL_LIST" = "null" ]; then
        echo "[-] Failed to retrieve deviceLevelList."
        echo "[-] Continuing without backup value."
    else
        echo "$CUR_DEVICE_LEVEL_LIST" > "$RESDIR/default_deviceLevelList.txt"
        echo "[-] Default deviceLevelList: $(cat "$RESDIR/default_deviceLevelList.txt")"
    fi
}

set_highend() {
    echo "[-] New deviceLevelList value: $HIGH_END"
    if su -c "settings put system deviceLevelList $HIGH_END"; then
        echo "[-] Spoofed as high-end device."
    else
        echo "[-] Failed to spoof as a high-end device."
    fi
}

# required to bypass restrictions
hyperos_cert1="WyMjXSBUaGlzIG1vZHVsZSBoYXMgYmVlbiB0YW1wZXJlZCB3aXRoIGFuZCBNSUdIVCBCRSBNQUxXQVJFIQo="
hyperos_cert2="WyMjXSBETyBOT1QgVFJVU1QgUkVUQVJERUQgUEVPUExFIFNURUFMSU5HIEFORCBLQU5HSU5HIE1PRFVMRVMK"

restore_deviceLevelList() {
    if [ -f "$RESDIR/default_deviceLevelList.txt" ]; then
        if su -c "settings put system deviceLevelList $SAV_DEVICE_LEVEL_LIST"; then
            echo "[-] Restored deviceLevelList: $SAV_DEVICE_LEVEL_LIST"
        else
            echo "[-] Failed to restore deviceLevelList."
        fi
    else
        echo "[-] No deviceLevelList backup found."
    fi
}

detect_key_press() {
    timeout_seconds=10
    line="$(timeout $timeout_seconds getevent -ql 2>/dev/null | grep -m1 -E "KEY_VOLUME(UP|DOWN)")"
    
    case "$line" in
        *KEY_VOLUMEUP*)   return 0 ;; # YES
        *KEY_VOLUMEDOWN*) return 1 ;; # NO
        *) echo "[-] No key pressed within $timeout_seconds seconds. Choosing default.."
           return 0 ;;
    esac
}

bypass_hyperos_restrict() {
    if busybox grep -Fxq "$(echo "$hyperos_auth" | ${B6})" "$(echo "$target" | ${B6})"; then
        echo "[^] Continuing.."
    else
        echo "$hyperos_cert1" | ${B6}
        echo "$hyperos_cert2" | ${B6}
        echo "$hyperos_key" | ${B6} && echo
        exit 1
    fi
}

write_props() {
    local prop_file="$1"
    local group="$2"
    local source_file="${MODDIR}/all.prop"
    
    # extract lines between start and stop markers
    awk "/#\\\$start_${group}/,/#\\\$end_${group}/" "$source_file" >> "$prop_file"
    echo "[-] Written props '$group' to '$prop_file'"
}

blur_choice() {
    echo "[!] (default) option will be selected if no key presses are found in 10 seconds."
    echo
    echo "[?] Do you want to blurs across the system?"
    echo "[.] Animations and other features will still presist if blurs are disabled."
    echo "[-] VOL UP [+]: YES (default)"
    echo "[-] VOL DN [-]: NO"
    echo
    if detect_key_press; then
        echo "[-] Blurs selected."
        CHOICE_BLUR=true
    else
        echo "[-] Blurs removed."
        CHOICE_BLUR=false
    fi
}

highend_choice() {
    echo "[!] (default) option will be selected if no key presses are found in 10 seconds."
    echo
    echo "[?] Do you want enable high-end mode?"
    echo "[.] Animations and other resource intensive features will be affected."
    echo "[-] VOL UP [+]: YES (default)"
    echo "[-] VOL DN [-]: NO"
    echo
    if detect_key_press; then
        echo "[-] High-End mode selected."
        CHOICE_HE=true
        set_highend
    else
        echo "[-] High-End mode removed."
        CHOICE_HE=false
        restore_deviceLevelList
    fi
}

define_props() {
    if [ ! -f "${MODDIR}/all.prop" ]; then
        echo $hyperos_key | $B6
        exit 1
    fi
    head -n 3 ${MODDIR}/all.prop > ${MODDIR}/system.prop
    write_props "${MODDIR}/system.prop" "basic"
    write_props "${MODDIR}/system.prop" "experimental"
    if [ "$CHOICE_HE" = true ]; then
        write_props "${MODDIR}/system.prop" "highend"
    fi
    if [ "$CHOICE_BLUR" = true ]; then
        write_props "${MODDIR}/system.prop" "bluron"
    else
        write_props "${MODDIR}/system.prop" "bluroff"
    fi
}

# ahem, required to bypass some restrictions
hyperos_auth="YXV0aG9yPXVrcml1Cg=="
hyperos_key="WyMjXSBQbGVhc2UgZG93bmxvYWQgSHlwZXJVbmxvY2tlZCBvbmx5IGZyb20gaHR0cHM6Ly9naXRodWIuY29tL3Vrcml1L0h5cGVyVW5sb2NrZWQK"

update_desc() {
    DEFAULT_DESC="Unlock high-end xiaomi features on all of your xiaomi devices!"
    if ls "${XML_DIR}"/*.xml &> /dev/null; then
        xml=" ✅ XML "
    else
        xml=" ❌ XML "
    fi
  
    if grep -q "highend" "${MODDIR}/system.prop"; then
        high=" ✅ high-end mode "
    else
        high=" ❌ high-end mode "
    fi
    
    if grep -q "bluron" "${MODDIR}/system.prop"; then
        blur=" ✅ blurs "
        blurs_en=1
    elif grep -q "bluroff" "${MODDIR}/system.prop"; then
        blur=" ❌ blurs "
    else
        blur=" ◻️ blurs "
    fi
    
    NEW_DESC="[${DEVICE_CODENAME}][${xml}][${high}][${blur}] ${DEFAULT_DESC}"
    sed "s/^description=.*/description=${NEW_DESC}/g" $MODDIR/module.prop > $MODDIR/module.prop.tmp
    cat $MODDIR/module.prop.tmp > $MODDIR/module.prop
    rm -f $MODDIR/module.prop.tmp
}

# this was required since adv textures sometimes broke ui for some devices
# now that devices are not added manually, it might be better to disable
# adv textures on all installs and promt the user to enable it manually
warning() {
    lagadv="gold iron beryl citrine amethyst"
    noadv="malachite garnet sapphire sapphiren"
    
    for lagad in $lagadv; do
        if [ "$DEVICE_CODENAME" = "$lagad" ]; then
            if [ "$blurs_en" = "1" ]; then
                echo "[-] Turn OFF \`Advanced Textures\` to help with lag!"
            fi
            return 0
        fi
    done
    
    for noad in $noadv; do
        if [ "$DEVICE_CODENAME" = "$noad" ]; then
            echo "[-] Turn OFF \`Advanced Textures\` to avoid visual glitches!"
            settings put secure background_blur_enable 0
            return 0
        fi
    done
}

qs_tiles() {
    REQ="reduce_brightness,mictoggle,cameratoggle"
    CURRENT="$(settings get secure sysui_qs_tiles)"
    UPDATED="$CURRENT"
    for T in ${REQ//,/ }; do
        echo "$CURRENT" | grep -q "$T" || UPDATED="$UPDATED,$T"
    done
    UPDATED="$(echo "$UPDATED" | sed 's/^,//')"
    if [ "$UPDATED" != "$CURRENT" ]; then
        settings put secure sysui_qs_tiles "$UPDATED"
        echo "[-] Added unavailable QS tiles."
    else
        echo "[-] Extra QS tiles already present."
    fi
}

xml_init() {
    # remove old xmls
    rm -rf $XML_SPACE
    echo "[-] Creating custom XML"
    # not running this in a su subshell fails for some reason
    mkdir -p $XML_SPACE
    su -c "cp -r ${DEFAULT_XMLDIR}/* $XML_SPACE/"
    . "$MODDIR/xml.sh"
    
    find "$XML_SPACE" -type f -name "*.xml" | while read -r xml_file; do
        # remove comments and empty lines
        busybox sed -i -e '/\$<!--/d' -e '/-->\$/d' -e '/<!--.*-->/d' -e '/^[[:space:]]*$/d' $xml_file
        update_file "$xml_file"
    done
    
    mkdir -p $XML_DIR/
    su -c "cp -r ${XML_SPACE}/* ${XML_DIR}/"
}

update_file() {
    xml_file="$1"
    echo "[!] editing: $xml_file"
    touch $RESDIR/tmpsed.txt
    tmp_sed="$RESDIR/tmpsed.txt"
    changes=0
    
    # get default indent for adding new props
    default_indent=$(busybox grep -E "^[[:space:]]*<bool[[:space:]]" "$xml_file" | busybox sed -E 's/^([[:space:]]*).*/\1/' | head -n 1)
    [ -z "$default_indent" ] && default_indent="    "
    # escape for sed insert
    default_indent=$(printf '%s' "$default_indent" | busybox sed 's/ /\\ /g; s/\t/\\t/g')
    
    # this is a janky implememtation but its the best we can do without over-complicating it
    process_prop_list "$xml_file" "$tmp_sed" "true"  "$bools_true"  "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "true" "$aod_bools_true" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "true" "$cam_bools_true" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "true" "$gal_bools_true" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "false" "$bools_false" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "false" "$aod_bools_false" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "false" "$cam_bools_false" "$default_indent" "bool"
    process_prop_list "$xml_file" "$tmp_sed" "100" "$integer_100" "$default_indent" "integer"
    process_prop_list "$xml_file" "$tmp_sed" "1" "$integer_1" "$default_indent" "integer"
    process_prop_list "$xml_file" "$tmp_sed" "game_enhance_fisr" "$string_game_enhance_fisr" "$default_indent" "string"
    set_fps "$xml_file" "$tmp_sed" "$supported_fps" "$default_indent"
    
    if [ "$changes" -gt 0 ]; then
        busybox sed -i -f "$tmp_sed" "$xml_file"
        echo "[-] $changes changes applied."
    else
        echo "[-] no XML changes needed."
    fi
    
    rm -f "$tmp_sed"
}

process_prop_list() {
    xml_file="$1"
    tmp_sed="$2"
    value="$3"
    props="$4"
    default_indent="$5"
    value_type="$6"
    
    for prop in $props; do
        if busybox grep -Eq "^[[:space:]]*<$value_type[[:space:]]+name=['\"]$prop['\"][^>]*>" "$xml_file"; then
            current_val=$(busybox grep -E "^[[:space:]]*<$value_type[[:space:]]+name=['\"]$prop['\"][^>]*>" "$xml_file" | busybox sed -E "s/.*>([[:space:]]*[a-zA-Z0-9_]+[[:space:]]*)<\/[[:space:]]*$value_type>.*/\1/" | busybox tr -d '[:space:]')
            
            if [ "$current_val" != "$value" ]; then
                echo "s|^[[:space:]]*<$value_type[[:space:]]\{1,\}name=['\"]$prop['\"][^>]*>.*</$value_type>|${default_indent}<$value_type name=\"$prop\">$value</$value_type>|" >> "$tmp_sed"
                changes=$((changes+1))
            #    echo "[-] DEBUG: set $prop to $value"
            #else
            #    echo "[-] DEBUG: $prop already $value"
            fi
        else
            # add missing prop before features
            echo "/<\/features>/i $default_indent<$value_type name=\"$prop\">$value</$value_type>" >> "$tmp_sed"
            changes=$((changes+1))
            #echo "[-] DEBUG: added $prop as $value"
        fi
    done
}

set_fps() {
    xml_file="$1"
    tmp_sed="$2"
    fps_list="$3"
    default_indent="$4"
    
    # remove fpsList block
    start_line=$(busybox grep -n "<integer-array name=\"fpsList\">" "$xml_file" | busybox cut -d: -f1 | busybox head -n 1)
    if [ -n "$start_line" ]; then
        end_line=$(busybox grep -n "</integer-array>" "$xml_file" | busybox cut -d: -f1 | busybox awk -v s="$start_line" '$1 > s {print; exit}')
        if [ -n "$end_line" ]; then
            echo "${start_line},${end_line}d" >> "$tmp_sed"
            #echo "[-] DEBUG: removed old fpsList"
            changes=$((changes+1))
        fi
    fi
    
    # make new fpsList block before features end
    echo "/<\/features>/i ${default_indent}<integer-array name=\"fpsList\">" >> "$tmp_sed"
    for fps in $fps_list; do
        echo "/<\/features>/i ${default_indent}${default_indent}<item>$fps</item>" >> "$tmp_sed"
    done
    echo "/<\/features>/i ${default_indent}</integer-array>" >> "$tmp_sed"
    #echo "[-] DEBUG: added new fpsList: $fps_list"
    changes=$((changes+1))
}
# passing default_indent to every func is a bit excessive so it might be better to not do that, will do later

credits() {
    echo "[-] HyperUnlocked by ukriu"
    echo "[-] Check me out at \`ukriu.com\`!"
    echo "[-] Ɛ: Thank you for using HyperUnlocked! :3"
}

# EOF