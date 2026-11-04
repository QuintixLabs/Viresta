#!/usr/bin/env bash

# tracking.sh
# Remembers what Viresta installs, and updates configs without losing user changes.

# ------------------------------------------------------------
# Installed files
# ------------------------------------------------------------

track() {
    mkdir -p "$(dirname "$INSTALLED_FILES")"
    printf '%s\n' "$1" >>"$INSTALLED_FILES"
}

# Everything that is not put in place by install_file or sudo_install_file.
track_other_files() {
    track "$CONFIG_DIR/kactivitymanagerdrc"
    track "$STATE_DIR/kactivitymanagerdstaterc"
    track "$POWER_CONFIG_FILE"
    track "$THEME_SYNC_SCRIPT"
    track "$THEMES_DIR/$THEME_DARK"
    track "$THEMES_DIR/$THEME_LIGHT"
    track "$PLASMA_STYLES_DIR/viresta-dark"
    track "$PLASMA_STYLES_DIR/viresta-light"
    track "$CONFIG_DIR/systemd/user/graphical-session.target.wants/$THEME_SYNC_UNIT"
    track "$VICINAE_UNIT_LINK"
    track "$ICONS_DIR/$ICON_THEME"
    track "$ICONS_DIR/$ICON_THEME_LIGHT"
    track "$CURSORS_DIR/$CURSOR_THEME"
    track "$FASTFETCH_DIR/logo.png"
    track "$USER_WALLPAPERS_DIR/rename_wallpapers.py"
    track "$(dirname "$LOGIN_WALLPAPER")"
    track "$WALLPAPER_DIR"
    track "$SDDM_USER_CONFIG_DIR/kdeglobals"
    track "$SDDM_THEMES_DIR/$SDDM_THEME/faces/.face.icon"
    track "$REMOVED_THEMES_HOOK"
    track "$DEFAULT_CURSOR_HOOK"
}

