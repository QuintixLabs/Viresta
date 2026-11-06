#!/usr/bin/env bash

# drivers.sh
# Tests what an update adds for drivers: the 32-bit ones someone is missing, multilib
# turned on for them, and never the Gaming row.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
SCRIPT_DIR="$VIRESTA"
export PCI_DEVICES_DIR="$TEST_DIR/pci" OS_RELEASE_FILE="$TEST_DIR/os-release"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
VIRESTA_STATE_DIR="$HOME/.local/state/viresta"
mkdir -p "$VIRESTA_STATE_DIR"
source "$VIRESTA/lib/installers/pacman.sh"
source "$VIRESTA/lib/installers/aur.sh"
# shellcheck source=/dev/null
for file in "$VIRESTA"/lib/drivers/hardware/*.sh "$VIRESTA/lib/drivers/install.sh" "$VIRESTA/lib/update/install-pkgs.sh"; do source "$file"; done

CALLS="$TEST_DIR/calls"
call() { printf '%s;' "$1" >>"$CALLS"; }
info() { :; }
ok() { :; }
failure() { call "FAILURE $1"; }
spinner_stop() { :; }
spinner_start() { :; }
register_cleanup() { :; }
ask_yes_no() { call "asked"; [ "$ANSWER" = y ]; }
sudo() { "$@"; }
systemd-detect-virt() { echo none; }
lspci() { :; }
INSTALLED=""
SYNCED=0
ANSWER=n
is_installed() { printf '%s\n' $INSTALLED | grep -qxF "$1"; }
pacman() { [ "$1" = -Qq ] && [ "$#" -eq 1 ] && printf '%s\n' $INSTALLED; }
pkg_source() { case "$1" in lib32-nvidia-580xx-utils) echo aur ;; *) echo repo ;; esac; }
# Installing from multilib only works once its package list was downloaded with -Syu.
run_pacman() {
    case "$1" in
        -Syu) call "pacman -Syu"; SYNCED=1 ;;
        -S)
            shift 3
            call "pacman $*"
            [ "$SYNCED" -eq 1 ] || return 1
            INSTALLED="$INSTALLED $*" ;;
    esac
}
aur_install_one() { call "aur $1"; }
DRY_RUN=0
USE_DRIVERS=1

gpu() {
    rm -rf "$PCI_DEVICES_DIR"
    mkdir -p "$PCI_DEVICES_DIR/0000:01:00.0"
    echo 0x030000 >"$PCI_DEVICES_DIR/0000:01:00.0/class"
    echo "$1" >"$PCI_DEVICES_DIR/0000:01:00.0/vendor"
    echo "${2:-0x2786}" >"$PCI_DEVICES_DIR/0000:01:00.0/device"
}
# Only what was asked for, not the blank line before the question.
update_drivers() { : >"$CALLS"; install_new_32bit_drivers >/dev/null; cat "$CALLS"; }

# ------------------------------------------------------------
# Someone from before the 32-bit drivers
# ------------------------------------------------------------

gpu 0x1002
INSTALLED="mesa vulkan-radeon"
fake_pacman_conf
printf 'mesa\nvulkan-radeon\n' >"$KNOWN_PACKAGES_FILE"

got="$(update_drivers)"
is "multilib is turned on for them" "$(grep -c '^\[multilib\]$' "$SYSTEM_PACMAN_CONF")" "1"
has "multilib has no package list yet, so it asks for a full update" "pacman lib32-mesa lib32-vulkan-radeon;asked;" "$got"
has "said no: listed as failed, tried next time" "FAILURE Could not install: lib32-mesa lib32-vulkan-radeon" "$got"

ANSWER=y
got="$(update_drivers)"
is "said yes: updated, then installed" "$got" "pacman lib32-mesa lib32-vulkan-radeon;asked;pacman -Syu;pacman lib32-mesa lib32-vulkan-radeon;"
ANSWER=n

# ------------------------------------------------------------
# When nothing should happen
# ------------------------------------------------------------

INSTALLED="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon"
is "already there: nothing" "$(update_drivers)" ""

INSTALLED="mesa vulkan-radeon"
printf 'lib32-mesa\nlib32-vulkan-radeon\n' >>"$KNOWN_PACKAGES_FILE"
is "removed on purpose: stays removed" "$(update_drivers)" ""
printf 'mesa\nvulkan-radeon\n' >"$KNOWN_PACKAGES_FILE"

USE_DRIVERS=0
is "drivers turned off in the menu: nothing" "$(update_drivers)" ""
USE_DRIVERS=1

gpu 0x10de 0x1c03
INSTALLED="nvidia-580xx-dkms nvidia-580xx-utils"
SYNCED=1
is "an older NVIDIA driver: its 32-bit one from the AUR" "$(update_drivers)" "aur lib32-nvidia-580xx-utils;"

# A first NVIDIA driver needs install.sh, for the headers and the boot image. Its 32-bit
# part alone would bring nvidia-utils, turn nouveau off and leave a black screen.
gpu 0x10de 0x2786
INSTALLED="mesa"
is "NVIDIA without its driver: nothing" "$(update_drivers)" ""

# ------------------------------------------------------------
# The Gaming row
# ------------------------------------------------------------

is "the Gaming packages are not in any list an update reads" "$(listed_packages | grep -cxE 'steam|protonup-qt-bin|goverlay|gamemode|mangohud')" "0"
is "the 32-bit drivers are, so a removed one stays removed" "$(listed_packages | grep '^lib32-' | sort -u | wc -l)" "5"
for list in system/base system/kde apps/pacman apps/aur; do
    hasnt "steam is not in $list.txt" "steam" "$(read_package_list "$VIRESTA/packages/$list.txt")"
done

finish
