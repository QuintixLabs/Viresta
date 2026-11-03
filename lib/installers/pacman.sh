#!/usr/bin/env bash

# pacman.sh
# Installs packages with pacman.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

PACMAN_CONF=""

# ------------------------------------------------------------
# Pacman
# ------------------------------------------------------------

cleanup_pacman_conf() {
    [ -n "${PACMAN_CONF:-}" ] || return 0
    rm -f "$PACMAN_CONF" 2>/dev/null || true
    PACMAN_CONF=""
}

# Uses a temporary config, so the real /etc/pacman.conf is never modified.
prepare_pacman_conf() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would limit downloads to one at a time"
        return 0
    fi

    PACMAN_CONF="$(mktemp /tmp/viresta-pacman.XXXXXX)"
    cp /etc/pacman.conf "$PACMAN_CONF"

    if grep -qE '^[#[:space:]]*ParallelDownloads' "$PACMAN_CONF"; then
        sed -i -E 's|^[#[:space:]]*ParallelDownloads.*|ParallelDownloads = 1|' "$PACMAN_CONF"
    else
        printf '\nParallelDownloads = 1\n' >>"$PACMAN_CONF"
    fi

    register_cleanup cleanup_pacman_conf
    ok "Downloads limited to one at a time"
}

# Normally writes only to the log. With --verbose it runs inside a pseudo-terminal
# so progress streams live.
run_pacman() {
    local -a args=(pacman)
    if [ -n "${PACMAN_CONF:-}" ]; then
        args+=(--config "$PACMAN_CONF")
    fi
    args+=("$@")

    if [ "$VERBOSE" -eq 0 ]; then
        sudo "${args[@]}" >>"$LOG_FILE" 2>&1 </dev/null
        return
    fi

    if command -v script >/dev/null 2>&1; then
        script -q -e -c "sudo ${args[*]}" /dev/null | tee -a "$LOG_FILE"
    else
        sudo "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
    fi
}

# ------------------------------------------------------------
# System update
# ------------------------------------------------------------

update_system() {
    prepare_pacman_conf

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would refresh archlinux-keyring"
        info "Would run a full system upgrade"
        return 0
    fi

    info "Refreshing archlinux-keyring"
    run_pacman -Sy --needed --noconfirm archlinux-keyring || die "Failed to refresh the keyring."

    info "Upgrading the system"
    run_pacman -Su --noconfirm || die "System upgrade failed."

    ok "System up to date"
}

# ------------------------------------------------------------
# Package lists
# ------------------------------------------------------------

_install_array() {
    local label="$1"
    shift
    local -a pkgs=("$@")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        info "$label: nothing to install"
        return 0
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "$label: would install ${pkgs[*]}"
        return 0
    fi

    info "$label: ${pkgs[*]}"
    run_pacman -S --needed --noconfirm "${pkgs[@]}" || die "Failed to install $label."
    ok "$label installed"
}

# One bad package makes pacman refuse the whole list, so after a failure the
# packages are tried one at a time to install everything that can be.
_install_array_optional() {
    local label="$1" pkg
    shift

    if [ "$#" -eq 0 ] || [ "${DRY_RUN:-0}" -eq 1 ]; then
        _install_array "$label" "$@"
        return 0
    fi

    info "$label: $*"
    if run_pacman -S --needed --noconfirm "$@"; then
        ok "$label installed"
        return 0
    fi

    for pkg in "$@"; do
        run_pacman -S --needed --noconfirm "$pkg" || failure "$pkg: install failed - see $LOG_FILE"
    done
}

_read_package_list() {
    [ -f "$1" ] || return 0
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true
}

# For packages the desktop can work without: failures are listed, not fatal.
install_group_optional() {
    local -a pkgs=()
    mapfile -t pkgs < <(_read_package_list "$2")
    _install_array_optional "$1" "${pkgs[@]}"
}

# For packages the desktop needs: a failure stops the install.
install_group() {
    local label="$1" file="$2"
    local -a pkgs=()

    mapfile -t pkgs < <(_read_package_list "$file")
    _install_array "$label" "${pkgs[@]}"
}

# ------------------------------------------------------------
# Package lookups
# ------------------------------------------------------------

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

pkg_source() {
    if pacman -Si "$1" >/dev/null 2>&1; then
        printf 'repo\n'
    else
        printf 'aur\n'
    fi
}
