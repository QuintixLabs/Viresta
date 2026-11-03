#!/usr/bin/env bash

# obs.sh
# Installs the starting OBS settings.

# OBS keeps its other settings in this file too, so one that exists stays.
# viresta-theme-sync changes the theme in it after that.
install_obs_config() {
    if [ -e "$OBS_CONFIG_FILE" ]; then
        printf 'Kept %s\n' "$OBS_CONFIG_FILE"
        return 0
    fi

    install_file "$CONFIG_SOURCE_DIR/obs-studio/user.ini" "$OBS_CONFIG_FILE"
}