# Sorted with no repeats, since an update adds to the list from the install.
finish_tracking() {
    track_other_files
    sort -u -o "$INSTALLED_FILES" "$INSTALLED_FILES"
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

# Configs that would be replaced, so someone with an existing setup can keep a copy.
list_replaced_configs() {
    local source

    {
        while IFS= read -r -d '' source; do
            kde_config_target "$source"
        done < <(kde_config_sources)
        while IFS= read -r -d '' source; do
            printf '%s\n' "$CONFIG_DIR/kitty/${source#"$CONFIG_SOURCE_DIR/kitty/"}"
        done < <(find "$CONFIG_SOURCE_DIR/kitty" -type f -print0)
        printf '%s\n' \
            "$CONFIG_DIR/VSCodium/User/settings.json" \
            "$CONFIG_DIR/vicinae/settings.json" \
            "$FASTFETCH_DIR/config.jsonc" \
            "$POWER_CONFIG_FILE" \
            "$CONFIG_DIR/kactivitymanagerdrc" \
            "$STATE_DIR/kactivitymanagerdstaterc"
    } | while IFS= read -r source; do
        if [ -e "$source" ]; then
            printf '%s\n' "$source"
        fi
    done
}

# uninstall.sh puts these back. Only the first copy counts, as later ones are Viresta's.
back_up_configs() {
    local file target

    [ ! -e "$BACKUP_DIR" ] || return 0

    while IFS= read -r file; do
        target="$BACKUP_DIR/${file#"$HOME"/}"
        mkdir -p "$(dirname "$target")"
        cp -a "$file" "$target"
    done < <(list_replaced_configs)
}

# ------------------------------------------------------------
# Shared configs
# ------------------------------------------------------------

note() {
    mkdir -p "$(dirname "$UPDATE_NOTES_FILE")"
    printf '%s\n' "$1" >>"$UPDATE_NOTES_FILE"
}

save_base() {
    install -Dm644 "$1" "$BASE_DIR/${2#"$HOME"/}"
}

# A config the user may edit. The copy kept in BASE_DIR is how an update tells what
# they changed from what Viresta changed.
install_shared_file() {
    if [ "$SETUP_MODE" = "update" ]; then
        update_shared_file "$1" "$2"
    else
        install_file "$1" "$2"
    fi
    save_base "$1" "$2"
}

install_shared_tree() {
    local source

    while IFS= read -r -d '' source; do
        install_shared_file "$source" "$2/${source#"$1/"}"
    done < <(find "$1" -mindepth 1 -type f -print0)
}

update_shared_file() {
    local new="$1" target="$2"
    local base="$BASE_DIR/${target#"$HOME"/}"

    track "$target"

    if [ ! -e "$target" ]; then
        # Removed on purpose if a copy was installed before, so it stays removed.
        [ -e "$base" ] || install_file "$new" "$target"
    elif cmp -s "$target" "$new"; then
        rm -f "$target.viresta-new"
    elif [ ! -e "$base" ]; then
        keep_user_file "$new" "$target"
    elif cmp -s "$target" "$base"; then
        install_file "$new" "$target"
    elif cmp -s "$new" "$base"; then
        printf 'Viresta did not change %s\n' "$target"
    elif merge_settings "$base" "$target" "$new" || merge_lines "$base" "$target" "$new"; then
        printf 'Merged %s\n' "$target"
    else
        keep_user_file "$new" "$target"
    fi
}

keep_user_file() {
    install -m644 "$1" "$2.viresta-new"
    track "$2.viresta-new"
    note "Kept your ${2#"$HOME"/} - the new version is ${2#"$HOME"/}.viresta-new"
}

# Compares a JSON file setting by setting, so two changed settings next to each other
# are fine. Fails on anything jq cannot read, such as a file with comments.
merge_settings() {
    local base="$1" target="$2" new="$3"
    local merged temp_file

    case "$target" in
        *.json) ;;
        *) return 1 ;;
    esac

    merged="$(jq -n --slurpfile b "$base" --slurpfile u "$target" --slurpfile n "$new" '
        def absent: "__viresta_absent__";
        def get($k): if type == "object" and has($k) then .[$k] else absent end;
        def merge($b; $u; $n; $path):
            if $n == $b or $u == $n then {result: $u, kept: []}
            elif $u == $b then {result: $n, kept: []}
            elif ($b | type) == "object" and ($u | type) == "object" and ($n | type) == "object" then
                reduce (($b + $n) | keys_unsorted[]) as $k ({result: $u, kept: []};
                    merge($b | get($k); $u | get($k); $n | get($k); $path + [$k]) as $m
                    | .kept += $m.kept
                    | if $m.result == absent then .result |= del(.[$k]) else .result[$k] = $m.result end)
            else {result: $u, kept: [$path | join(".")]}
            end;
        merge($b[0]; $u[0]; $n[0]; [])
    ' 2>/dev/null)" || return 1

    temp_file="$(mktemp)"
    jq --indent 4 '.result' <<<"$merged" >"$temp_file"
    install -m644 "$temp_file" "$target"
    rm -f "$temp_file"

    while IFS= read -r temp_file; do
        note "Kept your $temp_file in ${target#"$HOME"/} - Viresta changed it too"
    done < <(jq -r '.kept[]' <<<"$merged")
}

# Compares a text file line by line. Where both changed the same or nearby lines, the
# user's stay, and everything else still arrives. The first run only counts those places.
merge_lines() {
    local temp_file clashes=0

    temp_file="$(mktemp)"
    git merge-file -p -q "$2" "$1" "$3" >/dev/null 2>&1 || clashes=$?

    # git reports an error, such as a binary file, as a number above 127.
    if [ "$clashes" -gt 127 ] || ! git merge-file -p -q --ours "$2" "$1" "$3" >"$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        return 1
    fi

    install -m644 "$temp_file" "$2"
    rm -f "$temp_file"
    if [ "$clashes" -gt 0 ]; then
        note "Kept some of your settings in ${2#"$HOME"/} - Viresta changed them too"
    fi
}
