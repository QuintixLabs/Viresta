#!/usr/bin/env bash

# obs.sh
# Installs the starting OBS settings and its launcher.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

# OBS keeps its other settings in this file too, so one that exists stays.
# viresta-theme-sync changes the theme in it after that.
install_obs_config() {
    if [ -e "$OBS_CONFIG_FILE" ]; then
        printf 'Kept %s\n' "$OBS_CONFIG_FILE"
        return 0
    fi

    install_file "$CONFIG_SOURCE_DIR/obs-studio/user.ini" "$OBS_CONFIG_FILE"
}

# ------------------------------------------------------------
# Launcher
# ------------------------------------------------------------

# A copy of OBS's own menu entry that sets the theme first, since OBS overwrites a
# change made while it is open. It is rebuilt from the package's entry on each update.
install_obs_launcher() {
    [ -f "$OBS_DESKTOP_SOURCE" ] || return 0

    mkdir -p "$(dirname "$OBS_DESKTOP_FILE")"
    sed -E \
        -e 's/ %[a-zA-Z]//g' \
        -e "s|^Exec=(.*)|Exec=sh -c \"$THEME_SYNC_SCRIPT --obs; exec \1\"|" \
        "$OBS_DESKTOP_SOURCE" >"$OBS_DESKTOP_FILE"
    track "$OBS_DESKTOP_FILE"
    printf 'Installed %s\n' "$OBS_DESKTOP_FILE"

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}
