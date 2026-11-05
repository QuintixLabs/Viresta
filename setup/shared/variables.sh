#!/usr/bin/env bash

# variables.sh
# Paths and names used by the setup scripts.
# This is for developing the dots, not a user setting.

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

# What is ticked in the install menu. What the user chose last time is read over these.
# Anything starting with USE_ is saved as an option, so only options should start with it.
USE_VICINAE=1
USE_RENAME_WALLPAPERS=1
USE_DRIVERS=1
# Not in the menu. ./update.sh --notifications-off and --notifications-on change it.
USE_UPDATE_NOTIFICATIONS=1
# "update" leaves out what belongs to the user and merges the shared configs.
SETUP_MODE="install"

# ------------------------------------------------------------
# Repository
# ------------------------------------------------------------

REPO_DIR="$(dirname "$SETUP_DIR")"
CONFIG_SOURCE_DIR="$REPO_DIR/config"
KDE_SOURCE_DIR="$CONFIG_SOURCE_DIR/kde"
COLOR_SCHEMES_SOURCE_DIR="$KDE_SOURCE_DIR/appearance/color-schemes"
THEMES_SOURCE_DIR="$CONFIG_SOURCE_DIR/themes"
PROFILE_SOURCE_DIR="$CONFIG_SOURCE_DIR/profile/assets"
CURSOR_THEME="Bibata"
CURSORS_ARCHIVE="$CONFIG_SOURCE_DIR/cursors/$CURSOR_THEME.tar.xz"
VICINAE_SOURCE_DIR="$CONFIG_SOURCE_DIR/vicinae"
SDDM_SOURCE_DIR="$CONFIG_SOURCE_DIR/sddm"
WALLPAPERS_SOURCE_DIR="$CONFIG_SOURCE_DIR/wallpapers"
SHELL_SOURCE_DIR="$CONFIG_SOURCE_DIR/shell"
UPDATE_CHECK_SOURCE="$CONFIG_SOURCE_DIR/updates/viresta-update-check"

# ------------------------------------------------------------
# User folders
# ------------------------------------------------------------

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
ICONS_DIR="$DATA_DIR/icons"
USER_WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
SAVED_OPTIONS_FILE="$CONFIG_DIR/viresta/options"

# ------------------------------------------------------------
# Tracking
# ------------------------------------------------------------

VIRESTA_STATE_DIR="$STATE_DIR/viresta"
INSTALLED_FILES="$VIRESTA_STATE_DIR/installed-files"
BASE_DIR="$VIRESTA_STATE_DIR/base"
BACKUP_DIR="$VIRESTA_STATE_DIR/backup"
UPDATE_NOTES_FILE="$VIRESTA_STATE_DIR/update-notes"
BASHRC_ADDED_FILE="$VIRESTA_STATE_DIR/bashrc-added"
VIRESTA_FOLDER_FILE="$VIRESTA_STATE_DIR/folder"
NOTIFIED_VERSION_FILE="$VIRESTA_STATE_DIR/notified-version"

# ------------------------------------------------------------
# Update alerts
# ------------------------------------------------------------

UPDATE_CHECK_SCRIPT="$HOME/.local/bin/viresta-update-check"
UPDATE_CHECK_UNIT="viresta-update-check.timer"

# ------------------------------------------------------------
# About this System
# ------------------------------------------------------------

# KDE's own file for this. It adds to the distro's details instead of changing them.
ABOUT_SYSTEM_FILE="$CONFIG_DIR/kcm-about-distrorc"

# ------------------------------------------------------------
# Plasma
# ------------------------------------------------------------

PLASMA_LAYOUT_FILE="$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc"
LOCK_SCREEN_FILE="$CONFIG_DIR/kscreenlockerrc"
SHORTCUTS_FILE="$CONFIG_DIR/kglobalshortcutsrc"
PANEL_COLORIZER_DIR="$CONFIG_DIR/panel-colorizer"
# Used by both themes: it takes its colors from the color scheme.
PANEL_COLORIZER_PRESET_DIR="$PANEL_COLORIZER_DIR/presets/Viresta"

# ------------------------------------------------------------
# Global themes
# ------------------------------------------------------------

