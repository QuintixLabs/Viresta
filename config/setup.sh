#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Settings: every path and name used more than once lives here.
# ---------------------------------------------------------------------------

# Options, set from what install.sh saved and the flags at the bottom of this file.
USE_VICINAE=1
USE_RENAME_WALLPAPERS=1

# Repository
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# User directories
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
APPLICATIONS_DIR="$DATA_DIR/applications"
ICONS_DIR="$DATA_DIR/icons"
COLOR_SCHEMES_DIR="$DATA_DIR/color-schemes"

# Plasma
PLASMA_LAYOUT_FILE="$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc"
LOCK_SCREEN_FILE="$CONFIG_DIR/kscreenlockerrc"
SHORTCUTS_FILE="$CONFIG_DIR/kglobalshortcutsrc"
SAVED_OPTIONS_FILE="$CONFIG_DIR/viresta/options"

# Global themes
THEMES_SOURCE_DIR="$SCRIPT_DIR/themes"
THEMES_DIR="$DATA_DIR/plasma/look-and-feel"
PLASMA_STYLES_DIR="$DATA_DIR/plasma/desktoptheme"
APP_STYLES_DIR="$DATA_DIR/kstyle/themes"
THEME_LAYOUT_NAME="org.kde.plasma.desktop-layout.js"
THEME_DARK="org.viresta.dark.desktop"
THEME_LIGHT="org.viresta.light.desktop"
THEME_SYNC_SCRIPT="$HOME/.local/bin/viresta-theme-sync"
THEME_SYNC_STATE_FILE="$STATE_DIR/viresta/applied-theme"
THEME_SYNC_UNIT="viresta-theme-sync.path"

# Themes hidden from Settings, and the packages that bring them back on update.
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
)
REMOVED_THEMES_PACKAGES=(aurorae breeze oxygen oxygen-cursors oxygen-icons plasma-workspace)
REMOVED_THEMES_HOOK="/etc/pacman.d/hooks/viresta-remove-themes.hook"

# Wallpapers: this is the only place that sets their names. The installed Plasma,
# lock screen, SDDM and global theme configs all get these paths written into them.
WALLPAPERS_SOURCE_DIR="$REPO_DIR/wallpapers"
WALLPAPER_DARK_SOURCE="$WALLPAPERS_SOURCE_DIR/Viresta Dark/01. Viresta.jpg"
WALLPAPER_LIGHT_SOURCE="$WALLPAPERS_SOURCE_DIR/Viresta Light/01. Viresta Light.jpg"
WALLPAPER_DIR="/usr/share/wallpapers/Viresta"
WALLPAPER_DARK="$WALLPAPER_DIR/Viresta Dark.jpg"
WALLPAPER_LIGHT="$WALLPAPER_DIR/Viresta Light.jpg"
# A link the user owns, so changing theme can change the login screen without root.
LOGIN_WALLPAPER="/var/lib/viresta/login-wallpaper.jpg"
# Same idea for the login screen's colors, which SDDM's own user reads as kdeglobals.
LOGIN_COLORS="/var/lib/viresta/login-colors"
LOGIN_PROFILE_PICTURE="/var/lib/viresta/login-profile"

# Profile pictures
PROFILE_SOURCE_DIR="$SCRIPT_DIR/profile/assets"
SDDM_USER_CONFIG_DIR="/var/lib/sddm/.config"
USER_WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
RENAME_WALLPAPERS_URL="https://raw.githubusercontent.com/fr0st-xyz/wallz/refs/heads/main/rename_wallpapers.py"

# Panel Colorizer
PANEL_COLORIZER_PRESET="Viresta-Dark"
PANEL_COLORIZER_PRESET_DIR="$CONFIG_DIR/panel-colorizer/presets/$PANEL_COLORIZER_PRESET"

# Cursors: System Settings does not look for cursor themes in ~/.local/share/icons.
CURSORS_SOURCE_DIR="$SCRIPT_DIR/cursors"
CURSORS_DIR="/usr/share/icons"

# Icons
ICON_THEME="YAMIS"
# Vicinae draws icons with their built-in color instead of following the color
# scheme, so light mode needs a copy of the theme with dark icons.
ICON_THEME_LIGHT="YAMIS-Light"
ICON_THEME_LIGHT_COLOR="#292724"
ICON_THEME_ARCHIVE="$SCRIPT_DIR/icons/yet-another-monochrome-icon-set.tar.gz"

