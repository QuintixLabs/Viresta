#!/usr/bin/env bash
# Viresta - pacman setup and package list installation.
# Sourced by install.sh. Not meant to be executed directly.

PACMAN_CONF=""

cleanup_pacman_conf() {
    [ -n "${PACMAN_CONF:-}" ] || return 0
    rm -f "$PACMAN_CONF" 2>/dev/null || true
    PACMAN_CONF=""
}

# Creates a temporary pacman config with ParallelDownloads = 1 so packages
# download one at a time. The real /etc/pacman.conf is never modified.
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

# run_pacman <pacman args...>
# Runs pacman inside a pseudo-terminal so progress streams live, and tees it.
run_pacman() {
    local -a args=(pacman)
    if [ -n "${PACMAN_CONF:-}" ]; then
        args+=(--config "$PACMAN_CONF")
    fi
    args+=("$@")

    if command -v script >/dev/null 2>&1; then
        script -q -e -c "sudo ${args[*]}" /dev/null | tee -a "$LOG_FILE"
    else
        sudo "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
    fi
}

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

# _install_array <label> <pkg...>
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

# install_group <label> <package-list-file>
install_group() {
    local label="$1" file="$2"
    local -a pkgs=()

    if [ -f "$file" ]; then
        mapfile -t pkgs < <(
            sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" |
                grep -v '^$'
        )
    fi

    _install_array "$label" "${pkgs[@]}"
}

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

# pkg_source <package>
# Prints "repo" if pacman knows the package, otherwise "aur".
# The lookup is silent on purpose - nothing is shown or logged.
pkg_source() {
    if pacman -Si "$1" >/dev/null 2>&1; then
        printf 'repo\n'
    else
        printf 'aur\n'
    fi
}