THEMES_DIR="$DATA_DIR/plasma/look-and-feel"
PLASMA_STYLES_DIR="$DATA_DIR/plasma/desktoptheme"
THEME_LAYOUT_NAME="org.kde.plasma.desktop-layout.js"
THEME_DARK="org.viresta.dark.desktop"
THEME_LIGHT="org.viresta.light.desktop"
THEME_SYNC_SCRIPT="$HOME/.local/bin/viresta-theme-sync"
THEME_SYNC_STATE_FILE="$VIRESTA_STATE_DIR/applied-theme"
APPLIED_PROFILE_PICTURE="$VIRESTA_STATE_DIR/applied-profile"
THEME_SYNC_UNIT="viresta-theme-sync.path"

# ------------------------------------------------------------
# Removed themes
# ------------------------------------------------------------

# Removed from the system, and the packages that bring them back on update.
REMOVED_THEMES=(
    /usr/share/plasma/look-and-feel/org.kde.air
    /usr/share/plasma/look-and-feel/org.kde.breezetwilight.desktop
    /usr/share/plasma/look-and-feel/org.kde.oxygen
    /usr/share/plasma/look-and-feel/org.kde.oxygenlight
    /usr/share/plasma/desktoptheme/air
    /usr/share/plasma/desktoptheme/oxygen
    /usr/share/wallpapers/Air
    /usr/share/wallpapers/Horos
    /usr/share/color-schemes/BreezeClassic.colors
    /usr/share/color-schemes/Oxygen.colors
    /usr/share/color-schemes/OxygenCold.colors
    /usr/share/color-schemes/OxygenDark.colors
    /usr/share/icons/oxygen
    /usr/share/icons/KDE_Classic
    /usr/share/icons/Oxygen_Black
    /usr/share/icons/Oxygen_Blue
    /usr/share/icons/Oxygen_White
    /usr/share/icons/Oxygen_Yellow
    /usr/share/icons/Oxygen_Zion
    /usr/share/kwin/decorations/kwin4_decoration_qml_plastik
    /usr/lib/qt6/plugins/org.kde.kdecoration3/org.kde.oxygen.so
    /usr/lib/qt6/plugins/org.kde.kdecoration3.kcm/kcm_oxygendecoration.so
    /usr/lib/qt6/plugins/styles/oxygen6.so
    /usr/lib/qt6/plugins/kstyle_config/kstyle_oxygen_config.so
    /usr/share/kstyle/themes/oxygen.themerc
    /usr/share/sddm/themes/elarun
    /usr/share/sddm/themes/maya
    /usr/share/sddm/themes/maldives
)
REMOVED_THEMES_PACKAGES=(aurorae breeze oxygen oxygen-cursors oxygen-icons plasma-workspace sddm)
REMOVED_THEMES_HOOK="/etc/pacman.d/hooks/viresta-remove-themes.hook"

# ------------------------------------------------------------
# Wallpapers
# ------------------------------------------------------------

# This is the only place that sets their names. The installed Plasma,
# lock screen, SDDM and global theme configs all get these paths written into them.
WALLPAPER_DARK_SOURCE="$WALLPAPERS_SOURCE_DIR/Viresta Dark/01. Viresta Dark.jpg"
WALLPAPER_LIGHT_SOURCE="$WALLPAPERS_SOURCE_DIR/Viresta Light/01. Viresta Light.jpg"
WALLPAPER_DIR="/usr/share/wallpapers/Viresta"
WALLPAPER_DARK="$WALLPAPER_DIR/Viresta Dark.jpg"
WALLPAPER_LIGHT="$WALLPAPER_DIR/Viresta Light.jpg"
RENAME_WALLPAPERS_URL="https://raw.githubusercontent.com/fr0st-xyz/wallz/refs/heads/main/rename_wallpapers.py"

# ------------------------------------------------------------
# Icons and cursors
# ------------------------------------------------------------

