#!/usr/bin/env bash

# vm.sh
# Detects the VM and installs its packages and services.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

VIRT="none"

# ------------------------------------------------------------
# Detection
# ------------------------------------------------------------

detect_virt() {
    VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [ -n "$VIRT" ] || VIRT="none"
}

vm_pkgs_for() {
    local virt="$1" file="$SCRIPT_DIR/packages/vm.txt"
    [ -f "$file" ] || return 0
    while read -r v pkg _svc; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$virt" ] && [ -n "$pkg" ]; then
            printf '%s\n' "$pkg"
        fi
    done <"$file"
}

vm_service_for() {
    local virt="$1" file="$SCRIPT_DIR/packages/vm.txt"
    [ -f "$file" ] || return 0
    while read -r v _pkg svc; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$virt" ] && [ -n "$svc" ]; then
            printf '%s\n' "$svc"
            return 0
        fi
    done <"$file"
}

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------

install_vm_extras() {
    local -a pkgs=()
    mapfile -t pkgs < <(vm_pkgs_for "$VIRT")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        info "No VM packages for $VIRT"
        return 0
    fi

    local pkg source
    for pkg in "${pkgs[@]}"; do
        source="$(pkg_source "$pkg")"

        if [ "$source" = "repo" ]; then
            if [ "${DRY_RUN:-0}" -eq 1 ]; then
                info "Would install $pkg (repository)"
                continue
            fi
            info "$pkg: installing"
            run_pacman -S --needed --noconfirm "$pkg" || failure "$pkg: install failed - see $LOG_FILE"
        else
            _aur_install_one "$pkg" || true
        fi
    done

    return 0
}

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------

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
        || failure "Could not enable $svc"
}
