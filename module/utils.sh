#!/bin/sh
set_variables() {
    RESDIR=/data/adb/HyperUnlocked
    mkdir -p $RESDIR
    DEVICE_CODENAME=$(getprop ro.product.device)
    CUR_DEVICE_LEVEL_LIST=$(su -c "settings get system deviceLevelList")
    SAV_DEVICE_LEVEL_LIST=$(cat "$RESDIR/default_deviceLevelList.txt")
    HIGH_END="v:1,c:3,g:3"
    XML_MODDIR=$MODDIR/system/product/etc/device_features
    XML_DIR=/product/etc/device_features
    DEVICE_CODENAME=$(getprop ro.product.device)
    ADDONS_BIN=$MODDIR/addons
}

initalise() {
    chmod 0755 $ADDONS_BIN/*
    mkdir -p "$XML_MODDIR"
    mv "${MODDIR}/system.prop.noblur" "${RESDIR}"
    mv "${MODDIR}/system.prop.blur" "${RESDIR}"
}

check_supported() {
    codenames="gold iron malachite beryl citrine sapphire sapphiren pipa amethyst river sky XIG03 garnet XIG05 tanzanite gale gust"

    for codename in $codenames; do
        if [ "$DEVICE_CODENAME" = "$codename" ]; then
            supported=true
            echo "[-] Supported device!"
            return 0
        fi
    done
    # handle the case where the device is not in the list
    if [ -z $DEVICE_CODENAME ]; then
        echo "[-] Your device is not fully supported and might lack some features."
    else
        partial=true
        echo "[-] Your device is partially supported."
    fi
}

disable_incompatible_modules() {
    echo "-"
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
    echo "-"
    if [ -s "$RESDIR/default_deviceLevelList.txt" ]; then
        echo "[-] The deviceLevelList backup file already exists and is not empty."
        echo "[-] Skipping creating backup."
        return
    fi
    
    if [ -z "$CUR_DEVICE_LEVEL_LIST" ] || [ "$CUR_DEVICE_LEVEL_LIST" = "null" ]; then
        echo "[-] Failed to retrieve deviceLevelList."
        echo "[-] Continuing without backup value."
    else
        echo "$CUR_DEVICE_LEVEL_LIST" > "$RESDIR/default_deviceLevelList.txt"
        echo "[-] The default value of deviceLevelList is: \`$(cat "$RESDIR/default_deviceLevelList.txt")\`"
    fi
}

set_highend() {
    echo "-"
    echo "[-] New deviceLevelList value: \`$HIGH_END\`"
    if su -c "settings put system deviceLevelList $HIGH_END"; then
        echo "[-] Successfully spoofed as a high-end device."
    else
        echo "[-] Failed to spoof as a high-end device."
    fi
}

restore_deviceLevelList() {
    echo "-"
    if [ -f "$RESDIR/default_deviceLevelList.txt" ]; then
        echo "[-] Restoring deviceLevelList to: \`$SAV_DEVICE_LEVEL_LIST\`."
        if su -c "settings put system deviceLevelList $SAV_DEVICE_LEVEL_LIST"; then
            echo "[-] Successfully restored deviceLevelList to: \`$SAV_DEVICE_LEVEL_LIST\`"
        else
            echo "[-] Failed to restore deviceLevelList."
        fi
    else
        echo "[-] No saved deviceLevelList found. Nothing to restore."
    fi
}


detect_key_press() {
    timeout_seconds=10
    line=$(timeout $timeout_seconds getevent -ql 2>/dev/null | head -n 1)
    
    if [ $? -eq 124 ]; then
      echo "[-] No key pressed within $timeout_seconds seconds. Choosing default.."
      return 0  # default = YES
    fi
  
    if echo "$line" | grep -q "KEY_VOLUMEDOWN"; then
      return 1  # NO
    else
      return 0  # YES
    fi
}

blur_choice() {
    echo "[!!!]"
    echo "[!] (default) option will be selected if no key presses are found in 10 seconds."
    
    echo "[?] Do you want to blurs across the system?"
    echo "[.] Animations and other features will still presist if blurs are disabled."
    echo "-"
    echo "[-] VOL UP [+]: YES (default)"
    echo "[-] VOL DN [-]: NO"
    echo "[¡¡¡]"
    if detect_key_press; then
      echo "[-] Blurs selected."
      cp "${RESDIR}/system.prop.blur" "${MODDIR}/system.prop"
    else
      echo "[-] Blurs removed."
      cp "${RESDIR}/system.prop.noblur" "${MODDIR}/system.prop"
    fi
}

highend_choice() {
    echo "[!!!]"
    echo "[!] (default) option will be selected if no key presses are found in 10 seconds."
    
    echo "[?] Do you want enable high-end mode?"
    echo "[.] Animations and other resource intensive features will be affected."
    echo "-"
    echo "[-] VOL UP [+]: YES (default)"
    echo "[-] VOL DN [-]: NO"
    echo "[¡¡¡]"
    if detect_key_press; then
      echo "[-] High-End mode selected."
      set_highend
    else
      echo "[-] High-End mode removed."
      restore_deviceLevelList
    fi
}

credits() {
    echo "-"
    echo "[-] HyperUnlocked by ukriu"
    echo "[-] Check me out at \`ukriu.com\`!"
    echo "- Ɛ: Thank you for using HyperUnlocked! :3"
}

update_desc() {
    echo "-"
    DEFAULT_DESC="Unlock high-end xiaomi features on all of your xiaomi devices!"
    if [ -n "$supported" ]; then
      xml=" ✅ XML "
    elif [ -n "$partial" ]; then
      xml=" ⚠️ Generic XML "
    else
      xml=" ❌ XML "
    fi
  
    if [ "$(settings get system deviceLevelList)" = "$HIGH_END" ]; then
      high=" ✅ high-end mode "
    else
      high=" ❌ high-end mode "
    fi
    
    if cmp -s "${RESDIR}/system.prop.blur" "${MODDIR}/system.prop"; then
      blur=" ✅ blurs "
      blurs_en=1
    elif cmp -s "${RESDIR}/system.prop.noblur" "${MODDIR}/system.prop"; then
      blur=" ❌ blurs "
    else
      blur=" ◻️ blurs "
    fi
    
    NEW_DESC="[${DEVICE_CODENAME}][${xml}][${high}][${blur}] ${DEFAULT_DESC}"
    sed "s/^description=.*/description=${NEW_DESC}/g" $MODDIR/module.prop > $MODDIR/module.prop.tmp
    cat $MODDIR/module.prop.tmp > $MODDIR/module.prop
    rm -f $MODDIR/module.prop.tmp
}

