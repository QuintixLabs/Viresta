#!/usr/bin/env bash

# services.sh
# Turns on system services and runs the setup.

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------

configure_networkmanager() {
    [ -e /usr/lib/systemd/system/NetworkManager.service ] || return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable NetworkManager"
        return 0
    fi
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 \
        && ok "NetworkManager enabled" \
        || failure "Could not enable NetworkManager"
}

# The login screen that is on now, like plasmalogin, or nothing.
current_login_manager() {
    local target

    target="$(readlink "$DISPLAY_MANAGER_LINK" 2>/dev/null)" || return 0
    target="${target##*/}"
    printf '%s\n' "${target%.service}"
}

# systemd refuses a second login screen, so one that is on is turned off first, and
# remembered for uninstall.sh.
configure_sddm() {
    local current

    current="$(current_login_manager)"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        if [ -n "$current" ] && [ "$current" != sddm ]; then
            info "Would switch the login screen from $current to SDDM"
        fi
        info "Would enable sddm.service"
        return 0
    fi

    if [ -n "$current" ] && [ "$current" != sddm ]; then
        sudo systemctl disable "$current.service" >/dev/null 2>&1 \
            || die "Could not turn off $current, the login screen that is on now."
        mkdir -p "$(dirname "$LOGIN_MANAGER_BEFORE_FILE")"
        printf '%s\n' "$current" >"$LOGIN_MANAGER_BEFORE_FILE"
        ok "Switched the login screen from $current to SDDM"
    fi

    sudo systemctl enable sddm.service >/dev/null 2>&1 \
        || die "Failed to enable sddm.service."
    ok "sddm enabled (starts on next boot)"
}

# For uninstall.sh. If the old one cannot be turned on, SDDM stays, so there is always
# a login screen.
restore_login_manager() {
    local before

    [ -s "$LOGIN_MANAGER_BEFORE_FILE" ] || return 0
    before="$(cat "$LOGIN_MANAGER_BEFORE_FILE")"

    sudo systemctl disable sddm.service >/dev/null 2>&1 || true
    if sudo systemctl enable "$before.service" >/dev/null 2>&1; then
        ok "Turned $before back on as your login screen"
    else
        sudo systemctl enable sddm.service >/dev/null 2>&1 || true
        failure "Could not turn $before back on, so SDDM stays your login screen"
    fi
}

# ------------------------------------------------------------
# Dots
# ------------------------------------------------------------

# The default SDDM session is set by config/sddm/viresta.conf.
configure_kde_configs() {
    local src="${SCRIPT_DIR}/setup/setup.sh"

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would install KDE configuration files into ${XDG_CONFIG_HOME:-$HOME/.config}"
        return 0
    fi

    # setup.sh reports what it could not do on stderr without stopping.
    local errors line setup_status=0

    errors="$(mktemp)"
    if [ "$VERBOSE" -eq 1 ]; then
        bash "$src" "$@" 2>"$errors" || setup_status=$?
    else
        bash "$src" "$@" >>"$LOG_FILE" 2>"$errors" || setup_status=$?
    fi

    while IFS= read -r line; do
        failure "$line"
    done <"$errors"
    rm -f "$errors"

    if [ "$setup_status" -ne 0 ]; then
        failure "Could not install KDE configuration files"
        return 0
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 \
            || failure "Could not reload the user systemd manager"
    fi

    ok "KDE and systemd-user configuration files installed"
}

# ------------------------------------------------------------
# VSCodium
# ------------------------------------------------------------

configure_vscodium() {
    local file="${SCRIPT_DIR}/config/vscodium/extensions.txt"
    local command_name=""
    local extension

    [ -f "$file" ] || return 0

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would install VSCodium extensions from $file"
        return 0
    fi

    if command -v codium >/dev/null 2>&1; then
        command_name="codium"
    elif command -v vscodium >/dev/null 2>&1; then
        command_name="vscodium"
    else
        warn "VSCodium command not found; skipping extensions"
        return 0
    fi

    while IFS= read -r extension || [ -n "$extension" ]; do
        extension="${extension%%#*}"
        extension="$(printf '%s' "$extension" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -n "$extension" ] || continue

        "$command_name" --install-extension "$extension" \
            >/dev/null 2>&1 \
            || failure "Could not install VSCodium extension: $extension"
    done <"$file"

    ok "VSCodium extensions installed"
}
