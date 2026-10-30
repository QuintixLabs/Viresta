#!/usr/bin/env bash
# Viresta - services, login session and desktop theme.
# Sourced by install.sh. Not meant to be executed directly.

configure_networkmanager() {
    [ -e /usr/lib/systemd/system/NetworkManager.service ] || return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable NetworkManager"
        return 0
    fi
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 \
        && ok "NetworkManager enabled" \
        || warn "Could not enable NetworkManager"
}

configure_vm_services() {
    local svc
    svc="$(vm_service_for "$VIRT")"
    [ -n "$svc" ] || return 0

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable $svc"
        return 0
    fi

    sudo systemctl enable "$svc" >/dev/null 2>&1 \
        && ok "Enabled $svc" \
        || warn "Could not enable $svc"
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

configure_default_session() {
    local sess=''
    local first
    first="$(ls /usr/share/wayland-sessions/*.desktop 2>/dev/null | head -n1 || true)"
    if [ -n "$first" ]; then
        sess="$(basename "$first" .desktop)"
    fi
    [ -n "$sess" ] || sess="plasma"

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would set the SDDM default session to $sess (Wayland)"
        return 0
    fi

    sudo mkdir -p /etc/sddm.conf.d
    printf '[Users]\nDefaultSession=%s\n' "$sess" |
        sudo tee /etc/sddm.conf.d/10-viresta.conf >/dev/null
    ok "Default session: $sess (Wayland)"
}

# Installs the tracked KDE configuration files into the user's config directory.
configure_kde_configs() {
    local src="${SCRIPT_DIR}/config/kde/setup.sh"

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would install KDE configuration files into ${XDG_CONFIG_HOME:-$HOME/.config}"
        return 0
    fi

    if [ ! -f "$src" ]; then
        warn "Missing $src; skipping KDE configuration setup"
        return 0
    fi

    bash "$src" || {
        warn "Could not install KDE configuration files"
        return 0
    }

    ok "KDE configuration files installed"
}