warning() {
    echo "-"
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
            if [ "$blurs_en" = "1" ]; then
              echo "[-] Turn OFF \`Advanced Textures\` to avoid visual glitches!"
            fi
            settings put secure background_blur_enable 0
            return 0
        fi
    done
}

xml_patch() {
    # Usage: xml_patch <device_name>
    # Applies JSON-defined feature patches to the corresponding XML file.

    local DEV_JSON="$1"
    local DEV_NAME="$2"
    [ -z "$DEV_NAME" ] && { echo "Usage: xml_patch <device_name>"; return 1; }

    local JSON_FILE="$MODDIR/devices/${DEV_JSON}.json"
    local XML_FILE="$XML_DIR/${DEV_NAME}.xml"
    # Use backup instead
    if [ -f "$RESDIR/${DEV_NAME}.backup.xml" ]; then
        echo "[-] Found backup XML for ${DEV_NAME}. Using it as source."
        XML_FILE="$RESDIR/${DEV_NAME}.backup.xml"
    fi
    local FINAL_XML_FILE="$XML_MODDIR/${DEV_NAME}.xml"

    # Work on a temporary copy of the XML file to avoid partial writes.
    local TMP_XML="$RESDIR/${DEV_NAME}_tmp.xml"
    # Backup the stock XML
    if [ "$XML_FILE" != "$RESDIR/${DEV_NAME}.backup.xml" ]; then
        echo "[-] Backing up stock XML..."
        cp "$XML_FILE" "$RESDIR/${DEV_NAME}.backup.xml"
    fi
    echo "[-] Patching XML..."
    cp "$XML_FILE" "$TMP_XML"

    # Process time!
    $ADDONS_BIN/jq -c '.[] | {feature: (.feature // .name), type, value}' "$JSON_FILE" | while read -r entry; do
        local NAME TYPE
        NAME="$(echo "$entry" | $ADDONS_BIN/jq -r '.feature')"
        TYPE="$(echo "$entry" | $ADDONS_BIN/jq -r '.type')"

        # Remove or update existing element.
        if [ "$($ADDONS_BIN/xmlstarlet sel -t -v "count(/features/${TYPE}[@name='${NAME}'])" "$TMP_XML")" -gt 0 ]; then
            if [ "$TYPE" = "bool" ] || [ "$TYPE" = "integer" ] || \
               [ "$TYPE" = "float" ] || [ "$TYPE" = "string" ]; then
                local VAL
                VAL="$(echo "$entry" | $ADDONS_BIN/jq -r '.value')"
                $ADDONS_BIN/xmlstarlet ed -P -L -u "/features/${TYPE}[@name='${NAME}']" -v "$VAL" "$TMP_XML"
                continue
            else
                $ADDONS_BIN/xmlstarlet ed -P -L -d "/features/${TYPE}[@name='${NAME}']" "$TMP_XML"
            fi
        fi

        # Insert new element (depends)
        case "$TYPE" in
          bool|boolean|integer|float|string)
            local VAL
            VAL="$(echo "$entry" | $ADDONS_BIN/jq -r '.value')"
            $ADDONS_BIN/xmlstarlet ed -P -L \
              -s /features -t elem -n "$TYPE" -v "$VAL" \
              -i "/features/${TYPE}[not(@name)][last()]" -t attr -n name -v "$NAME" \
              "$TMP_XML"
            ;;
          "string-array"|"integer-array")
            $ADDONS_BIN/xmlstarlet ed -P -L \
              -s /features -t elem -n "$TYPE" -v "" \
              -i "/features/${TYPE}[not(@name)][last()]" -t attr -n name -v "$NAME" \
              "$TMP_XML"

            echo "$entry" | $ADDONS_BIN/jq -r '.value[]' | while read -r ITEM; do
                $ADDONS_BIN/xmlstarlet ed -P -L \
                  -s "/features/${TYPE}[@name='${NAME}']" -t elem -n item -v "$ITEM" \
                  "$TMP_XML"
            done
            ;;
          *)
            echo "[-] Unsupported type \"$TYPE\" for feature \"$NAME\"."
            ;;
        esac
    done

    # Remove XML comments for cleaner :)
    $ADDONS_BIN/xmlstarlet ed -P -L -d "//comment()" "$TMP_XML"

    # Sort elements by node name then @name.
    local SORT_XSLT="$RESDIR/sort_${DEV_NAME}.xslt"
    cat > "$SORT_XSLT" <<'EOF'
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="features">
    <features>
      <xsl:apply-templates select="*">
        <xsl:sort select="name()" data-type="text"/>
        <xsl:sort select="@name" data-type="text"/>
      </xsl:apply-templates>
    </features>
  </xsl:template>
  <xsl:template match="comment()"/>
</xsl:stylesheet>
EOF

    $ADDONS_BIN/xmlstarlet tr "$SORT_XSLT" "$TMP_XML" > "${TMP_XML}.sorted" && mv "${TMP_XML}.sorted" "$TMP_XML"
    rm -f "$SORT_XSLT"

    # Format XML w/ 4 indentations.
    if $ADDONS_BIN/xmlstarlet fo -s 4 -e UTF-8 "$TMP_XML" > "${TMP_XML}.pretty" 2>/dev/null; then
        # In case it fails, will just leave it as is
        mv "${TMP_XML}.pretty" "$TMP_XML"
    fi
    # Replace original XML with patched version.
    mv "$TMP_XML" "$FINAL_XML_FILE"
    echo "[-] Patched XML saved to $FINAL_XML_FILE"
}

cleanup() {
  echo "[-] Cleaning up..."
  rm -rf $MODDIR/devices
  rm -rf $ADDONS_BIN
}
# EOF