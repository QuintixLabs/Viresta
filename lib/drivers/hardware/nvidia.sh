#!/usr/bin/env bash

# nvidia.sh
# Picks the driver for an NVIDIA card, and does what only that driver needs.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

KERNEL_MODULES_DIR="${KERNEL_MODULES_DIR:-/usr/lib/modules}"
NVIDIA_MKINITCPIO_CONF="/etc/mkinitcpio.conf.d/10-viresta-nvidia.conf"
# Which NVIDIA cards need which driver, from CachyOS's chwd (GPL-3.0). A card on neither
# list is newer than both, and uses the current driver.
NVIDIA_580XX_IDS="$SCRIPT_DIR/packages/nvidia/nvidia-580xx.ids"
NVIDIA_OLD_IDS="$SCRIPT_DIR/packages/nvidia/nouveau.ids"

# ------------------------------------------------------------
# Choosing the driver
# ------------------------------------------------------------

# The row in drivers.txt for a card. nvidia-old has no row, since those cards stay on the
# nouveau driver that is already in the kernel.
nvidia_hardware() {
    local id

    id="$(cat "$1/device")"
    id="${id#0x}"
    if grep -qwF "$id" "$NVIDIA_580XX_IDS" 2>/dev/null; then
        printf 'nvidia-580xx\n'
    elif grep -qwF "$id" "$NVIDIA_OLD_IDS" 2>/dev/null; then
        printf 'nvidia-old\n'
    else
        printf 'nvidia\n'
    fi
}

# Whatever NVIDIA driver is there may have been chosen on purpose, and swapping a working
# driver is an easy way to break the desktop.
has_nvidia_driver() {
    pacman -Qq 2>/dev/null \
        | grep -Eqx 'nvidia|nvidia-dkms|nvidia-lts|nvidia-open|nvidia-open-dkms|nvidia-open-lts|nvidia-lts-open|nvidia-[0-9]+xx-dkms'
}

has_nvidia_to_install() {
    has_hardware nvidia || has_hardware nvidia-580xx
}

# Two NVIDIA cards share one driver, and the older one also runs newer cards.
settle_nvidia_hardware() {
    if has_hardware nvidia-580xx; then
        remove_hardware nvidia
    fi
    if has_nvidia_driver; then
        remove_hardware nvidia
        remove_hardware nvidia-580xx
        remove_hardware nvidia-old
    fi
    if has_nvidia_to_install && is_hybrid_laptop; then
        HARDWARE+=(nvidia-laptop)
    fi
}

# ------------------------------------------------------------
# Kernel headers
# ------------------------------------------------------------

# The NVIDIA driver is built for every kernel that has its headers. Each kernel names
# its own package in a file next to its modules.
kernel_headers() {
    local file found=0

    for file in "$KERNEL_MODULES_DIR"/*/pkgbase; do
        [ -e "$file" ] || continue
        printf '%s-headers\n' "$(cat "$file")"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        printf 'linux-headers\n'
    fi
}

install_kernel_headers() {
    local -a pkgs=()

    mapfile -t pkgs < <(kernel_headers | sort -u)

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would install ${pkgs[*]}"
        return 0
    fi

    info "Installing ${pkgs[*]}"
    if ! run_pacman -S --needed --noconfirm "${pkgs[@]}"; then
        failure "Could not install ${pkgs[*]}, which the NVIDIA driver needs - see $LOG_FILE"
        return 1
    fi
}

# ------------------------------------------------------------
# Boot image
# ------------------------------------------------------------

# Taking kms out of the boot image stops nouveau loading before the NVIDIA driver can.
# Only done once a driver is really there, or a system without one would lose nouveau
# during early boot for nothing.
setup_nvidia_boot() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would add $NVIDIA_MKINITCPIO_CONF and rebuild the boot image"
        return 0
    fi

    if ! is_installed nvidia-open-dkms && ! is_installed nvidia-580xx-dkms; then
        return 0
    fi
    # Other tools build the boot image differently, and nvidia-utils still blocks nouveau
    # after the first reboot.
    command -v mkinitcpio >/dev/null 2>&1 || return 0

    info "Rebuilding the boot image for the NVIDIA driver"
    printf 'HOOKS=(${HOOKS[@]/kms/})\n' | sudo install -Dm644 /dev/stdin "$NVIDIA_MKINITCPIO_CONF"
    # The log belongs to the user, so it is written as the user on purpose.
    # shellcheck disable=SC2024
    if ! sudo mkinitcpio -P >>"$LOG_FILE" 2>&1; then
        failure "Could not rebuild the boot image. To try again: sudo mkinitcpio -P"
        return 1
    fi
}
