#!/usr/bin/env bash

# gaming.sh
# Installs the Gaming row from the install menu: Steam and the tools for running and
# tuning games.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

GAMING_FILE="$SCRIPT_DIR/packages/apps/gaming.txt"

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# Steam needs a 32-bit Vulkan driver, and with nothing there pacman picks the first one it
# knows, which may be for another card. So the matching ones come first, and a VM gets
# the software one.
install_gaming() {
    local pkg

    install_32bit_drivers
    if [ "${DRY_RUN:-0}" -eq 0 ] && ! pacman -T lib32-vulkan-driver >/dev/null 2>&1; then
        install_gaming_package lib32-vulkan-swrast || true
    fi

    while IFS= read -r pkg; do
        install_gaming_package "$pkg" || true
    done < <(read_package_list "$GAMING_FILE")

    join_gamemode_group
}

install_gaming_package() {
    local pkg="$1"

    is_installed "$pkg" && return 0

    if [ "$(pkg_source "$pkg")" != "repo" ]; then
        aur_install_one "$pkg"
        return
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would install $pkg (repository)"
        return 0
    fi

    info "$pkg: installing"
    if ! run_pacman -S --needed --noconfirm "$pkg"; then
        failure "$pkg: install failed - see $LOG_FILE"
        return 1
    fi
}

# GameMode can only raise a game's priority for someone in its group. It counts from the
# next login, and the install ends with a reboot anyway.
join_gamemode_group() {
    local user

    user="$(id -un)"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would add $user to the gamemode group"
        return 0
    fi

    getent group gamemode >/dev/null 2>&1 || return 0
    id -nG "$user" | grep -qw gamemode && return 0

    if sudo usermod -aG gamemode "$user"; then
        ok "Added $user to the gamemode group"
    else
        failure "Could not add $user to the gamemode group. To try again: sudo usermod -aG gamemode $user"
    fi
}
