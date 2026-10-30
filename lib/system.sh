#!/usr/bin/env bash
# Viresta - system checks, VM detection and sudo handling.
# Sourced by install.sh. Not meant to be executed directly.

sudoers_tmp="/etc/sudoers.d/viresta-temp"
_NOPASSWD_ACTIVE=0
VIRT="none"

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

detect_virt() {
    VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [ -n "$VIRT" ] || VIRT="none"
}

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

# Prints every package (2nd column) for a virt type from packages/vm.txt.
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

# Prints the first non-empty service (3rd column) for a virt type.
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

cleanup_nopasswd() {
    [ "$_NOPASSWD_ACTIVE" -eq 1 ] || return 0
    sudo -n rm -f "$sudoers_tmp" 2>/dev/null || true
    _NOPASSWD_ACTIVE=0
}

# Grants the current user passwordless sudo for the duration of this run only.
# The rule is validated with visudo and removed on any exit, including signals.
enable_nopasswd() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would ask for your password once"
        info "Would add a temporary NOPASSWD rule and remove it on exit"
        return 0
    fi

    printf '%s\n' "${ADMIN_PW:-}" | sudo -S -p '' -v 2>/dev/null \
        || die "sudo authentication failed."
    unset ADMIN_PW

    if sudo -n test -e "$sudoers_tmp" 2>/dev/null; then
        warn "Found leftover $sudoers_tmp from an interrupted run; removing"
        sudo rm -f "$sudoers_tmp"
    fi

    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${USER:-$(id -un)}" >"$tmp"

    if ! visudo -cf "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        die "Generated sudoers rule failed validation."
    fi

    sudo install -m 0440 -o root -g root "$tmp" "$sudoers_tmp"
    rm -f "$tmp"

    _NOPASSWD_ACTIVE=1
    register_cleanup cleanup_nopasswd
    ok "Passwordless sudo enabled for this run"
}
