#!/usr/bin/env bash

# variables.sh
# Paths and names used by the setup scripts.
# This is for developing the dots, not a user setting.

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

# Set from what install.sh saved and the flags in setup.sh.
USE_VICINAE=1
USE_RENAME_WALLPAPERS=1

# ------------------------------------------------------------
# Repository
# ------------------------------------------------------------

REPO_DIR="$(dirname "$SETUP_DIR")"
CONFIG_SOURCE_DIR="$REPO_DIR/config"
KDE_SOURCE_DIR="$CONFIG_SOURCE_DIR/kde"
COLOR_SCHEMES_SOURCE_DIR="$KDE_SOURCE_DIR/appearance/color-schemes"
THEMES_SOURCE_DIR="$CONFIG_SOURCE_DIR/themes"
PROFILE_SOURCE_DIR="$CONFIG_SOURCE_DIR/profile/assets"
CURSORS_SOURCE_DIR="$CONFIG_SOURCE_DIR/cursors"
VICINAE_SOURCE_DIR="$CONFIG_SOURCE_DIR/vicinae"
SDDM_SOURCE_DIR="$CONFIG_SOURCE_DIR/sddm"
WALLPAPERS_SOURCE_DIR="$REPO_DIR/wallpapers"

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
# Plasma
# ------------------------------------------------------------

PLASMA_LAYOUT_FILE="$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc"
LOCK_SCREEN_FILE="$CONFIG_DIR/kscreenlockerrc"
SHORTCUTS_FILE="$CONFIG_DIR/kglobalshortcutsrc"
# Used by both themes: it takes its colors from the color scheme.
PANEL_COLORIZER_PRESET_DIR="$CONFIG_DIR/panel-colorizer/presets/Viresta"

# ------------------------------------------------------------
# Global themes
# ------------------------------------------------------------

THEMES_DIR="$DATA_DIR/plasma/look-and-feel"
PLASMA_STYLES_DIR="$DATA_DIR/plasma/desktoptheme"
THEME_LAYOUT_NAME="org.kde.plasma.desktop-layout.js"
THEME_DARK="org.viresta.dark.desktop"
THEME_LIGHT="org.viresta.light.desktop"
THEME_SYNC_SCRIPT="$HOME/.local/bin/viresta-theme-sync"
THEME_SYNC_STATE_FILE="$STATE_DIR/viresta/applied-theme"
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
WALLPAPER_DARK_SOURCE="$WALLPAPERS_SOURCE_DIR/Viresta Dark/01. Viresta.jpg"
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
# Firefox
# ------------------------------------------------------------

FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"
