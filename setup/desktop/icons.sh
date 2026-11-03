#!/usr/bin/env bash

# icons.sh
# Installs the icons and cursors.

# ------------------------------------------------------------
# Icons
# ------------------------------------------------------------

install_icon_themes() {
    local target_root="$ICONS_DIR/$ICON_THEME"
    local temp_dir

    temp_dir="$(mktemp -d)"
    if ! tar -xzf "$CONFIG_SOURCE_DIR/icons/yet-another-monochrome-icon-set.tar.gz" -C "$temp_dir"; then
        rm -rf "$temp_dir"
        printf 'Could not extract %s icon theme archive\n' "$ICON_THEME" >&2
        return 1
    fi

    install_tree "$temp_dir/$ICON_THEME" "$target_root"
    rm -rf "$temp_dir"

    # Fix Dolphin's KDE application icon name
    ln -sfn dolphin.svg "$target_root/apps/scalable/org.kde.dolphin.svg"
    printf 'Created Dolphin icon alias\n'

    # Only Vicinae needs the copy with dark icons.
    if [ "$USE_VICINAE" -eq 1 ]; then
        install_light_icon_theme "$target_root"
    fi
}

install_light_icon_theme() {
    local target_root="$ICONS_DIR/$ICON_THEME_LIGHT"

    rm -rf "$target_root"
    cp -a "$1" "$target_root"

    find "$target_root" -type f -name '*.svg' -exec \
        sed -i "s/\(\.ColorScheme-Text *{ *color: *\)#[0-9a-fA-F]*/\1$ICON_THEME_LIGHT_COLOR/g" {} +

    # Hidden keeps it out of the Icons page in System Settings.
    sed -i \
        -e "s/^Name=.*/Name=$ICON_THEME_LIGHT\nHidden=true/" \
        -e 's/^Inherits=.*/Inherits=Papirus,breeze,Cosmic,Adwaita,hicolor/' \
        "$target_root/index.theme"
    printf 'Created %s\n' "$target_root"
}

# ------------------------------------------------------------
# Cursors
# ------------------------------------------------------------

install_cursor_themes() {
    local source

    while IFS= read -r -d '' source; do
        sudo_install_file "$source" "$CURSORS_DIR/${source#"$CURSORS_SOURCE_DIR/"}"
    done < <(find "$CURSORS_SOURCE_DIR" -type f -print0)
}

# SDDM 0.21 cannot pass its CursorTheme setting to Qt, so the login screen uses the
# system's default cursor. default-cursors owns that file, so a pacman hook puts
# Bibata back after that package updates.
install_default_cursor() {
    local source="$CURSORS_DIR/Bibata/default-index.theme"
    local target="$CURSORS_DIR/default/index.theme"

    sudo_install_file "$source" "$target"

    sudo mkdir -p "$(dirname "$DEFAULT_CURSOR_HOOK")"
    {
        printf '[Trigger]\nOperation = Install\nOperation = Upgrade\nType = Package\n'
        printf 'Target = default-cursors\n'
        printf '\n[Action]\nDescription = Setting the default cursor to Bibata...\n'
        printf 'When = PostTransaction\nExec = /usr/bin/cp %s %s\n' "$source" "$target"
    } | sudo tee "$DEFAULT_CURSOR_HOOK" >/dev/null
    printf 'Installed %s\n' "$DEFAULT_CURSOR_HOOK"
}