# System Settings does not look for cursor themes in
# ~/.local/share/icons, so they go in the system folder.
ICON_THEME="YAMIS"
# Vicinae draws icons with their built-in color instead of following the color
# scheme, so light mode needs a copy of the theme with dark icons.
ICON_THEME_LIGHT="YAMIS-Light"
ICON_THEME_LIGHT_COLOR="#292724"
CURSORS_DIR="/usr/share/icons"
DEFAULT_CURSOR_HOOK="/etc/pacman.d/hooks/viresta-default-cursor.hook"

# ------------------------------------------------------------
# Vicinae
# ------------------------------------------------------------

VICINAE_SYSTEM_THEMES_DIR="/usr/share/vicinae/themes"
VICINAE_UNIT="vicinae.service"
VICINAE_UNIT_FILE="/usr/lib/systemd/user/$VICINAE_UNIT"
VICINAE_UNIT_LINK="$CONFIG_DIR/systemd/user/graphical-session.target.wants/$VICINAE_UNIT"

# ------------------------------------------------------------
# Login screen
# ------------------------------------------------------------

# The files in /var/lib/viresta belong to the user, so changing theme
# can change the login screen without asking for a password.
SDDM_THEMES_DIR="/usr/share/sddm/themes"
SDDM_THEME="breeze"
SDDM_CONFIG_FILE="/etc/sddm.conf.d/viresta.conf"
SDDM_USER_CONFIG_DIR="/var/lib/sddm/.config"
LOGIN_WALLPAPER="/var/lib/viresta/login-wallpaper.jpg"
LOGIN_COLORS="/var/lib/viresta/login-colors"
LOGIN_PROFILE_PICTURE="/var/lib/viresta/login-profile"

# ------------------------------------------------------------
# Power
# ------------------------------------------------------------

POWER_SOURCE_DIR="$KDE_SOURCE_DIR/power"
POWER_CONFIG_FILE="$CONFIG_DIR/powerdevilrc"
POWER_SUPPLY_DIR="/sys/class/power_supply"
# Empty means it is detected. --power-profile in setup.sh sets it.
POWER_PROFILE=""
# Matches when the screen turns off while plugged in.
LAPTOP_LOCK_MINUTES=20

# ------------------------------------------------------------
# Sound
# ------------------------------------------------------------

# 75% on the slider. The slider works on a curve, so this is 0.75 cubed.
NOTIFICATION_VOLUME="0.421875"
NOTIFICATION_VOLUME_KEY="Output/Audio:media.role:Notification"
WIREPLUMBER_STREAMS_FILE="$STATE_DIR/wireplumber/stream-properties"

# ------------------------------------------------------------
# Firefox
# ------------------------------------------------------------

FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"

# ------------------------------------------------------------
# Fastfetch
# ------------------------------------------------------------

FASTFETCH_DIR="$CONFIG_DIR/fastfetch"

# ------------------------------------------------------------
# OBS
# ------------------------------------------------------------

OBS_CONFIG_FILE="$CONFIG_DIR/obs-studio/user.ini"
OBS_DESKTOP_SOURCE="/usr/share/applications/com.obsproject.Studio.desktop"
OBS_DESKTOP_FILE="$DATA_DIR/applications/com.obsproject.Studio.desktop"

# ------------------------------------------------------------
# Saved options
# ------------------------------------------------------------

# A line like vicinae=0 sets USE_VICINAE=0. A damaged line is skipped.
load_saved_options() {
    local option value

    [ -f "$SAVED_OPTIONS_FILE" ] || return 0

    while IFS='=' read -r option value || [ -n "$option" ]; do
        if [[ "$option" =~ ^[a-z_]+$ && "$value" =~ ^[01]$ ]]; then
            printf -v "USE_${option^^}" '%s' "$value"
        fi
    done <"$SAVED_OPTIONS_FILE"
}

# Changes one option and leaves the others as they are.
save_option() {
    local kept

    mkdir -p "$(dirname "$SAVED_OPTIONS_FILE")"
    kept="$(grep -v "^$1=" "$SAVED_OPTIONS_FILE" 2>/dev/null || true)"
    {
        if [ -n "$kept" ]; then
            printf '%s\n' "$kept"
        fi
        printf '%s=%s\n' "$1" "$2"
    } >"$SAVED_OPTIONS_FILE"
}
