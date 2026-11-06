#!/usr/bin/env bash

# detect.sh
# Finds the VM or graphics cards, as the rows they use in drivers.txt.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

VIRT="none"
HARDWARE=()
PCI_DEVICES_DIR="${PCI_DEVICES_DIR:-/sys/bus/pci/devices}"
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
CHASSIS_FILE="${CHASSIS_FILE:-/sys/class/dmi/id/chassis_type}"

# ------------------------------------------------------------
# Graphics cards
# ------------------------------------------------------------

detect_virt() {
    VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [ -n "$VIRT" ] || VIRT="none"
}

# Reads the PCI devices directly, since lspci may not be installed yet. Class 03 is a
# graphics card, and the vendor numbers are the same on every system.
gpu_vendor() {
    case "$(cat "$1/vendor")" in
        0x1002) printf 'amd\n' ;;
        0x8086) printf 'intel\n' ;;
        0x10de) printf 'nvidia\n' ;;
    esac
}

gpu_devices() {
    local device

    for device in "$PCI_DEVICES_DIR"/*; do
        [ -e "$device/class" ] || continue
        case "$(cat "$device/class")" in
            0x03*) printf '%s\n' "$device" ;;
        esac
    done
}

gpu_hardware() {
    local device="$1" vendor

    vendor="$(gpu_vendor "$device")"
    if [ "$vendor" = "nvidia" ]; then
        nvidia_hardware "$device"
    else
        printf '%s\n' "$vendor"
    fi
}

# ------------------------------------------------------------
# The list of hardware
# ------------------------------------------------------------

has_hardware() {
    local item

    for item in "${HARDWARE[@]}"; do
        if [ "$item" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

remove_hardware() {
    local keep=() item

    for item in "${HARDWARE[@]}"; do
        if [ "$item" != "$1" ]; then
            keep+=("$item")
        fi
    done
    HARDWARE=("${keep[@]}")
}

# Only a laptop with a second graphics card has to switch between them.
is_hybrid_laptop() {
    has_hardware intel || has_hardware amd || return 1
    case "$(cat "$CHASSIS_FILE" 2>/dev/null)" in
        8|9|10|11|31) return 0 ;;
        *) return 1 ;;
    esac
}

is_cachyos() {
    grep -Eqs '^ID="?cachyos"?$' "$OS_RELEASE_FILE"
}

# A VM has no real graphics card, only its own tools to install. CachyOS sets up the
# drivers of a real PC with chwd, which also knows its own kernels and packages.
detect_hardware() {
    local device

    HARDWARE=()
    detect_virt

    if [ "$VIRT" != "none" ]; then
        HARDWARE=("$VIRT")
        return 0
    fi

    if is_cachyos; then
        return 0
    fi

    while IFS= read -r device; do
        HARDWARE+=("$(gpu_hardware "$device")")
    done < <(gpu_devices)
    mapfile -t HARDWARE < <(printf '%s\n' "${HARDWARE[@]}" | awk 'NF && !seen[$0]++')

    settle_nvidia_hardware
}
