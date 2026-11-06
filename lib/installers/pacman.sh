#!/usr/bin/env bash

# pacman.sh
# Installs packages with pacman.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

PACMAN_CONF=""
SYSTEM_PACMAN_CONF="${SYSTEM_PACMAN_CONF:-/etc/pacman.conf}"
# What was already on the system, so uninstall.sh keeps it.
PACKAGES_BEFORE_FILE="$VIRESTA_STATE_DIR/packages-before"
# What Viresta has offered, so update.sh only adds new ones and does not bring back
# an app the user removed.
KNOWN_PACKAGES_FILE="$VIRESTA_STATE_DIR/known-packages"

# ------------------------------------------------------------
# Pacman
# ------------------------------------------------------------

cleanup_pacman_conf() {
    [ -n "${PACMAN_CONF:-}" ] || return 0
    rm -f "$PACMAN_CONF" 2>/dev/null || true
    PACMAN_CONF=""
}

# Uses a temporary copy, so the faster downloads only last for the install.
prepare_pacman_conf() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would download 5 packages at a time"
        return 0
    fi

    # Made again each time, so a repository turned on since then is in the copy too.
    cleanup_pacman_conf
    PACMAN_CONF="$(mktemp /tmp/viresta-pacman.XXXXXX)"
    cp "$SYSTEM_PACMAN_CONF" "$PACMAN_CONF"

    if grep -qE '^[#[:space:]]*ParallelDownloads' "$PACMAN_CONF"; then
        sed -i -E 's|^[#[:space:]]*ParallelDownloads.*|ParallelDownloads = 5|' "$PACMAN_CONF"
    else
        printf '\nParallelDownloads = 5\n' >>"$PACMAN_CONF"
    fi

    register_cleanup cleanup_pacman_conf
    ok "Downloading 5 packages at a time"
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
        # The log belongs to the user, so it is written as the user on purpose.
        # shellcheck disable=SC2024
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
# Repositories
# ------------------------------------------------------------

# Steam, Wine and many games need Arch's 32-bit repository, which is off by default. It
# is turned on the Arch Wiki's way, by taking the # off its two lines, and added only if
# those lines are not there. uninstall.sh leaves it on, since anything installed from it
# would stop getting updates.
enable_multilib() {
    [ -f "$SYSTEM_PACMAN_CONF" ] || return 0
    grep -q '^\[multilib\]' "$SYSTEM_PACMAN_CONF" && return 0

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would turn on the multilib repository, for 32-bit apps like Steam"
        return 0
    fi

    sudo sed -i '/^#\[multilib\]$/{N;s/^#\[multilib\]\n#Include/[multilib]\nInclude/}' "$SYSTEM_PACMAN_CONF"
    if ! grep -q '^\[multilib\]' "$SYSTEM_PACMAN_CONF"; then
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a "$SYSTEM_PACMAN_CONF" >/dev/null
    fi

    if grep -q '^\[multilib\]' "$SYSTEM_PACMAN_CONF"; then
        ok "multilib repository turned on"
    else
        failure "Could not turn on the multilib repository in $SYSTEM_PACMAN_CONF"
    fi
}

# ------------------------------------------------------------
# System update
# ------------------------------------------------------------

# multilib comes first, so the update below also downloads its package list.
update_system() {
    enable_multilib
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

install_array() {
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
install_array_optional() {
    local label="$1" pkg
    shift

    if [ "$#" -eq 0 ] || [ "${DRY_RUN:-0}" -eq 1 ]; then
        install_array "$label" "$@"
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

read_package_list() {
    [ -f "$1" ] || return 0
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true
}

# For packages the desktop can work without: failures are listed, not fatal.
install_group_optional() {
    local -a pkgs=()
    mapfile -t pkgs < <(read_package_list "$2")
    install_array_optional "$1" "${pkgs[@]}"
}

# For packages the desktop needs: a failure stops the install.
install_group() {
    local label="$1" file="$2"
    local -a pkgs=()

    mapfile -t pkgs < <(read_package_list "$file")
    install_array "$label" "${pkgs[@]}"
}

# ------------------------------------------------------------
# Package records
# ------------------------------------------------------------

save_packages_before() {
    [ "${DRY_RUN:-0}" -eq 0 ] || return 0
    [ ! -e "$PACKAGES_BEFORE_FILE" ] || return 0
    mkdir -p "$(dirname "$PACKAGES_BEFORE_FILE")"
    pacman -Qq >"$PACKAGES_BEFORE_FILE" 2>/dev/null || true
}

# The 32-bit drivers count too, so an update does not bring back one that was removed.
# The Gaming row does not, since updates never add it.
listed_packages() {
    local list

    for list in system/base system/kde apps/pacman apps/aur; do
        read_package_list "$SCRIPT_DIR/packages/$list.txt"
    done
    read_package_list "$SCRIPT_DIR/packages/drivers/drivers.txt" | awk '$2 ~ /^lib32-/ { print $2 }'
}

save_known_packages() {
    [ "${DRY_RUN:-0}" -eq 0 ] || return 0
    mkdir -p "$(dirname "$KNOWN_PACKAGES_FILE")"
    listed_packages | sort -u >"$KNOWN_PACKAGES_FILE"
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
