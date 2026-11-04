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
    while read -r v _pkg svc _replaces; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$virt" ] && [ -n "$svc" ]; then
            printf '%s\n' "$svc"
            return 0
        fi
    done <"$file"
}

vm_replaces_for() {
    local virt="$1" wanted="$2" file="$SCRIPT_DIR/packages/vm.txt"
    [ -f "$file" ] || return 0
    while read -r v pkg _svc replaces _rest; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$virt" ] && [ "$pkg" = "$wanted" ] && [ -n "$replaces" ] && [ "$replaces" != "-" ]; then
            printf '%s\n' "$replaces"
            return 0
        fi
    done <"$file"
}

vm_flags_for() {
    local virt="$1" wanted="$2" file="$SCRIPT_DIR/packages/vm.txt"
    [ -f "$file" ] || return 0
    while read -r v pkg _svc _replaces flags; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$virt" ] && [ "$pkg" = "$wanted" ] && [ -n "$flags" ]; then
            printf '%s\n' "$flags"
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

    local pkg old
    for pkg in "${pkgs[@]}"; do
        old="$(vm_replaces_for "$VIRT" "$pkg")"

        if [ -n "$old" ]; then
            replace_vm_package "$pkg" "$old" || true
        else
            install_vm_package "$pkg" || true
        fi
    done

    return 0
}

install_vm_package() {
    local pkg="$1"

    if [ "$(pkg_source "$pkg")" != "repo" ]; then
        aur_install_one "$pkg" "$(vm_flags_for "$VIRT" "$pkg")"
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

# Some distros come with a package that clashes with the one in vm.txt, and neither
# pacman nor paru replaces a package with --noconfirm. The name is compared because
# pacman also answers for a package that only provides it. If the install fails the
# old package comes back, so the VM still has tools.
replace_vm_package() {
    local pkg="$1" old="$2"

    if [ "${DRY_RUN:-0}" -eq 1 ] || [ "$(pacman -Qq "$old" 2>/dev/null)" != "$old" ]; then
        install_vm_package "$pkg"
        return
    fi

    info "$old: replacing with $pkg"
    if ! run_pacman -Rdd --noconfirm "$old"; then
        failure "$pkg: could not remove $old - see $LOG_FILE"
        return 1
    fi

    install_vm_package "$pkg" && return 0

    run_pacman -S --needed --noconfirm "$old" \
        || failure "Could not bring back $old. To try again: sudo pacman -S $old"
    return 1
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
