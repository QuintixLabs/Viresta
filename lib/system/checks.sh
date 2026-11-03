#!/usr/bin/env bash

# checks.sh
# Checks the system can run the install.

# ------------------------------------------------------------
# Requirements
# ------------------------------------------------------------

require_non_root() {
    [ "$(id -u)" -ne 0 ] || die "Do not run this installer as root. Run it as your normal user."
}

require_sudo() {
    command -v sudo >/dev/null 2>&1 || die "sudo is required but not installed."
}

require_arch() {
    [ -f /etc/arch-release ] || die "This installer only supports Arch Linux."
}

require_x86_64() {
    [ "$(uname -m)" = "x86_64" ] || die "Only x86_64 is supported (detected: $(uname -m))."
}

# ------------------------------------------------------------
# Internet
# ------------------------------------------------------------

has_internet() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 6 bash -c 'exec 3<>/dev/tcp/archlinux.org/443' 2>/dev/null && return 0
    fi
    command -v ping >/dev/null 2>&1 && ping -c1 -W2 archlinux.org >/dev/null 2>&1 && return 0
    return 1
}

require_internet() {
    has_internet || die "No internet connection detected."
}

# ------------------------------------------------------------
# All checks
# ------------------------------------------------------------

preflight() {
    require_non_root
    require_sudo
    require_arch
    require_x86_64
    require_internet
    detect_virt

    ok "Arch Linux x86_64"
    ok "Internet reachable"
    if [ "$VIRT" = "none" ]; then
        info "Running on bare metal"
    else
        info "Virtual machine detected: $VIRT"
    fi
}
