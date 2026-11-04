#!/usr/bin/env bash

# install.sh
# Installs the drivers and services for the hardware that hardware/detect.sh found.

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

# Only what is not installed yet, so a system with its drivers has nothing to ask about.
missing_drivers() {
    local hardware pkg

    for hardware in "${HARDWARE[@]}"; do
        while IFS= read -r pkg; do
            if ! is_installed "$pkg"; then
                printf '%s\n' "$pkg"
            fi
        done < <(driver_pkgs_for "$hardware")
    done | awk '!seen[$0]++'
}

# The name of the card from lspci when it is there, as the last part in brackets:
# Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600] (rev c1)
gpu_name() {
    local device="$1" fallback="$2" line

    line="$(lspci -s "${device##*/}" 2>/dev/null || true)"
    case "$line" in
        *\[*\]*) printf '%s\n' "$line" | sed 's/.*\[\([^]]*\)\].*/\1/' ;;
        *) printf '%s\n' "$fallback" ;;
    esac
}

hardware_names() {
    local device hardware

    case "$VIRT" in
        none) ;;
        vmware) printf 'VMware\n'; return 0 ;;
        kvm|qemu) printf 'QEMU/KVM\n'; return 0 ;;
        oracle) printf 'VirtualBox\n'; return 0 ;;
        *) printf '%s\n' "$VIRT"; return 0 ;;
    esac

    while IFS= read -r device; do
        hardware="$(gpu_hardware "$device")"
        has_hardware "$hardware" || continue
        [ -n "$(driver_pkgs_for "$hardware")" ] || continue
        case "$hardware" in
            amd) gpu_name "$device" "AMD" ;;
            intel) gpu_name "$device" "Intel" ;;
            *) gpu_name "$device" "NVIDIA" ;;
        esac
    done < <(gpu_devices)
}

# GeForce RTX 2060 + UHD Graphics 770: mesa, vulkan-intel
drivers_summary() {
    local names pkgs

    pkgs="$(missing_drivers | paste -sd, | sed 's/,/, /g')"
    [ -n "$pkgs" ] || return 0
    names="$(hardware_names | awk '!seen[$0]++' | paste -sd+ | sed 's/+/ + /g')"
    printf '%s: %s\n' "$names" "$pkgs"
}

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------

install_drivers() {
    local hardware pkg old

    if has_nvidia_to_install; then
        install_kernel_headers || true
    fi

    for hardware in "${HARDWARE[@]}"; do
        while IFS= read -r pkg; do
            old="$(driver_replaces_for "$hardware" "$pkg")"

            if [ -n "$old" ]; then
                replace_driver_package "$hardware" "$pkg" "$old" || true
            else
                install_driver_package "$hardware" "$pkg" || true
            fi
        done < <(driver_pkgs_for "$hardware")
    done

    if has_nvidia_to_install; then
        setup_nvidia_boot || true
    fi

    return 0
}

install_driver_package() {
    local hardware="$1" pkg="$2"

    if [ "$(pkg_source "$pkg")" != "repo" ]; then
        aur_install_one "$pkg" "$(driver_flags_for "$hardware" "$pkg")"
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

# Some distros come with a package that clashes with the one in drivers.txt, and neither
# pacman nor paru replaces a package with --noconfirm. The name is compared because
# pacman also answers for a package that only provides it. If the install fails the
# old package comes back, so the system still has it.
replace_driver_package() {
    local hardware="$1" pkg="$2" old="$3"

    if [ "${DRY_RUN:-0}" -eq 1 ] || [ "$(pacman -Qq "$old" 2>/dev/null)" != "$old" ]; then
        install_driver_package "$hardware" "$pkg"
        return
    fi

    info "$old: replacing with $pkg"
    if ! run_pacman -Rdd --noconfirm "$old"; then
        failure "$pkg: could not remove $old - see $LOG_FILE"
        return 1
    fi

    install_driver_package "$hardware" "$pkg" && return 0

    run_pacman -S --needed --noconfirm "$old" \
        || failure "Could not bring back $old. To try again: sudo pacman -S $old"
    return 1
}

# ------------------------------------------------------------
# Services
# ------------------------------------------------------------

configure_driver_services() {
    local hardware svc

    for hardware in "${HARDWARE[@]}"; do
        while IFS= read -r svc; do
            if [ "${DRY_RUN:-0}" -eq 1 ]; then
                info "Would enable $svc"
                continue
            fi

            sudo systemctl enable "$svc" >/dev/null 2>&1 \
                && ok "Enabled $svc" \
                || failure "Could not enable $svc"
        done < <(driver_services_for "$hardware")
    done
}
