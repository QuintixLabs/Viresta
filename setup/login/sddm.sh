#!/usr/bin/env bash

# sddm.sh
# Sets up the login screen.

# The wallpaper and colors the login screen starts with. viresta-theme-sync changes
# them after that, so an update leaves them alone.
install_login_look() {
    sudo install -d -m755 -o "$(id -un)" "$(dirname "$LOGIN_WALLPAPER")"
    ln -sfn "$WALLPAPER_DARK" "$LOGIN_WALLPAPER"
    printf 'Linked %s to %s\n' "$LOGIN_WALLPAPER" "$WALLPAPER_DARK"

    install -m644 "$COLOR_SCHEMES_SOURCE_DIR/VirestaDark.colors" "$LOGIN_COLORS"
    printf '\n[General]\nfont=%s\n' "$(sed -n 's/^font=//p' "$KDE_SOURCE_DIR/appearance/kdeglobals")" >>"$LOGIN_COLORS"
}

install_sddm_config() {
    local theme_config="$SDDM_THEMES_DIR/$SDDM_THEME/theme.conf.user"

    # --------------------------------------------------------
    # Theme
    # --------------------------------------------------------

    if [ -d "$SDDM_THEMES_DIR/$SDDM_THEME" ]; then
        sudo_install_file "$SDDM_SOURCE_DIR/theme.conf.user" "$theme_config"
        sudo sed -i "s|^background=.*|background=$LOGIN_WALLPAPER|" "$theme_config"
    else
        printf 'SDDM theme %s is not installed; skipping theme override\n' "$SDDM_THEME" >&2
    fi

    # --------------------------------------------------------
    # Colors, font and cursor
    # --------------------------------------------------------

    # The Viresta Plasma styles are in the user's home, which SDDM cannot read, so
    # plasmarc selects the style that follows the colors in kdeglobals.
    sudo install -d -m755 -o sddm -g sddm "$SDDM_USER_CONFIG_DIR"
    sudo ln -sfn "$LOGIN_COLORS" "$SDDM_USER_CONFIG_DIR/kdeglobals"
    sudo_install_file "$SDDM_SOURCE_DIR/plasmarc" "$SDDM_USER_CONFIG_DIR/plasmarc"
    # KDE's own login screen sync copies this too. The cursor itself comes from
    # install_default_cursor.
    sudo_install_file "$KDE_SOURCE_DIR/appearance/kcminputrc" "$SDDM_USER_CONFIG_DIR/kcminputrc"
    printf 'Linked %s to %s\n' "$SDDM_USER_CONFIG_DIR/kdeglobals" "$LOGIN_COLORS"

    # --------------------------------------------------------
    # SDDM settings
    # --------------------------------------------------------

    sudo_install_file "$SDDM_SOURCE_DIR/viresta.conf" "$SDDM_CONFIG_FILE"
}
