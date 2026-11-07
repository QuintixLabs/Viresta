#!/usr/bin/env bash

# banner.sh
# Tests the version in KDE's About this System.

source "$(dirname "$0")/../shared/helpers.sh"

copy_viresta

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
rm "$VIRESTA/VERSION" "$FILE"
is "about: no VERSION file, no error" "$(about 2>&1)" ""
missing "about: no VERSION file, no file" "$FILE"

finish
