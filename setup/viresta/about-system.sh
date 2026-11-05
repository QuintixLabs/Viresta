#!/usr/bin/env bash

# about-system.sh
# Shows the Viresta version in KDE's About this System, under the distro's own name.

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# Written again on every update, so it always shows the version that is installed. Only
# Variant is set, so the distro's own name, logo and website stay.
install_about_system() {
    local version

    version="$(tr -d '[:space:]' 2>/dev/null <"$REPO_DIR/VERSION" || true)"
    [ -n "$version" ] || return 0

    mkdir -p "$(dirname "$ABOUT_SYSTEM_FILE")"
    printf '[General]\nVariant=Viresta %s\n' "$version" >"$ABOUT_SYSTEM_FILE"
    track "$ABOUT_SYSTEM_FILE"
    printf 'Installed %s\n' "$ABOUT_SYSTEM_FILE"
}
