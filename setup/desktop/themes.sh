#!/usr/bin/env bash

# themes.sh
# Installs the global themes, styles and color schemes.

# ------------------------------------------------------------
# Color schemes
# ------------------------------------------------------------

install_color_schemes() {
    install_tree "$COLOR_SCHEMES_SOURCE_DIR" "$DATA_DIR/color-schemes"
}

# ------------------------------------------------------------
# Global themes
# ------------------------------------------------------------

install_global_themes() {
    install_tree "$THEMES_SOURCE_DIR/look-and-feel" "$THEMES_DIR"

    sed -i "s|^Image=.*|Image=$WALLPAPER_DARK|" "$THEMES_DIR/$THEME_DARK/contents/defaults"
    sed -i "s|^Image=.*|Image=$WALLPAPER_LIGHT|" "$THEMES_DIR/$THEME_LIGHT/contents/defaults"

    install_theme_layout "$THEME_DARK" "$WALLPAPER_DARK"
    install_theme_layout "$THEME_LIGHT" "$WALLPAPER_LIGHT"
}

install_theme_layout() {
    local target="$THEMES_DIR/$1/contents/layouts/$THEME_LAYOUT_NAME"
    local settings

    settings="$(jq -ce '.globalSettings' "$PANEL_COLORIZER_PRESET_DIR/settings.json")"

    mkdir -p "$(dirname "$target")"
    # Values go through ENVIRON because awk and sed would interpret them otherwise.
    SETTINGS="$settings" PRESET_DIR="$PANEL_COLORIZER_PRESET_DIR" WALLPAPER="$2" VICINAE="$USE_VICINAE" awk '
        function fill(name, value, at) {
            at = index($0, name)
            if (at) $0 = substr($0, 1, at - 1) value substr($0, at + length(name))
        }
        {
            fill("@PANEL_COLORIZER_SETTINGS@", ENVIRON["SETTINGS"])
            fill("@PANEL_COLORIZER_PRESET_DIR@", ENVIRON["PRESET_DIR"])
            fill("@WALLPAPER@", ENVIRON["WALLPAPER"])
            fill("@USE_VICINAE@", ENVIRON["VICINAE"])
            print
        }
    ' "$THEMES_SOURCE_DIR/$THEME_LAYOUT_NAME" >"$target"
    printf 'Installed %s\n' "$target"
}

# ------------------------------------------------------------
# Styles
# ------------------------------------------------------------

# A style is its color scheme on top of Breeze's shapes, the same way KDE builds
# Breeze Dark and Breeze Light.
install_plasma_styles() {
    install_tree "$THEMES_SOURCE_DIR/desktoptheme" "$PLASMA_STYLES_DIR"

    install_file "$COLOR_SCHEMES_SOURCE_DIR/VirestaDark.colors" "$PLASMA_STYLES_DIR/viresta-dark/colors"
    install_file "$COLOR_SCHEMES_SOURCE_DIR/VirestaLight.colors" "$PLASMA_STYLES_DIR/viresta-light/colors"
}

# Fusion and MS Windows 9x are built into Qt, so they can only be hidden from
# Settings. Union is hidden the same way rather than risk removing its package.
hide_app_styles() {
    install_tree "$THEMES_SOURCE_DIR/kstyle" "$DATA_DIR/kstyle/themes"
}

# ------------------------------------------------------------
# Theme switching
# ------------------------------------------------------------

# Plasma does not apply a global theme's wallpaper, so this service does it.
# kdeglobals is installed with the dark theme, which is what the state file records.
install_theme_sync() {
    local wants_dir="$CONFIG_DIR/systemd/user/graphical-session.target.wants"

    install -Dm755 "$THEMES_SOURCE_DIR/viresta-theme-sync" "$THEME_SYNC_SCRIPT"
    sed -i "s|^LOGIN_WALLPAPER=.*|LOGIN_WALLPAPER=\"$LOGIN_WALLPAPER\"|" "$THEME_SYNC_SCRIPT"
    sed -i "s|^LOGIN_COLORS=.*|LOGIN_COLORS=\"$LOGIN_COLORS\"|" "$THEME_SYNC_SCRIPT"
    sed -i "s|^LOGIN_PROFILE_PICTURE=.*|LOGIN_PROFILE_PICTURE=\"$LOGIN_PROFILE_PICTURE\"|" "$THEME_SYNC_SCRIPT"
    printf 'Installed %s\n' "$THEME_SYNC_SCRIPT"

    mkdir -p "$(dirname "$THEME_SYNC_STATE_FILE")" "$wants_dir"
    printf '%s\n' "$THEME_DARK" >"$THEME_SYNC_STATE_FILE"
    ln -sfn "../$THEME_SYNC_UNIT" "$wants_dir/$THEME_SYNC_UNIT"
    printf 'Enabled %s\n' "$THEME_SYNC_UNIT"
}

# Each theme carries its picture, and viresta-theme-sync decides whether to apply it,
# since a picture the user chose must survive both this install and theme changes.
install_profile_pictures() {
    local theme_faces="$SDDM_THEMES_DIR/$SDDM_THEME/faces"

    install_file "$PROFILE_SOURCE_DIR/viresta-dark-profile.png" "$THEMES_DIR/$THEME_DARK/contents/profile.png"
    install_file "$PROFILE_SOURCE_DIR/viresta-light-profile.png" "$THEMES_DIR/$THEME_LIGHT/contents/profile.png"

    "$THEME_SYNC_SCRIPT" --profile "$THEMES_DIR/$THEME_DARK/contents/profile.png"
    printf 'Configured the profile picture\n'

    [ -d "$SDDM_THEMES_DIR/$SDDM_THEME" ] || return 0
    sudo install -d -m755 "$theme_faces"
    sudo ln -sfn "$LOGIN_PROFILE_PICTURE" "$theme_faces/.face.icon"
    printf 'Linked %s to %s\n' "$theme_faces/.face.icon" "$LOGIN_PROFILE_PICTURE"
}

# ------------------------------------------------------------
# Removed themes
# ------------------------------------------------------------

# Updates would restore these themes, so a pacman hook removes them again.
remove_other_themes() {
    local package

    sudo rm -rf "${REMOVED_THEMES[@]}"
    printf 'Removed %s other theme files\n' "${#REMOVED_THEMES[@]}"

    sudo mkdir -p "$(dirname "$REMOVED_THEMES_HOOK")"
    {
        printf '[Trigger]\nOperation = Install\nOperation = Upgrade\nType = Package\n'
        for package in "${REMOVED_THEMES_PACKAGES[@]}"; do
            printf 'Target = %s\n' "$package"
        done
        printf '\n[Action]\nDescription = Removing themes Viresta does not use...\n'
        printf 'When = PostTransaction\nExec = /usr/bin/rm -rf %s\n' "${REMOVED_THEMES[*]}"
    } | sudo tee "$REMOVED_THEMES_HOOK" >/dev/null
    printf 'Installed %s\n' "$REMOVED_THEMES_HOOK"
}
