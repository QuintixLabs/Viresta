#!/usr/bin/env bash

# gaming.sh
# Tests the Gaming row: what it installs and in which order, the 32-bit Vulkan driver
# Steam needs, and joining the gamemode group.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
SCRIPT_DIR="$VIRESTA"
export PCI_DEVICES_DIR="$TEST_DIR/pci" OS_RELEASE_FILE="$TEST_DIR/os-release"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
VIRESTA_STATE_DIR="$HOME/.local/state/viresta"
source "$VIRESTA/lib/installers/pacman.sh"
source "$VIRESTA/lib/installers/aur.sh"
# shellcheck source=/dev/null
for file in "$VIRESTA"/lib/drivers/hardware/*.sh "$VIRESTA/lib/drivers/install.sh" "$VIRESTA/lib/installers/gaming.sh"; do source "$file"; done

# What would change the system writes what it was asked to do to CALLS.
CALLS="$TEST_DIR/calls"
call() { printf '%s;' "$1" >>"$CALLS"; }
info() { :; }
ok() { :; }
failure() { call "FAILURE $1"; }
INSTALLED=""
VULKAN_THERE=0
IN_GROUP=0
FAKE_VIRT=none
systemd-detect-virt() { printf '%s\n' "$FAKE_VIRT"; }
lspci() { :; }
is_installed() { printf '%s\n' $INSTALLED | grep -qxF "$1"; }
pacman() {
    case "$1" in
        # Like pacman, a 32-bit driver for a real card counts as a Vulkan driver too.
        -T) [ "$VULKAN_THERE" -eq 1 ] || printf '%s\n' $INSTALLED | grep -qE '^lib32-(vulkan-|nvidia-)' ;;
        -Qq) [ "$#" -eq 1 ] && printf '%s\n' $INSTALLED ;;
        *) return 1 ;;
    esac
}
pkg_source() { case "$1" in *-bin) echo aur ;; *) echo repo ;; esac; }
run_pacman() { shift 3; call "pacman $*"; INSTALLED="$INSTALLED $*"; }
aur_install_one() { call "aur $1"; INSTALLED="$INSTALLED $1"; }
getent() { [ "$1" = group ] && [ "$2" = gamemode ]; }
id() { if [ "$1" = -un ]; then echo frost; elif [ "$IN_GROUP" -eq 1 ]; then echo "frost gamemode"; else echo frost; fi; }
sudo() { call "sudo $*"; }
DRY_RUN=0

gpu() {
    rm -rf "$PCI_DEVICES_DIR"
    mkdir -p "$PCI_DEVICES_DIR/0000:01:00.0"
    echo 0x030000 >"$PCI_DEVICES_DIR/0000:01:00.0/class"
    echo "$1" >"$PCI_DEVICES_DIR/0000:01:00.0/vendor"
    echo 0x2786 >"$PCI_DEVICES_DIR/0000:01:00.0/device"
}
gaming() { : >"$CALLS"; install_gaming; cat "$CALLS"; }

# ------------------------------------------------------------
# A real PC
# ------------------------------------------------------------

gpu 0x1002
INSTALLED="mesa vulkan-radeon"
detect_hardware
got="$(gaming)"
has "the 32-bit drivers come first" "pacman lib32-mesa;pacman lib32-vulkan-radeon;pacman steam;" "$got"
has "ProtonUp-Qt from the AUR" "aur protonup-qt-bin;" "$got"
for pkg in goverlay gamemode lib32-gamemode mangohud lib32-mangohud; do
    has "installs $pkg" "pacman $pkg;" "$got"
done
hasnt "no software Vulkan driver needed" "lib32-vulkan-swrast" "$got"
has "joins the gamemode group" "sudo usermod -aG gamemode frost" "$got"
hasnt "nothing failed" "FAILURE" "$got"

INSTALLED="$INSTALLED lib32-mesa lib32-vulkan-radeon steam protonup-qt-bin goverlay gamemode lib32-gamemode mangohud lib32-mangohud"
IN_GROUP=1
is "everything already there: nothing to do" "$(gaming)" ""
IN_GROUP=0

# ------------------------------------------------------------
# A VM, with no 32-bit Vulkan driver at all
# ------------------------------------------------------------

FAKE_VIRT=vmware
INSTALLED="mesa"
detect_hardware
got="$(gaming)"
has "a VM gets the software Vulkan driver, before Steam" "pacman lib32-vulkan-swrast;pacman steam;" "$got"
VULKAN_THERE=1
hasnt "one already there: no software driver" "lib32-vulkan-swrast" "$(gaming)"
FAKE_VIRT=none

# ------------------------------------------------------------
# Dry run
# ------------------------------------------------------------

DRY_RUN=1
INSTALLED=""
detect_hardware
is "dry run: changes nothing" "$(gaming | grep -o 'pacman [^;]*' )" ""

finish
