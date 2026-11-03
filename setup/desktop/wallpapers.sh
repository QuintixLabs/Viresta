#!/usr/bin/env bash

# wallpapers.sh
# Installs the wallpapers and sets the default one.

# ------------------------------------------------------------
# User wallpapers
# ------------------------------------------------------------

install_wallpapers() {
    if [ "$USE_RENAME_WALLPAPERS" -eq 1 ]; then
        download_rename_wallpapers
    fi

    install_tree "$WALLPAPERS_SOURCE_DIR/Viresta Dark" "$USER_WALLPAPERS_DIR/Viresta Dark"
    install_tree "$WALLPAPERS_SOURCE_DIR/Viresta Light" "$USER_WALLPAPERS_DIR/Viresta Light"
}

# A failed download should not stop the install, since nothing else needs this script.
download_rename_wallpapers() {
    local temp_file

    temp_file="$(mktemp)"
    if curl -fsSL "$RENAME_WALLPAPERS_URL" -o "$temp_file"; then
        install_file "$temp_file" "$USER_WALLPAPERS_DIR/rename_wallpapers.py"
    else
        printf 'Could not download rename_wallpapers.py\n' >&2
    fi
    rm -f "$temp_file"
}

# ------------------------------------------------------------
# System wallpapers
# ------------------------------------------------------------

install_system_wallpapers() {
    sudo_install_file "$WALLPAPER_DARK_SOURCE" "$WALLPAPER_DARK"
    sudo_install_file "$WALLPAPER_LIGHT_SOURCE" "$WALLPAPER_LIGHT"
}

# ------------------------------------------------------------
# Default wallpaper
# ------------------------------------------------------------

configure_wallpaper() {
    local file

    for file in "$PLASMA_LAYOUT_FILE" "$LOCK_SCREEN_FILE"; do
        sed -i "s|^\(Preview\)\?Image=.*|\1Image=file://$WALLPAPER_DARK|" "$file"
        printf 'Configured wallpaper in %s\n' "$file"
    done
}
