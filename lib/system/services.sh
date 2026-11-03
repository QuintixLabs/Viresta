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

configure_sddm() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable sddm.service"
        return 0
    fi
    sudo systemctl enable sddm.service >/dev/null 2>&1 \
        || die "Failed to enable sddm.service."
    ok "sddm enabled (starts on next boot)"
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
    local -a setup_args=()
    [ "${INSTALL_VICINAE:-1}" -eq 1 ] || setup_args+=(--no-vicinae)
    [ "${INSTALL_RENAME_WALLPAPERS:-1}" -eq 1 ] || setup_args+=(--no-rename-wallpapers)

    errors="$(mktemp)"
    if [ "$VERBOSE" -eq 1 ]; then
        bash "$src" "${setup_args[@]}" 2>"$errors" || setup_status=$?
    else
        bash "$src" "${setup_args[@]}" >>"$LOG_FILE" 2>"$errors" || setup_status=$?
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
