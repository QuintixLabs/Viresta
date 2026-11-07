#!/usr/bin/env bash

# nvidia.sh
# Tests installing the NVIDIA driver: headers first, the boot image after, and what
# happens when a step fails or there is nothing to do.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
SCRIPT_DIR="$VIRESTA"
export PCI_DEVICES_DIR="$TEST_DIR/pci" OS_RELEASE_FILE="$TEST_DIR/os-release"
export CHASSIS_FILE="$TEST_DIR/chassis" KERNEL_MODULES_DIR="$TEST_DIR/modules"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
printf '3\n' >"$CHASSIS_FILE"
source "$VIRESTA/lib/installers/aur.sh"
# shellcheck source=/dev/null
for file in "$VIRESTA"/lib/drivers/hardware/*.sh "$VIRESTA/lib/drivers/install.sh"; do source "$file"; done

# Everything that would change the system writes what it was asked to do to CALLS.
CALLS="$TEST_DIR/calls"
call() { printf '%s;' "$1" >>"$CALLS"; }
info() { printf 'info: %s\n' "$1"; }
ok() { printf 'ok: %s\n' "$1"; }
failure() { printf 'FAILURE: %s\n' "$1"; }
systemd-detect-virt() { printf 'none\n'; }
lspci() { :; }
paru() { call "paru $4"; [ "${PARU_OK:-1}" -eq 1 ]; }
pkg_source() { case "$1" in nvidia-580xx-*) echo aur ;; *) echo repo ;; esac; }
INSTALLED=""
pacman() { if [ "$#" -eq 1 ]; then printf '%s\n' $INSTALLED; return 0; fi; return 1; }
is_installed() { printf '%s\n' $INSTALLED | grep -qxF "$1"; }
run_pacman() {
    shift 3
    call "pacman $*"
    [ "$*" != "${FAIL_PKG:-none}" ] || return 1
    INSTALLED="$INSTALLED $*"
}
sudo() {
    if [ "$1" = install ]; then call "write $4"; cat >"$TEST_DIR/conf"; return 0; fi
    call "sudo $*"
    [ "${SUDO_OK:-1}" -eq 1 ]
}
printf '#!/bin/sh\nexit 0\n' >"$BIN/mkinitcpio"
chmod +x "$BIN/mkinitcpio"
AUR_LOG_DIR="$TEST_DIR/logs"
LOG_FILE="$TEST_DIR/log"
DRY_RUN=0

card() {
    rm -rf "$PCI_DEVICES_DIR"
    mkdir -p "$PCI_DEVICES_DIR/0000:01:00.0"
    printf '0x030000\n' >"$PCI_DEVICES_DIR/0000:01:00.0/class"
    printf '%s\n' "$1" >"$PCI_DEVICES_DIR/0000:01:00.0/vendor"
    printf '%s\n' "${2:-0x2786}" >"$PCI_DEVICES_DIR/0000:01:00.0/device"
    detect_hardware
}
kernels() {
    rm -rf "$KERNEL_MODULES_DIR"
    local kernel
    for kernel in "$@"; do
        mkdir -p "$KERNEL_MODULES_DIR/$kernel"
        printf '%s\n' "$kernel" >"$KERNEL_MODULES_DIR/$kernel/pkgbase"
    done
}
# What install_drivers asked for, and what it said in $TEST_DIR/said.
install() { : >"$CALLS"; install_drivers >"$TEST_DIR/said"; cat "$CALLS"; }
said() { cat "$TEST_DIR/said"; }

kernels linux linux-lts

# ------------------------------------------------------------
# A new card
# ------------------------------------------------------------

INSTALLED=""; card 0x10de 0x2786
got="$(install)"
has "headers come first" "pacman linux-headers linux-lts-headers;pacman nvidia-open-dkms;" "$got"
has "the boot setting is written" "write /etc/mkinitcpio.conf.d/10-viresta-nvidia.conf" "$got"
has "the boot image is rebuilt after the drivers" "lib32-nvidia-utils;write /etc/mkinitcpio.conf.d/10-viresta-nvidia.conf;sudo mkinitcpio -P;" "$got"
is "the boot setting only drops kms" "$(cat "$TEST_DIR/conf")" 'HOOKS=(${HOOKS[@]/kms/})'

has "the 32-bit driver comes last" "pacman libva-nvidia-driver;pacman lib32-nvidia-utils;write" "$got"

# Run again with the driver there: only the 32-bit part, without the headers or a rebuild.
INSTALLED="nvidia-open-dkms nvidia-utils egl-wayland nvidia-settings libva-nvidia-driver"
card 0x10de 0x2786
got="$(install)"
has "the driver already there: the 32-bit part" "pacman lib32-nvidia-utils;" "$got"
hasnt "the driver already there: no headers" "headers" "$got"
hasnt "the driver already there: no boot image rebuild" "mkinitcpio" "$got"

# ------------------------------------------------------------
# A 580xx card
# ------------------------------------------------------------

INSTALLED=""; card 0x10de 0x1c03
got="$(install)"
has "580xx is built from the AUR" "paru nvidia-580xx-dkms;" "$got"
has "580xx: headers first" "pacman linux-headers linux-lts-headers;paru nvidia-580xx-dkms;" "$got"
hasnt "580xx: not the open driver" "nvidia-open-dkms" "$got"

# ------------------------------------------------------------
# Failures
# ------------------------------------------------------------

PARU_OK=0; INSTALLED=""; card 0x10de 0x1c03
got="$(install)"
hasnt "a failed build: the boot image is left alone" "mkinitcpio" "$got"
has "a failed build: reported" "install failed" "$(said)"
PARU_OK=1

FAIL_PKG=nvidia-open-dkms; INSTALLED=""; card 0x10de 0x2786
got="$(install)"
hasnt "a failed driver: the boot image is left alone" "mkinitcpio" "$got"
has "a failed driver: reported" "nvidia-open-dkms: install failed" "$(said)"

FAIL_PKG="linux-headers linux-lts-headers"; INSTALLED=""; card 0x10de 0x2786
install >/dev/null
has "failed headers: reported" "which the NVIDIA driver needs" "$(said)"
FAIL_PKG=none

SUDO_OK=0; INSTALLED=""; card 0x10de 0x2786
install >/dev/null
has "a failed rebuild: says how to try again" "To try again: sudo mkinitcpio -P" "$(said)"
SUDO_OK=1

rm "$BIN/mkinitcpio"
if ! command -v mkinitcpio >/dev/null 2>&1; then
    INSTALLED=""; card 0x10de 0x2786
    hasnt "no mkinitcpio: nothing is written" "write" "$(install)"
else
    skip "no mkinitcpio: this system has a real one"
fi
printf '#!/bin/sh\nexit 0\n' >"$BIN/mkinitcpio"
chmod +x "$BIN/mkinitcpio"

# ------------------------------------------------------------
# Nothing to do
# ------------------------------------------------------------

DRY_RUN=1; INSTALLED=""; card 0x10de 0x2786
is "dry run: changes nothing" "$(install)" ""
DRY_RUN=0

INSTALLED=""; card 0x10de 0x1180
is "an old card: nothing installed" "$(install)" ""

INSTALLED=""; card 0x1002
got="$(install)"
hasnt "AMD: no headers" "headers" "$got"
hasnt "AMD: the boot image is left alone" "mkinitcpio" "$got"

finish
