#!/usr/bin/env bash

# files.sh
# Removes what Viresta installed, for uninstall.sh.

# ------------------------------------------------------------
# Installed files
# ------------------------------------------------------------

# The list decides what gets deleted with rm -rf, so a bad line must not be able to
# take a whole folder of someone's files with it.
is_safe_to_remove() {
    case "$1" in
        "$HOME"|"$HOME/"|"$CONFIG_DIR"|"$DATA_DIR"|"$STATE_DIR"|"$HOME/.local"|"$HOME/.local/bin") return 1 ;;
        "$HOME/Pictures"|"$USER_WALLPAPERS_DIR"|"$ICONS_DIR"|"$THEMES_DIR"|"$PLASMA_STYLES_DIR") return 1 ;;
        /usr/share|/usr/share/icons|/usr/share/wallpapers|/etc|/etc/pacman.d|/var/lib|/var/lib/sddm) return 1 ;;
        */../*|*/..|*/./*) return 1 ;;
        "$HOME"/*|/usr/share/*|/etc/*|/var/lib/*|"$VIRESTA_COMMAND"|"$UPDATE_SCRIPT") return 0 ;;
        *) return 1 ;;
    esac
}

# One file that cannot be removed is listed at the end, and the rest still go.
remove_installed_files() {
    local path

    while IFS= read -r path; do
        [ -n "$path" ] || continue
        if ! is_safe_to_remove "$path"; then
            failure "Did not remove $path - it is not somewhere Viresta installs to"
        elif [ "${path#"$HOME"/}" != "$path" ]; then
            rm -rf -- "$path" 2>/dev/null || failure "Could not remove $path"
        else
            sudo rm -rf -- "$path" 2>/dev/null || failure "Could not remove $path"
        fi
    done <"$INSTALLED_FILES"
}

# ------------------------------------------------------------
# Other changes
# ------------------------------------------------------------

# Only Viresta's own picture. One the user chose stays.
remove_profile_picture() {
    if [ -f "$APPLIED_PROFILE_PICTURE" ] && cmp -s "$HOME/.face.icon" "$APPLIED_PROFILE_PICTURE"; then
        rm -f -- "$HOME/.face.icon"
    fi
}

# KDE writes these when a global theme is applied, and rebuilds the caches. Left in
# place, they could still point at Viresta's theme and apps.
remove_kde_theme_files() {
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}"

    rm -rf -- "${CONFIG_DIR:?}/kdedefaults" "${CONFIG_DIR:?}/ksplashrc"
    rm -rf -- "$cache"/ksycoca6_* "$cache"/icon-cache.kcache "$cache"/plasma-svgelements* "$cache"/plasma_theme_*
}

# Only Viresta's own value. A volume the user set stays.
remove_notification_volume() {
    [ -f "$WIREPLUMBER_STREAMS_FILE" ] || return 0
    local kept

    kept="$(grep -vxF "$(notification_volume_line)" "$WIREPLUMBER_STREAMS_FILE" || true)"
    printf '%s\n' "$kept" >"$WIREPLUMBER_STREAMS_FILE"
}

# Only Viresta's lines. If that leaves nothing, the file was only there for them.
remove_bash_setup() {
    remove_bashrc_lines
    if [ -f "$BASHRC_FILE" ] && [ ! -s "$BASHRC_FILE" ]; then
        rm -f -- "$BASHRC_FILE"
    fi
}

# Without a theme set, SDDM would fall back to its plain built-in login screen. This
# is the file KDE's own login screen settings write to.
set_kde_login_theme() {
    local file
    file="$(dirname "$SDDM_CONFIG_FILE")/kde_settings.conf"

    sudo test -e "$file" && return 0
    sudo mkdir -p "$(dirname "$file")"
    printf '[Theme]\nCurrent=%s\n' "$SDDM_THEME" | sudo tee "$file" >/dev/null
}

remove_viresta_files() {
    remove_profile_picture
    remove_installed_files
    remove_kde_theme_files
    remove_notification_volume
    remove_bash_setup
    set_kde_login_theme
}

# ------------------------------------------------------------
# Finishing
# ------------------------------------------------------------

restore_backup() {
    [ -d "$BACKUP_DIR" ] || return 0
    local file relative

    while IFS= read -r -d '' file; do
        relative="${file#"$BACKUP_DIR"/}"
        mkdir -p "$(dirname "$HOME/$relative")"
        cp -a -- "$file" "$HOME/$relative"
    done < <(find "$BACKUP_DIR" \( -type f -o -type l \) -print0)
}

# The uninstall's own logs stay, in case something needs looking into.
finish_uninstall() {
    restore_backup
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    rm -rf -- "${CONFIG_DIR:?}/viresta"
    find "$VIRESTA_STATE_DIR" -mindepth 1 -maxdepth 1 ! -name 'uninstall*' -exec rm -rf -- {} +
}
