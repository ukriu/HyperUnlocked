#!/bin/sh
# Copyright (C) 2025 ukriu (Contact: contact@ukriu.com)
# Read LICENSE_NOTICE.txt for further info.

. ./utils.sh
CONFIG_FILE="$RESDIR/config"

usage() {
    cat <<EOF
Usage:
  sh webui.sh set <setting> <value>
  sh webui.sh apply
  sh webui.sh status
  sh webui.sh clear

Settings:
  blur true|false
  screenshot_blur true|false
  extra_tiles true|false
  device_level v:1,c:1,g:1 .. v:1,c:3,g:3 (or default)
EOF
}

is_bool() {
    [ "$1" = "true" ] || [ "$1" = "false" ]
}

# clunky ass solution :cry:
is_device_level() {
    case "$1" in
        default|v:1,c:1,g:1|v:1,c:1,g:2|v:1,c:1,g:3|v:1,c:2,g:1|v:1,c:2,g:2|v:1,c:2,g:3|v:1,c:3,g:1|v:1,c:3,g:2|v:1,c:3,g:3)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

set_config_entry() {
    key="$1"
    value="$2"

    mkdir -p "$RESDIR" || return 1
    touch "$CONFIG_FILE" || return 1

    tmp_file="${CONFIG_FILE}.tmp"
    awk -F'=' -v k="$key" -v v="$value" '
        BEGIN { updated = 0 }
        $1 == k { print k "=" v; updated = 1; next }
        { print }
        END { if (!updated) print k "=" v }
    ' "$CONFIG_FILE" > "$tmp_file" || return 1

    mv "$tmp_file" "$CONFIG_FILE" || return 1
    return 0
}

get_config_entry() {
    key="$1"
    default_value="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$default_value"
        return
    fi

    value="$(awk -F'=' -v k="$key" '$1==k{print substr($0, index($0, "=")+1)}' "$CONFIG_FILE" | tail -n 1)"
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

detect_current_blur() {
    if [ -f "$MODDIR/system.prop" ] && grep -q "\$start_bluroff" "$MODDIR/system.prop"; then
        echo "false"
    else
        echo "true"
    fi
}

detect_current_ssblur() {
    if [ -f "$MODDIR/system/product/overlay/HyperUnlocked-screenshot-blur.apk" ]; then
        echo "true"
    else
        echo "false"
    fi
}

detect_current_device_level() {
    echo "$CUR_DEVICE_LEVEL_LIST"
}

set_device_level() {
    su -c "settings put system deviceLevelList $1"
}

read_module_prop() {
    key="$1"
    module_prop_path="$MODDIR/module.prop"

    if [ ! -f "$module_prop_path" ]; then
        return 1
    fi

    awk -F'=' -v k="$key" '$1==k{print substr($0, index($0, "=")+1); exit}' "$module_prop_path"
}

set_value_cmd() {
    setting="$1"
    value="$2"

    if [ -z "$setting" ] || [ -z "$value" ]; then
        usage
        return 1
    fi

    case "$setting" in
        blur|screenshot_blur|extra_tiles|leica)
            if ! is_bool "$value"; then
                warn "Invalid value '$value' for '$setting'. Use true/false."
                return 1
            fi
            staged_value="$value"
            ;;
        device_level)
            if ! is_device_level "$value"; then
                warn "Invalid device level '$value'."
                return 1
            fi
            staged_value="$value"
            ;;
        *)
            warn "Unknown setting '$setting'."
            usage
            return 1
            ;;
    esac

    if ! set_config_entry "$setting" "$staged_value"; then
        warn "Failed writing config file: $CONFIG_FILE"
        return 1
    fi

    log "Queued: $setting=$staged_value"
    return 0
}

apply_cmd() {
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        log "No pending config found at $CONFIG_FILE"
        return 0
    fi

    current_blur="$(detect_current_blur)"
    current_ssblur="$(detect_current_ssblur)"
    current_level="$(detect_current_device_level)"
    blur="$(get_config_entry blur "$current_blur")"
    if ! is_bool "$blur"; then
        warn "Invalid staged blur value."
        return 1
    fi
    ssblur="$(get_config_entry screenshot_blur "$current_ssblur")"
    if ! is_bool "$ssblur"; then
        warn "Invalid staged screenshot_blur value."
        return 1
    fi
    extra_tiles="$(get_config_entry extra_tiles false)"
    if ! is_bool "$extra_tiles"; then
        warn "Invalid staged extra_tiles value."
        return 1
    fi
    device_level="$(get_config_entry device_level "$current_level")"
    if ! is_device_level "$device_level"; then
        warn "Invalid staged device_level value."
        return 1
    fi

    if [ "$blur" = "true" ]; then
        CHOICE_BLUR=true
        log "Blurs: enabled"
    else
        CHOICE_BLUR=false
        log "Blurs: disabled"
    fi

    if [ "$device_level" = "default" ]; then
        restore_deviceLevelList
        log "Device level: restored default"
    else
        save_deviceLevelList
        if ! set_device_level "$device_level"; then
            warn "Failed to apply deviceLevelList '$device_level'."
            return 1
        fi
        log "Device level: $device_level"
    fi

    if ! define_props; then
        warn "Failed generating system.prop."
        return 1
    fi

    if [ "$ssblur" = "true" ]; then
        add_ssblur
        log "Screenshot blur: enabled"
    else
        remove_ssblur
        log "Screenshot blur: disabled"
    fi

    if [ "$extra_tiles" = "true" ]; then
        add_qs_tiles
    fi

    update_desc
    warning

    rm -f "$CONFIG_FILE"
    log "Applied successfully."
    log "Reboot is required for some changes."
    return 0
}

status_cmd() {
    module_version="$(read_module_prop version 2>/dev/null)"
    module_version_code="$(read_module_prop versionCode 2>/dev/null)"

    current_blur="$(detect_current_blur)"
    current_ssblur="$(detect_current_ssblur)"
    current_level="$(detect_current_device_level)"

    # coulf be that user running script outside the module maybe
    [ -n "$module_version" ] && echo "version=$module_version"
    [ -n "$module_version_code" ] && echo "versionCode=$module_version_code"
    echo "current.blur=$current_blur"
    echo "current.screenshot_blur=$current_ssblur"
    echo "current.device_level=$current_level"

    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        echo "pending.config=true"
        while IFS= read -r line; do
            [ -n "$line" ] && echo "pending.$line"
        done < "$CONFIG_FILE"
    else
        echo "pending.config=false"
    fi
}

clear_cmd() {
    if rm -f "$CONFIG_FILE"; then
        log "Cleared staged config."
        return 0
    fi

    warn "Failed clearing staged config."
    return 1
}

command="$1"
shift 2>/dev/null

case "$command" in
    set)
        set_value_cmd "$1" "$2"
        ;;
    apply)
        apply_cmd
        ;;
    status)
        status_cmd
        ;;
    clear)
        clear_cmd
        ;;
    *)
        usage
        exit 1
        ;;
esac
