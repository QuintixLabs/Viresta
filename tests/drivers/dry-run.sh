#!/usr/bin/env bash

# dry-run.sh
# Runs the real install.sh as a dry run with fake hardware, to check what it would
# install, how many steps it shows, and the warnings it gives.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
sed -i 's|\[ -f /etc/arch-release \]|true|; s|^    require_internet$|    true|' "$VIRESTA/lib/system/checks.sh"
printf '#!/bin/sh\nexit 1\n' >"$BIN/pacman"
printf '#!/bin/sh\necho "${FAKE_VIRT:-none}"\n' >"$BIN/systemd-detect-virt"
chmod +x "$BIN/pacman" "$BIN/systemd-detect-virt"
export PCI_DEVICES_DIR="$TEST_DIR/pci" OS_RELEASE_FILE="$TEST_DIR/os-release" FAKE_VIRT=none
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
OPTIONS="$HOME/.config/viresta/options"
mkdir -p "$(dirname "$OPTIONS")"

gpu() {
    rm -rf "$PCI_DEVICES_DIR"
    mkdir -p "$PCI_DEVICES_DIR/0000:01:00.0"
    echo 0x030000 >"$PCI_DEVICES_DIR/0000:01:00.0/class"
    echo "$1" >"$PCI_DEVICES_DIR/0000:01:00.0/vendor"
    echo "${2:-0x2786}" >"$PCI_DEVICES_DIR/0000:01:00.0/device"
}
dry_run() { (cd "$VIRESTA" && bash ./install.sh --dry-run </dev/null 2>&1); }
steps() { grep -m1 -oE '/[0-9]+\]' <<<"$1"; }
count() { grep -c -- "$1" <<<"$2"; }

# ------------------------------------------------------------
# Graphics
# ------------------------------------------------------------

gpu 0x1002; out="$(dry_run)"
is "AMD: 9 steps" "$(steps "$out")" "/9]"
is "AMD: a drivers step" "$(count 'Installing drivers' "$out")" "1"
is "AMD: mesa" "$(count 'Would install mesa\|Would build mesa' "$out")" "1"
is "AMD: no NVIDIA warning" "$(count NVIDIA "$out")" "0"

gpu 0x10de; out="$(dry_run)"
is "NVIDIA: 9 steps" "$(steps "$out")" "/9]"
is "NVIDIA: a new card is not called untested" "$(count 'has not been tested' "$out")" "0"
is "NVIDIA: the open driver" "$(count 'Would build nvidia-open-dkms' "$out")" "1"
is "NVIDIA: the boot image" "$(count 'rebuild the boot image' "$out")" "1"
gpu 0x10de 0x1c03; out="$(dry_run)"
is "GTX 1060: 580xx" "$(count 'Would build nvidia-580xx-dkms' "$out")" "1"
is "GTX 1060: the untested warning" "$(count 'has not been tested' "$out")" "1"
gpu 0x10de 0x1180; out="$(dry_run)"
is "GTX 680: 8 steps" "$(steps "$out")" "/8]"
is "GTX 680: told it stays on nouveau" "$(count 'stays on nouveau' "$out")" "1"
is "GTX 680: not called untested" "$(count 'has not been tested' "$out")" "0"

rm -rf "$PCI_DEVICES_DIR"; mkdir "$PCI_DEVICES_DIR"; out="$(dry_run)"
is "no gpu: 8 steps" "$(steps "$out")" "/8]"

# ------------------------------------------------------------
# CachyOS
# ------------------------------------------------------------

gpu 0x1002
printf 'ID=cachyos\n' >"$OS_RELEASE_FILE"; out="$(dry_run)"
is "a CachyOS PC: 8 steps" "$(steps "$out")" "/8]"
is "a CachyOS PC: no drivers step" "$(count 'Installing drivers' "$out")" "0"
FAKE_VIRT=vmware; out="$(dry_run)"
is "a CachyOS VM: 9 steps" "$(steps "$out")" "/9]"
is "a CachyOS VM: clipway" "$(count 'Would build open-vm-tools-clipway' "$out")" "1"
is "a CachyOS VM: its service" "$(count 'Would enable vmtoolsd.service' "$out")" "1"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"

# ------------------------------------------------------------
# Saved choices
# ------------------------------------------------------------

printf 'vicinae=1\nrename_wallpapers=1\ndrivers=0\n' >"$OPTIONS"; out="$(dry_run)"
is "drivers turned off: 8 steps" "$(steps "$out")" "/8]"
is "drivers turned off: no clipway" "$(count open-vm-tools-clipway "$out")" "0"
is "drivers turned off: no service" "$(count vmtoolsd "$out")" "0"

printf 'vicinae=0\nrename_wallpapers=0\ndrivers=1\n' >"$OPTIONS"; out="$(dry_run)"
is "Vicinae turned off: not built" "$(count 'Would build vicinae-bin' "$out")" "0"
rm -f "$OPTIONS"; out="$(dry_run)"
is "by default: Vicinae is built" "$(count 'Would build vicinae-bin' "$out")" "1"

sed -i 's/^USE_DRIVERS=1$/USE_DRIVERS=0/' "$VIRESTA/setup/shared/variables.sh"; out="$(dry_run)"
is "the defaults come from variables.sh" "$(count open-vm-tools-clipway "$out")" "0"
sed -i 's/^USE_DRIVERS=0$/USE_DRIVERS=1/' "$VIRESTA/setup/shared/variables.sh"

finish
