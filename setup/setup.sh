#!/usr/bin/env bash

# setup.sh
# Puts the dots in place. install.sh runs this, and you can also run it by hand.

set -euo pipefail

SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=setup/shared/variables.sh
source "$SETUP_DIR/shared/variables.sh"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

usage() {
    cat <<'EOF'

Usage: setup.sh [options]

Install the Viresta configuration files into ~/.config, replacing what is there.
It follows what you chose in the install.sh menu. The normal KDE app launcher is used
when Vicinae is turned off or is not installed.

  --power-profile=laptop|desktop
                   Use this power profile instead of detecting the machine
  --update         What update.sh uses: keeps the user's own settings
  --list-replaced  List the existing configs an install would replace
  --back-up        Copy those configs, for uninstall.sh to put back

EOF
}

install_file() {
    install -Dm644 "$1" "$2"
    track "$2"
    printf 'Installed %s\n' "$2"
}

sudo_install_file() {
    sudo install -Dm644 "$1" "$2"
    track "$2"
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

# shellcheck source=setup/shared/tracking.sh
source "$SETUP_DIR/shared/tracking.sh"
# shellcheck source=setup/shared/shell.sh
source "$SETUP_DIR/shared/shell.sh"
# shellcheck source=setup/desktop/plasma.sh
source "$SETUP_DIR/desktop/plasma.sh"
# shellcheck source=setup/desktop/themes.sh
source "$SETUP_DIR/desktop/themes.sh"
# shellcheck source=setup/desktop/wallpapers.sh
source "$SETUP_DIR/desktop/wallpapers.sh"
# shellcheck source=setup/desktop/icons.sh
source "$SETUP_DIR/desktop/icons.sh"
# shellcheck source=setup/desktop/sound.sh
source "$SETUP_DIR/desktop/sound.sh"
# shellcheck source=setup/desktop/power.sh
source "$SETUP_DIR/desktop/power.sh"
# shellcheck source=setup/desktop/update-check.sh
source "$SETUP_DIR/desktop/update-check.sh"
# shellcheck source=setup/login/sddm.sh
source "$SETUP_DIR/login/sddm.sh"
# shellcheck source=setup/apps/vicinae.sh
source "$SETUP_DIR/apps/vicinae.sh"
# shellcheck source=setup/apps/firefox.sh
source "$SETUP_DIR/apps/firefox.sh"
# shellcheck source=setup/apps/fastfetch.sh
source "$SETUP_DIR/apps/fastfetch.sh"
# shellcheck source=setup/apps/obs.sh
source "$SETUP_DIR/apps/obs.sh"
# shellcheck source=setup/apps/shell.sh
source "$SETUP_DIR/apps/shell.sh"

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

install_config_categories() {
    local category

    while IFS= read -r -d '' category; do
        case "$(basename "$category")" in
            vicinae|sddm|icons|cursors|firefox|themes|profile|obs-studio|wallpapers|shell|updates)
                # Installed by their own functions.
                ;;
            kde)
                if [ "$SETUP_MODE" = "update" ]; then
                    install_tree "$KDE_SOURCE_DIR/taskbar/panel-colorizer" "$PANEL_COLORIZER_DIR"
                else
                    install_kde_configs
                fi
                ;;
            vscodium)
                install_shared_file "$category/settings.json" "$CONFIG_DIR/VSCodium/User/settings.json"
                ;;
            kitty)
                install_shared_tree "$category" "$CONFIG_DIR/kitty"
                ;;
            fastfetch)
                install_fastfetch
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
        enable_vicinae
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
    install_login_look
    install_sddm_config

    # Themes
    install_color_schemes
    install_global_themes
    install_theme_sync
    enable_theme_sync
    install_profile_pictures
    apply_profile_picture
    install_plasma_styles
    hide_app_styles
    remove_other_themes

    # Firefox
    install_firefox_policy

    # Fastfetch
    install_fastfetch_logo

    # OBS
    install_obs_config
    install_obs_launcher

    # Shell
    install_shell_setup

    # Sound
    install_notification_volume

    # Power
    install_power_profile

    # Update alerts
    install_update_check

    # Default wallpaper
    configure_wallpaper

    # Tracking
    finish_tracking
}

# Leaves out the user's KDE configs, wallpaper, login screen look, profile picture,
# notification volume and anything they have turned off.
update_configs() {
    command -v sudo >/dev/null 2>&1 || {
        printf 'sudo is required to install the dots\n' >&2
        return 1
    }

    mkdir -p "$(dirname "$UPDATE_NOTES_FILE")"
    : >"$UPDATE_NOTES_FILE"

    # Configs
    install_config_categories

    # App launcher
    if [ "$USE_VICINAE" -eq 1 ]; then
        install_vicinae
        install_vicinae_themes
    fi

    # Icons and cursors
    install_icon_themes
    install_cursor_themes
    install_default_cursor

    # Wallpapers
    install_new_wallpapers
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

    # OBS
    install_obs_launcher

    # Shell
    install_shell_setup

    # Update alerts
    install_update_check

    # Tracking
    track_kept_configs
    finish_tracking
}

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

# What the user chose in install.sh also applies when this is run by hand.
load_saved_options

for arg in "$@"; do
    case "$arg" in
        --power-profile=laptop|--power-profile=desktop) POWER_PROFILE="${arg#*=}" ;;
        --update) SETUP_MODE="update" ;;
        --list-replaced) list_replaced_configs; exit 0 ;;
        --back-up) back_up_configs; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

# Also covers a failed AUR build, which would otherwise leave no app launcher at all.
if ! command -v vicinae >/dev/null 2>&1; then
    USE_VICINAE=0
fi

if [ "$SETUP_MODE" = "update" ]; then
    update_configs
    exit 0
fi

install_configs
