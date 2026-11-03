#!/usr/bin/env bash

# setup.sh
# Puts the dots in place. install.sh runs this, and you can also run it by hand.

set -euo pipefail

SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=setup/variables.sh
source "$SETUP_DIR/variables.sh"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: setup.sh [--no-vicinae] [--no-rename-wallpapers]

Install the Viresta configuration files into ~/.config. The normal KDE app
launcher is used when Vicinae is turned off or is not installed.
EOF
}

install_file() {
    install -Dm644 "$1" "$2"
    printf 'Installed %s\n' "$2"
}

sudo_install_file() {
    sudo install -Dm644 "$1" "$2"
    printf 'Installed %s\n' "$2"
}

install_tree() {
    local source_root="$1"
    local target_root="$2"
    local source

    while IFS= read -r -d '' source; do
        install_file "$source" "$target_root/${source#"$source_root/"}"
    done < <(find "$source_root" -mindepth 1 \( -type f -o -type l \) -print0)
}

# ------------------------------------------------------------
# Parts
# ------------------------------------------------------------

# shellcheck source=setup/desktop/plasma.sh
source "$SETUP_DIR/desktop/plasma.sh"
# shellcheck source=setup/desktop/themes.sh
source "$SETUP_DIR/desktop/themes.sh"
# shellcheck source=setup/desktop/wallpapers.sh
source "$SETUP_DIR/desktop/wallpapers.sh"
# shellcheck source=setup/desktop/icons.sh
source "$SETUP_DIR/desktop/icons.sh"
# shellcheck source=setup/login/sddm.sh
source "$SETUP_DIR/login/sddm.sh"
# shellcheck source=setup/apps/vicinae.sh
source "$SETUP_DIR/apps/vicinae.sh"
# shellcheck source=setup/apps/firefox.sh
source "$SETUP_DIR/apps/firefox.sh"

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

install_config_categories() {
    local category

    while IFS= read -r -d '' category; do
        case "$(basename "$category")" in
            vicinae|sddm|icons|cursors|firefox|themes|profile)
                # Installed by their own functions.
                ;;
            kde)
                install_kde_configs
                ;;
            vscodium)
                install_file "$category/settings.json" "$CONFIG_DIR/VSCodium/User/settings.json"
                ;;
            systemd)
                install_tree "$category" "$CONFIG_DIR/systemd/user"
                ;;
            *)
                install_tree "$category" "$CONFIG_DIR/$(basename "$category")"
                ;;
        esac
    done < <(find "$CONFIG_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
}

install_configs() {
    command -v sudo >/dev/null 2>&1 || {
        printf 'sudo is required to install the dots\n' >&2
        return 1
    }

    # Configs
    install_config_categories

    # Panel
    configure_plasma_activity
    install_panel_colorizer_preset

    # App launcher
    if [ "$USE_VICINAE" -eq 1 ]; then
        install_vicinae
        install_vicinae_themes
    else
        use_kde_launcher
    fi

    # Icons and cursors
    install_icon_themes
    install_cursor_themes
    install_default_cursor

    # Wallpapers
    install_wallpapers
    install_system_wallpapers

    # Login screen
    install_sddm_config

    # Themes
    install_color_schemes
    install_global_themes
    install_theme_sync
    install_profile_pictures
    install_plasma_styles
    hide_app_styles
    remove_other_themes

    # Firefox
    install_firefox_policy

    # Default wallpaper
    configure_wallpaper
}

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

# What the user chose in install.sh also applies when this is run by hand.
if grep -qx 'vicinae=0' "$SAVED_OPTIONS_FILE" 2>/dev/null; then
    USE_VICINAE=0
fi
if grep -qx 'rename_wallpapers=0' "$SAVED_OPTIONS_FILE" 2>/dev/null; then
    USE_RENAME_WALLPAPERS=0
fi

for arg in "$@"; do
    case "$arg" in
        --no-vicinae) USE_VICINAE=0 ;;
        --no-rename-wallpapers) USE_RENAME_WALLPAPERS=0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

# Also covers a failed AUR build, which would otherwise leave no app launcher at all.
if ! command -v vicinae >/dev/null 2>&1; then
    USE_VICINAE=0
fi

install_configs