# Vicinae
VICINAE_SOURCE_DIR="$SCRIPT_DIR/vicinae"
VICINAE_SYSTEM_THEMES_DIR="/usr/share/vicinae/themes"

# SDDM
SDDM_SOURCE_DIR="$SCRIPT_DIR/sddm"
SDDM_THEMES_DIR="/usr/share/sddm/themes"
SDDM_THEME="breeze"
SDDM_CONFIG_FILE="/etc/sddm.conf.d/viresta.conf"
SDDM_UNSUPPORTED_THEMES=(elarun maya maldives)

# Firefox
FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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

require_sudo() {
    command -v sudo >/dev/null 2>&1 && return 0
    printf 'sudo is required to %s\n' "$1" >&2
    return 1
}

# ---------------------------------------------------------------------------
# Wallpaper
# ---------------------------------------------------------------------------

install_wallpapers() {
    [ -d "$WALLPAPERS_SOURCE_DIR" ] || return 0

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

install_system_wallpapers() {
    local source

    require_sudo "install the Viresta wallpapers" || return 1

    for source in "$WALLPAPER_DARK_SOURCE" "$WALLPAPER_LIGHT_SOURCE"; do
        [ -f "$source" ] || {
            printf 'Viresta wallpaper not found at %s\n' "$source" >&2
            return 1
        }
    done

    sudo_install_file "$WALLPAPER_DARK_SOURCE" "$WALLPAPER_DARK"
    sudo_install_file "$WALLPAPER_LIGHT_SOURCE" "$WALLPAPER_LIGHT"
}

configure_wallpaper() {
    local file

    for file in "$PLASMA_LAYOUT_FILE" "$LOCK_SCREEN_FILE"; do
        [ -f "$file" ] || continue
        sed -i "s|^\(Preview\)\?Image=.*|\1Image=file://$WALLPAPER_DARK|" "$file"
        printf 'Configured wallpaper in %s\n' "$file"
    done
}

# ---------------------------------------------------------------------------
# Global themes
# ---------------------------------------------------------------------------

install_global_themes() {
    install_tree "$THEMES_SOURCE_DIR/look-and-feel" "$THEMES_DIR"

    sed -i "s|^Image=.*|Image=$WALLPAPER_DARK|" "$THEMES_DIR/$THEME_DARK/contents/defaults"
    sed -i "s|^Image=.*|Image=$WALLPAPER_LIGHT|" "$THEMES_DIR/$THEME_LIGHT/contents/defaults"

    install_theme_layout "$THEME_DARK" "$WALLPAPER_DARK"
    install_theme_layout "$THEME_LIGHT" "$WALLPAPER_LIGHT"
}

# install_theme_layout <theme> <wallpaper>
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

# A style is its color scheme on top of Breeze's shapes, the same way KDE builds
# Breeze Dark and Breeze Light.
install_plasma_styles() {
    install_tree "$THEMES_SOURCE_DIR/desktoptheme" "$PLASMA_STYLES_DIR"

    install_file "$SCRIPT_DIR/kde/appearance/color-schemes/VirestaDark.colors" "$PLASMA_STYLES_DIR/viresta-dark/colors"
    install_file "$SCRIPT_DIR/kde/appearance/color-schemes/VirestaLight.colors" "$PLASMA_STYLES_DIR/viresta-light/colors"
}

# Fusion and MS Windows 9x are built into Qt, so they can only be hidden from
# Settings. Union is hidden the same way rather than risk removing its package.
hide_app_styles() {
    install_tree "$THEMES_SOURCE_DIR/kstyle" "$APP_STYLES_DIR"
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
    require_sudo "install the login screen's profile picture" || return 1
    sudo install -d -m755 "$theme_faces"
    sudo ln -sfn "$LOGIN_PROFILE_PICTURE" "$theme_faces/.face.icon"
    printf 'Linked %s to %s\n' "$theme_faces/.face.icon" "$LOGIN_PROFILE_PICTURE"
}

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

# Updates would restore these themes, so a pacman hook removes them again.
remove_other_themes() {
    local package

    require_sudo "remove the other global themes" || return 1

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

# ---------------------------------------------------------------------------
# Plasma panel and activity
# ---------------------------------------------------------------------------

# Plasma destroys desktop containments whose activity does not exist, which
# drops the configured wallpaper. Register the activity the tracked layout uses
# so its desktop containment survives the first login.
configure_plasma_activity() {
    local activity_id

    [ -f "$PLASMA_LAYOUT_FILE" ] || {
        printf 'Plasma layout not found: %s\n' "$PLASMA_LAYOUT_FILE" >&2
        return 0
    }

    activity_id="$(sed -n 's/^activityId=\(..*\)$/\1/p' "$PLASMA_LAYOUT_FILE" | head -n 1)"

    [ -n "$activity_id" ] || {
        printf 'No activity set in %s\n' "$PLASMA_LAYOUT_FILE" >&2
        return 0
    }

    mkdir -p "$CONFIG_DIR" "$STATE_DIR"
    printf '[activities]\n%s=Default\n' "$activity_id" \
        >"$CONFIG_DIR/kactivitymanagerdrc"
    # Replaces any stale current activity, which the daemon would fail to restore.
    printf '[main]\ncurrentActivity=%s\n' "$activity_id" \
        >"$STATE_DIR/kactivitymanagerdstaterc"
    printf 'Configured Plasma activity: %s\n' "$activity_id"
}

# ---------------------------------------------------------------------------
# Panel Colorizer
# ---------------------------------------------------------------------------

# The widget reads its settings from the Plasma layout at startup, so the preset
# has to be written there for it to apply at login. The preset is the source of
# truth for globalSettings.
install_panel_colorizer_preset() {
    local settings temp_file

    [ -f "$PLASMA_LAYOUT_FILE" ] && [ -f "$PANEL_COLORIZER_PRESET_DIR/settings.json" ] || {
        printf 'Panel Colorizer preset or Plasma layout not found\n' >&2
        return 0
    }

    command -v jq >/dev/null 2>&1 || {
        printf 'jq is unavailable, skipping Panel Colorizer preset\n' >&2
        return 0
    }

    settings="$(jq -ce '.globalSettings' "$PANEL_COLORIZER_PRESET_DIR/settings.json")" || {
        printf 'Could not read Panel Colorizer preset: %s\n' "$PANEL_COLORIZER_PRESET_DIR" >&2
        return 0
    }

    temp_file="$(mktemp)"
    # Values go through ENVIRON because awk and sed would interpret them otherwise.
    SETTINGS="$settings" PRESET="$PANEL_COLORIZER_PRESET_DIR/" awk '
        /^globalSettings=/ { print "globalSettings=" ENVIRON["SETTINGS"]; next }
        /^lastPreset=/ { print "lastPreset=" ENVIRON["PRESET"]; next }
        { print }
    ' "$PLASMA_LAYOUT_FILE" >"$temp_file"
    install -m644 "$temp_file" "$PLASMA_LAYOUT_FILE"
    rm -f "$temp_file"
    printf 'Installed Panel Colorizer preset into %s\n' "$PLASMA_LAYOUT_FILE"
}

# ---------------------------------------------------------------------------
# KDE configs and color schemes
# ---------------------------------------------------------------------------

install_kde_configs() {
    local source_root="$SCRIPT_DIR/kde"
    local excluded_root="$source_root/appearance/color-schemes"
    local source relative

    [ -d "$source_root" ] || return 0

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        install_file "$source" "$CONFIG_DIR/${relative#*/}"
    done < <(
        find "$source_root" -mindepth 2 \
            \( -type f -o -type l \) \
            ! -path "$excluded_root/*" \
            -print0
    )
}

install_color_schemes() {
    local source_root="$SCRIPT_DIR/kde/appearance/color-schemes"

    [ -d "$source_root" ] || return 0
    install_tree "$source_root" "$COLOR_SCHEMES_DIR"
}

# ---------------------------------------------------------------------------
# Icons
# ---------------------------------------------------------------------------

install_icon_themes() {
    local target_root="$ICONS_DIR/$ICON_THEME"
    local apps_dir="$target_root/apps/scalable"
    local temp_dir

    temp_dir="$(mktemp -d)"
    if ! tar -xzf "$ICON_THEME_ARCHIVE" -C "$temp_dir"; then
        rm -rf "$temp_dir"
        printf 'Could not extract %s icon theme archive\n' "$ICON_THEME" >&2
        return 1
    fi

    install_tree "$temp_dir/$ICON_THEME" "$target_root"
    rm -rf "$temp_dir"

    # Fix Dolphin's KDE application icon name
    if [ -f "$apps_dir/dolphin.svg" ]; then
        ln -sfn dolphin.svg "$apps_dir/org.kde.dolphin.svg"
        printf 'Created Dolphin icon alias\n'
    fi

    # Only Vicinae needs the copy with dark icons.
    if [ "$USE_VICINAE" -eq 1 ]; then
        install_light_icon_theme "$target_root"
    fi
}

# install_light_icon_theme <dark theme directory>
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

install_cursor_themes() {
    local source

    require_sudo "install cursor themes" || return 1

    while IFS= read -r -d '' source; do
        sudo_install_file "$source" "$CURSORS_DIR/${source#"$CURSORS_SOURCE_DIR/"}"
    done < <(find "$CURSORS_SOURCE_DIR" -type f -print0)
}

# ---------------------------------------------------------------------------
# Vicinae
# ---------------------------------------------------------------------------

# The tracked configs are set up for Vicinae, so without it they get the normal KDE
# launcher back: Kickoff on the panel, and the shortcuts Vicinae had taken over.
use_kde_launcher() {
    local temp_file

    rm -rf "$CONFIG_DIR/systemd/user/vicinae.service.d"

    temp_file="$(mktemp)"
    awk '
        /^\[Containments\]\[2\]\[Applets\]\[4\]$/ {
            print "[Containments][2][Applets][3]"
            print "immutability=1"
            print "plugin=org.kde.plasma.kickoff"
            print ""
        }
        /^AppletOrder=/ { sub(/=/, "=3;") }
        /^launchers=/ { sub(/applications:viresta-vicinae\.desktop,/, "") }
        { print }
    ' "$PLASMA_LAYOUT_FILE" >"$temp_file"
    install -m644 "$temp_file" "$PLASMA_LAYOUT_FILE"

    awk '
        /^\[/ { skip = ($0 ~ /viresta-vicinae/ || $0 ~ /org\.kde\.plasma\.emojier/) }
        skip { next }
        /^activate application launcher=/ { sub(/=Alt\+F1,/, "=Meta\\tAlt+F1,") }
        /^show-on-mouse-pos=/ { sub(/=none,/, "=Meta+V,") }
        { print }
    ' "$SHORTCUTS_FILE" >"$temp_file"
    install -m644 "$temp_file" "$SHORTCUTS_FILE"

    rm -f "$temp_file"
    printf 'Configured the KDE app launcher instead of Vicinae\n'
}

install_vicinae() {
    local source

    [ -d "$VICINAE_SOURCE_DIR" ] || return 0

    if [ -f "$VICINAE_SOURCE_DIR/settings.json" ]; then
        install_file "$VICINAE_SOURCE_DIR/settings.json" "$CONFIG_DIR/vicinae/settings.json"
    fi

    if [ -d "$VICINAE_SOURCE_DIR/applications" ]; then
        while IFS= read -r -d '' source; do
            install_file "$source" "$APPLICATIONS_DIR/$(basename "$source")"
        done < <(find "$VICINAE_SOURCE_DIR/applications" -maxdepth 1 -type f -name '*.desktop' -print0)
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

install_vicinae_themes() {
    local source_root="$VICINAE_SOURCE_DIR/themes"
    local source

    [ -d "$source_root" ] || return 0
    require_sudo "install Vicinae themes" || return 1

    while IFS= read -r -d '' source; do
        sudo_install_file "$source" "$VICINAE_SYSTEM_THEMES_DIR/${source#"$source_root/"}"
    done < <(find "$source_root" -type f -print0)
}

# ---------------------------------------------------------------------------
# SDDM
# ---------------------------------------------------------------------------

install_sddm_config() {
    local theme_config="$SDDM_THEMES_DIR/$SDDM_THEME/theme.conf.user"

    require_sudo "install the SDDM configuration" || return 1

    if [ -d "$SDDM_THEMES_DIR/$SDDM_THEME" ]; then
        if [ -f "$SDDM_SOURCE_DIR/theme.conf.user" ]; then
            sudo_install_file "$SDDM_SOURCE_DIR/theme.conf.user" "$theme_config"
            sudo sed -i "s|^background=.*|background=$LOGIN_WALLPAPER|" "$theme_config"
        fi
    else
        printf 'SDDM theme %s is not installed; skipping theme override\n' "$SDDM_THEME" >&2
    fi

    sudo install -d -m755 -o "$(id -un)" "$(dirname "$LOGIN_WALLPAPER")"
    ln -sfn "$WALLPAPER_DARK" "$LOGIN_WALLPAPER"
    printf 'Linked %s to %s\n' "$LOGIN_WALLPAPER" "$WALLPAPER_DARK"

    # The Viresta Plasma styles are in the user's home, which SDDM cannot read, so
    # plasmarc selects the style that follows the colors in kdeglobals.
    install -m644 "$SCRIPT_DIR/kde/appearance/color-schemes/VirestaDark.colors" "$LOGIN_COLORS"
    printf '\n[General]\nfont=%s\n' "$(sed -n 's/^font=//p' "$SCRIPT_DIR/kde/appearance/kdeglobals")" >>"$LOGIN_COLORS"
    sudo install -d -m755 -o sddm -g sddm "$SDDM_USER_CONFIG_DIR"
    sudo ln -sfn "$LOGIN_COLORS" "$SDDM_USER_CONFIG_DIR/kdeglobals"
    sudo_install_file "$SDDM_SOURCE_DIR/plasmarc" "$SDDM_USER_CONFIG_DIR/plasmarc"
    # Without this the login screen's Qt integration falls back to the Breeze cursor.
    sudo_install_file "$SCRIPT_DIR/kde/appearance/kcminputrc" "$SDDM_USER_CONFIG_DIR/kcminputrc"
    printf 'Linked %s to %s\n' "$SDDM_USER_CONFIG_DIR/kdeglobals" "$LOGIN_COLORS"

    if [ -f "$SDDM_SOURCE_DIR/viresta.conf" ]; then
        sudo_install_file "$SDDM_SOURCE_DIR/viresta.conf" "$SDDM_CONFIG_FILE"
    fi
}

remove_unsupported_sddm_themes() {
    local theme

    require_sudo "remove unsupported SDDM themes" || return 1

    for theme in "${SDDM_UNSUPPORTED_THEMES[@]}"; do
        if [ -d "$SDDM_THEMES_DIR/$theme" ]; then
            sudo rm -rf "${SDDM_THEMES_DIR:?}/$theme"
            printf 'Removed unsupported SDDM theme: %s\n' "$theme"
        fi
    done
}

# ---------------------------------------------------------------------------
# Firefox
# ---------------------------------------------------------------------------

install_firefox_policy() {
    local policy="$SCRIPT_DIR/firefox/policies.json"

    [ -f "$policy" ] || return 0
    require_sudo "install Firefox policies" || return 1
    sudo_install_file "$policy" "$FIREFOX_POLICY_FILE"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

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
                if [ -f "$category/settings.json" ]; then
                    install_file "$category/settings.json" "$CONFIG_DIR/VSCodium/User/settings.json"
                fi
                ;;
            systemd)
                install_tree "$category" "$CONFIG_DIR/systemd/user"
                ;;
            *)
                install_tree "$category" "$CONFIG_DIR/$(basename "$category")"
                ;;
        esac
    done < <(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
}

install_configs() {
    install_config_categories

    configure_plasma_activity
    install_panel_colorizer_preset
    if [ "$USE_VICINAE" -eq 1 ]; then
        install_vicinae
        install_vicinae_themes
    else
        use_kde_launcher
    fi
    install_icon_themes
    install_cursor_themes
    install_wallpapers
    install_system_wallpapers
    install_sddm_config
    remove_unsupported_sddm_themes
    install_color_schemes
    install_global_themes
    install_theme_sync
    install_profile_pictures
    install_plasma_styles
    hide_app_styles
    remove_other_themes
    install_firefox_policy
    configure_wallpaper
}

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
