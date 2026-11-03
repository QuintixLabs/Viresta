#!/usr/bin/env bash

# vicinae.sh
# Installs the Vicinae config and themes.

install_vicinae() {
    local source

    install_shared_file "$VICINAE_SOURCE_DIR/settings.json" "$CONFIG_DIR/vicinae/settings.json"

    while IFS= read -r -d '' source; do
        install_file "$source" "$DATA_DIR/applications/$(basename "$source")"
    done < <(find "$VICINAE_SOURCE_DIR/applications" -maxdepth 1 -type f -name '*.desktop' -print0)

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

# Starts the server at login, so the first press of Meta can open the window.
enable_vicinae() {
    mkdir -p "$(dirname "$VICINAE_UNIT_LINK")"
    ln -sfn "$VICINAE_UNIT_FILE" "$VICINAE_UNIT_LINK"
    printf 'Enabled %s\n' "$VICINAE_UNIT"
}

install_vicinae_themes() {
    local source_root="$VICINAE_SOURCE_DIR/themes"
    local source

    while IFS= read -r -d '' source; do
        sudo_install_file "$source" "$VICINAE_SYSTEM_THEMES_DIR/${source#"$source_root/"}"
    done < <(find "$source_root" -type f -print0)
}
