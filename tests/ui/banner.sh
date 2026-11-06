#!/usr/bin/env bash

# banner.sh
# Tests the banner and the lines on screen: the version next to the logo, the lines all
# the same width, and the version in KDE's About this System.

source "$(dirname "$0")/../shared/helpers.sh"

copy_viresta

banner_lines() {
    (
        SCRIPT_DIR="$VIRESTA"
        source "$VIRESTA/lib/load.sh"
        ui_colors
        banner
    ) 2>&1 | strip_colors
}

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

echo 1.0.0 >"$VIRESTA/VERSION"
out="$(banner_lines)"
is "the version is after the logo" "$(sed -n 4p <<<"$out")" "  ▀   ▀ ▀     ▀▀▀ ▀▀▀    ▀▀  ▀▀▀▀ v1.0.0"
is "the top of the logo is unchanged" "$(sed -n 2p <<<"$out")" "█   █ ▀ ▄ ▄▄  ▄▄   ▄▄▄ ▄█▄   ▄▄▄"
is "then a blank line and the tagline" "$(sed -n '5,6p' <<<"$out" | paste -sd'|')" "|The clean, stable and user-friendly dots for everyone!"

echo 10.12.3 >"$VIRESTA/VERSION"
is "a longer version" "$(banner_lines | sed -n 4p)" "  ▀   ▀ ▀     ▀▀▀ ▀▀▀    ▀▀  ▀▀▀▀ v10.12.3"

rm "$VIRESTA/VERSION"
is "no VERSION file: no version" "$(banner_lines | sed -n 4p)" "  ▀   ▀ ▀     ▀▀▀ ▀▀▀    ▀▀  ▀▀▀▀"
lines_without="$(banner_lines | wc -l)"
echo 1.0.0 >"$VIRESTA/VERSION"
is "no VERSION file: the same lines" "$lines_without" "$(banner_lines | wc -l)"

widths="$(
    SCRIPT_DIR="$VIRESTA"
    source "$VIRESTA/lib/load.sh"
    banner | sed -n '6,7p'
    hr
)"
is "the tagline and both lines are as wide" "$(awk '{ print length }' <<<"$widths" | paste -sd' ')" "54 54 54"

# ------------------------------------------------------------
# About this System
# ------------------------------------------------------------

about() {
    (
        SETUP_DIR="$VIRESTA/setup"
        source "$SETUP_DIR/shared/variables.sh"
        source "$SETUP_DIR/shared/tracking.sh"
        source "$SETUP_DIR/viresta/about-system.sh"
        install_about_system >/dev/null
    )
}
FILE="$HOME/.config/kcm-about-distrorc"

echo 1.0.0 >"$VIRESTA/VERSION"
about
is "about: the version" "$(cat "$FILE")" $'[General]\nVariant=Viresta 1.0.0'
is "about: on the uninstall list" "$(grep -c -x "$FILE" "$HOME/.local/state/viresta/installed-files")" "1"
echo 1.1.0 >"$VIRESTA/VERSION"
about
is "about: an update changes it" "$(cat "$FILE")" $'[General]\nVariant=Viresta 1.1.0'
rm "$VIRESTA/VERSION" "$FILE"
is "about: no VERSION file, no error" "$(about 2>&1)" ""
missing "about: no VERSION file, no file" "$FILE"

finish
