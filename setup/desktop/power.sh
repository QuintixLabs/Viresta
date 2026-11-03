#!/usr/bin/env bash

# power.sh
# Installs the power settings for a laptop or a desktop.

# ------------------------------------------------------------
# Machine type
# ------------------------------------------------------------

# A mouse or a UPS can also report a battery, so the battery only decides when the
# system cannot say what it is. Those mouse batteries have the scope "Device".
has_system_battery() {
    local supply

    for supply in "$POWER_SUPPLY_DIR"/*; do
        [ "$(cat "$supply/type" 2>/dev/null)" = "Battery" ] || continue
        [ "$(cat "$supply/scope" 2>/dev/null)" != "Device" ] || continue
        return 0
    done
    return 1
}

# A VM counts as a desktop, because its battery is not a real one.
machine_type() {
    case "$(hostnamectl chassis 2>/dev/null)" in
        laptop|convertible|tablet|handset)
            printf 'laptop\n'
            ;;
        desktop|server|vm|container)
            printf 'desktop\n'
            ;;
        *)
            if has_system_battery; then
                printf 'laptop\n'
            else
                printf 'desktop\n'
            fi
            ;;
    esac
}

# ------------------------------------------------------------
# Profiles
# ------------------------------------------------------------

install_power_profile() {
    local profile="${POWER_PROFILE:-$(machine_type)}"

    install_file "$POWER_SOURCE_DIR/$profile-powerdevilrc" "$POWER_CONFIG_FILE"
    printf 'Using the %s power profile\n' "$profile"

    # The screen locks when it turns off on a laptop, and asks for the password on wake.
    if [ "$profile" = "laptop" ]; then
        sed -i -e 's/^Autolock=.*/Autolock=true/' -e "s/^Timeout=.*/Timeout=$LAPTOP_LOCK_MINUTES/" "$LOCK_SCREEN_FILE"
    fi
}
