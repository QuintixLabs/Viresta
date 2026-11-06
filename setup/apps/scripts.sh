#!/usr/bin/env bash

# scripts.sh
# Installs the scripts from the install menu's Scripts section. rename_wallpapers.py is
# there too, but it comes from its own repository, so wallpapers.sh installs it.

# ------------------------------------------------------------
# update
# ------------------------------------------------------------

# In the system folder like viresta, so every shell finds it. Unticked, Viresta's own copy
# is taken away again. A different update command the user had is never touched.
install_update_script() {
    local ours=0

    if [ -e "$UPDATE_SCRIPT" ] && grep -qxF "$UPDATE_SCRIPT" "$INSTALLED_FILES" 2>/dev/null; then
        ours=1
    fi

    if [ "$USE_UPDATE_SCRIPT" -eq 0 ]; then
        if [ "$ours" -eq 1 ]; then
            sudo rm -f -- "$UPDATE_SCRIPT"
            printf 'Removed %s\n' "$UPDATE_SCRIPT"
        fi
        return 0
    fi

    if [ -e "$UPDATE_SCRIPT" ] && [ "$ours" -eq 0 ]; then
        note "Kept your own $UPDATE_SCRIPT, so Viresta's update command was not installed"
        printf 'Kept the existing %s\n' "$UPDATE_SCRIPT"
        return 0
    fi

    sudo install -Dm755 "$UPDATE_SCRIPT_SOURCE" "$UPDATE_SCRIPT"
    track "$UPDATE_SCRIPT"
    printf 'Installed %s\n' "$UPDATE_SCRIPT"
}
