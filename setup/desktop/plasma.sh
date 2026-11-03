#!/usr/bin/env bash

# plasma.sh
# Sets up the KDE configs, panel and Panel Colorizer.

# ------------------------------------------------------------
# KDE configs
# ------------------------------------------------------------

install_kde_configs() {
    local source relative

    while IFS= read -r -d '' source; do
        relative="${source#"$KDE_SOURCE_DIR/"}"
        install_file "$source" "$CONFIG_DIR/${relative#*/}"
    done < <(
        find "$KDE_SOURCE_DIR" -mindepth 2 \
            \( -type f -o -type l \) \
            ! -path "$COLOR_SCHEMES_SOURCE_DIR/*" \
            -print0
    )
}

# ------------------------------------------------------------
# Activity
# ------------------------------------------------------------

# Plasma destroys desktop containments whose activity does not exist, which
# drops the configured wallpaper. Register the activity the tracked layout uses
# so its desktop containment survives the first login.
configure_plasma_activity() {
    local activity_id

    activity_id="$(sed -n 's/^activityId=\(..*\)$/\1/p' "$PLASMA_LAYOUT_FILE" | head -n 1)"

    mkdir -p "$CONFIG_DIR" "$STATE_DIR"
    printf '[activities]\n%s=Default\n' "$activity_id" \
        >"$CONFIG_DIR/kactivitymanagerdrc"
    # Replaces any stale current activity, which the daemon would fail to restore.
    printf '[main]\ncurrentActivity=%s\n' "$activity_id" \
        >"$STATE_DIR/kactivitymanagerdstaterc"
    printf 'Configured Plasma activity: %s\n' "$activity_id"
}

# ------------------------------------------------------------
# Panel Colorizer
# ------------------------------------------------------------

# The widget reads its settings from the Plasma layout at startup, so the preset
# has to be written there for it to apply at login. The preset is the source of
# truth for globalSettings.
install_panel_colorizer_preset() {
    local settings temp_file

    settings="$(jq -ce '.globalSettings' "$PANEL_COLORIZER_PRESET_DIR/settings.json")"

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

# ------------------------------------------------------------
# KDE app launcher
# ------------------------------------------------------------

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
