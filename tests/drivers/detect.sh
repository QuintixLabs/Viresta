#!/usr/bin/env bash

# detect.sh
# Tests finding the hardware with fake PCI devices: AMD, Intel, NVIDIA, laptops and VMs,
# which NVIDIA driver a card needs, the menu row, and the kernel headers.

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

FAKE_VIRT=none
LSPCI_OK=1
INSTALLED=""
declare -A LSPCI_LINES
info() { :; }
ok() { :; }
failure() { :; }
systemd-detect-virt() { printf '%s\n' "$FAKE_VIRT"; }
lspci() { [ "$LSPCI_OK" -eq 1 ] || return 127; printf '%s\n' "${LSPCI_LINES[$2]:-}"; }
pacman() { if [ "$#" -eq 1 ]; then printf '%s\n' $INSTALLED; return 0; fi; return 1; }
is_installed() { printf '%s\n' $INSTALLED | grep -qxF "$1"; }
pkg_source() { case "$1" in nvidia-580xx-*) echo aur ;; *) echo repo ;; esac; }

# gpu <address> <class> <vendor> [device]
gpu() {
    mkdir -p "$PCI_DEVICES_DIR/$1"
    printf '%s\n' "$2" >"$PCI_DEVICES_DIR/$1/class"
    printf '%s\n' "$3" >"$PCI_DEVICES_DIR/$1/vendor"
    printf '%s\n' "${4:-0x2786}" >"$PCI_DEVICES_DIR/$1/device"
}
no_gpus() { rm -rf "$PCI_DEVICES_DIR"; mkdir -p "$PCI_DEVICES_DIR"; }
found() { detect_hardware; printf '%s\n' "${HARDWARE[*]}"; }
card() { no_gpus; gpu 0000:01:00.0 0x030000 0x10de "$1"; found; }

# ------------------------------------------------------------
# Reading drivers.txt
# ------------------------------------------------------------

is "vmware: package" "$(driver_pkgs_for vmware)" "open-vm-tools-clipway"
is "vmware: service" "$(driver_services_for vmware)" "vmtoolsd.service"
is "vmware: replaces" "$(driver_replaces_for vmware open-vm-tools-clipway)" "open-vm-tools"
is "vmware: build options" "$(driver_flags_for vmware open-vm-tools-clipway)" "--without-gtk4"
is "kvm: service" "$(driver_services_for kvm)" "qemu-guest-agent.service"
is "kvm: replaces nothing" "$(driver_replaces_for kvm qemu-guest-agent)" ""
is "amd: packages" "$(driver_pkgs_for amd | paste -sd,)" "mesa,vulkan-radeon,lib32-mesa,lib32-vulkan-radeon"
is "amd: no service" "$(driver_services_for amd)" ""
is "intel: packages" "$(driver_pkgs_for intel | paste -sd,)" "mesa,vulkan-intel,intel-media-driver,libva-intel-driver,lib32-mesa,lib32-vulkan-intel"
is "old nvidia: nothing" "$(driver_pkgs_for nvidia-old)" ""

# ------------------------------------------------------------
# Finding the hardware
# ------------------------------------------------------------

no_gpus
is "no gpu" "$(found)" ""
gpu 0000:01:00.0 0x030000 0x1002
is "amd" "$(found)" "amd"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086
is "intel" "$(found)" "intel"
no_gpus; gpu 0000:01:00.0 0x030200 0x10de
is "nvidia as a 3D controller" "$(found)" "nvidia"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de
is "two cards" "$(found)" "intel nvidia"
no_gpus; gpu 0000:01:00.0 0x030000 0x1002; gpu 0000:02:00.0 0x030000 0x1002
is "two of the same count once" "$(found)" "amd"
no_gpus; gpu 0000:00:1f.0 0x060100 0x8086; gpu 0000:00:1f.3 0x040300 0x8086
is "other Intel devices are not a gpu" "$(found)" ""
no_gpus; gpu 0000:01:00.0 0x030000 0x1af4
is "an unknown maker is ignored" "$(found)" ""

FAKE_VIRT=vmware; no_gpus; gpu 0000:00:0f.0 0x030000 0x15ad
is "a VM counts as the VM, not its gpu" "$(found)" "vmware"
printf 'ID=cachyos\n' >"$OS_RELEASE_FILE"
is "a CachyOS VM still gets the VM tools" "$(found)" "vmware"
FAKE_VIRT=none; no_gpus; gpu 0000:01:00.0 0x030000 0x1002
is "a CachyOS PC: chwd does it" "$(found)" ""
printf 'ID="cachyos"\n' >"$OS_RELEASE_FILE"
is "CachyOS with quotes" "$(found)" ""
printf 'ID=arch\nID_LIKE=cachyos\n' >"$OS_RELEASE_FILE"
is "ID_LIKE is not CachyOS" "$(found)" "amd"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"

# ------------------------------------------------------------
# Which NVIDIA driver
# ------------------------------------------------------------

# Real IDs of real cards.
is "RTX 4070: current" "$(card 0x2786)" "nvidia"
is "RTX 3060: current" "$(card 0x2504)" "nvidia"
is "RTX 2060: current" "$(card 0x1f08)" "nvidia"
is "GTX 1650: current" "$(card 0x1f82)" "nvidia"
is "GTX 1080: 580xx" "$(card 0x1b80)" "nvidia-580xx"
is "GTX 1060: 580xx" "$(card 0x1c03)" "nvidia-580xx"
is "GTX 970: 580xx" "$(card 0x13c2)" "nvidia-580xx"
is "GTX 750 Ti: 580xx" "$(card 0x1380)" "nvidia-580xx"
is "GTX 680: too old" "$(card 0x1180)" "nvidia-old"
is "GTX 560: too old" "$(card 0x1200)" "nvidia-old"
is "a card from the future: current" "$(card 0xffff)" "nvidia"
is "part of an ID does not match" "$(card 0x0138)" "nvidia"
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x1f08; gpu 0000:02:00.0 0x030000 0x10de 0x1c03
is "a new and a 580xx card share 580xx" "$(found)" "nvidia-580xx"

# A driver the user chose is left alone, with the card dropped from the list.
for driver in nvidia-open nvidia nvidia-dkms nvidia-580xx-dkms nvidia-470xx-dkms nvidia-390xx-dkms; do
    INSTALLED="$driver"
    is "their own $driver: the card is left alone" "$(card 0x2786)" ""
done
# The one Viresta picks keeps the card, so its other rows like the 32-bit driver still come.
INSTALLED="nvidia-open-dkms"
is "Viresta's driver already there: the card stays" "$(card 0x2786)" "nvidia"
INSTALLED="nvidia-580xx-dkms"
is "Viresta's 580xx driver already there: the card stays" "$(card 0x1c03)" "nvidia-580xx"
INSTALLED="nvidia-open-dkms"
is "an old card with a driver: no nouveau warning" "$(card 0x1180)" ""
INSTALLED="nvidia-utils"
is "nvidia-utils alone is not a driver" "$(card 0x2786)" "nvidia"
INSTALLED="nvidia-open"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de 0x2786
is "the other card is still handled" "$(found)" "intel"
INSTALLED=""

# ------------------------------------------------------------
# Laptops
# ------------------------------------------------------------

no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de 0x2786
printf '10\n' >"$CHASSIS_FILE"
is "Intel and NVIDIA laptop" "$(found)" "intel nvidia nvidia-laptop"
printf '3\n' >"$CHASSIS_FILE"
is "Intel and NVIDIA desktop" "$(found)" "intel nvidia"
printf '10\n' >"$CHASSIS_FILE"
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x2786
is "an NVIDIA only laptop" "$(found)" "nvidia"
no_gpus; gpu 0000:05:00.0 0x030000 0x1002; gpu 0000:01:00.0 0x030200 0x10de 0x1c03
is "AMD and 580xx laptop" "$(found)" "nvidia-580xx amd nvidia-laptop"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de 0x1180
is "a laptop with an old card: no switching" "$(found)" "intel nvidia-old"
rm -f "$CHASSIS_FILE"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de 0x2786
is "no chassis file: not a laptop" "$(found)" "intel nvidia"
printf '3\n' >"$CHASSIS_FILE"

# ------------------------------------------------------------
# The menu row
# ------------------------------------------------------------

no_gpus; gpu 0000:01:00.0 0x030000 0x1002; detect_hardware
LSPCI_LINES["0000:01:00.0"]='01:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600/6600 XT/6600M] (rev c1)'
is "amd row" "$(drivers_summary)" "Radeon RX 6600/6600 XT/6600M: mesa, vulkan-radeon, lib32-mesa, lib32-vulkan-radeon"
LSPCI_OK=0
is "no lspci: the maker's name" "$(drivers_summary)" "AMD: mesa, vulkan-radeon, lib32-mesa, lib32-vulkan-radeon"
LSPCI_OK=1
INSTALLED="mesa"
is "only what is missing" "$(drivers_summary)" "Radeon RX 6600/6600 XT/6600M: vulkan-radeon, lib32-mesa, lib32-vulkan-radeon"
INSTALLED="mesa vulkan-radeon"
is "only the 32-bit ones missing" "$(drivers_summary)" "Radeon RX 6600/6600 XT/6600M: lib32-mesa, lib32-vulkan-radeon"
INSTALLED="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon"
is "all installed: no row" "$(drivers_summary)" ""
INSTALLED=""

no_gpus; gpu 0000:00:02.0 0x030000 0x8086; detect_hardware
LSPCI_LINES["0000:00:02.0"]='00:02.0 VGA compatible controller: Intel Corporation HD Graphics 620 (rev 02)'
is "no brackets: the maker's name" "$(drivers_summary)" "Intel: mesa, vulkan-intel, intel-media-driver, libva-intel-driver, lib32-mesa, lib32-vulkan-intel"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de; detect_hardware
unset 'LSPCI_LINES[0000:01:00.0]'
is "Intel and NVIDIA: both named" "$(drivers_summary | cut -d: -f1)" "Intel + NVIDIA"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030000 0x1002; detect_hardware
LSPCI_LINES["0000:00:02.0"]='00:02.0 VGA: Intel Corporation Raptor Lake [UHD Graphics 770] (rev 04)'
LSPCI_LINES["0000:01:00.0"]='01:00.0 VGA: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [Radeon RX 6600/6600 XT/6600M] (rev c1)'
is "two cards: no package twice" "$(drivers_summary)" "UHD Graphics 770 + Radeon RX 6600/6600 XT/6600M: mesa, vulkan-intel, intel-media-driver, libva-intel-driver, lib32-mesa, lib32-vulkan-intel, vulkan-radeon, lib32-vulkan-radeon"

no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x1f08; detect_hardware
LSPCI_LINES["0000:01:00.0"]='01:00.0 VGA compatible controller: NVIDIA Corporation TU106 [GeForce RTX 2060 Rev. A] (rev a1)'
is "a new NVIDIA card" "$(drivers_summary)" "GeForce RTX 2060 Rev. A: nvidia-open-dkms, nvidia-utils, egl-wayland, nvidia-settings, libva-nvidia-driver, lib32-nvidia-utils"
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x1c03; detect_hardware
LSPCI_LINES["0000:01:00.0"]='01:00.0 VGA: NVIDIA Corporation GP106 [GeForce GTX 1060 6GB] (rev a1)'
is "a 580xx card" "$(drivers_summary)" "GeForce GTX 1060 6GB: nvidia-580xx-dkms, nvidia-580xx-utils, egl-wayland, libva-nvidia-driver, lib32-nvidia-580xx-utils"
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x1180; detect_hardware
is "an old card: no row" "$(drivers_summary)" ""
unset 'LSPCI_LINES[0000:01:00.0]'
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x2786; detect_hardware
is "no lspci name: NVIDIA" "$(drivers_summary | cut -d: -f1)" "NVIDIA"

printf '10\n' >"$CHASSIS_FILE"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030200 0x10de 0x2786; detect_hardware
LSPCI_LINES["0000:00:02.0"]='00:02.0 VGA: Intel Corporation Raptor Lake [UHD Graphics 770] (rev 04)'
LSPCI_LINES["0000:01:00.0"]='01:00.0 3D controller: NVIDIA Corporation AD107M [GeForce RTX 4060 Max-Q] (rev a1)'
has "a laptop row names both" "UHD Graphics 770 + GeForce RTX 4060 Max-Q:" "$(drivers_summary)"
has "a laptop row has switching" "nvidia-prime, switcheroo-control" "$(drivers_summary)"
is "the laptop service" "$(driver_services_for nvidia-laptop)" "switcheroo-control.service"
printf '3\n' >"$CHASSIS_FILE"

FAKE_VIRT=vmware; detect_hardware
is "vmware row" "$(drivers_summary)" "VMware: open-vm-tools-clipway"
FAKE_VIRT=oracle; detect_hardware
is "virtualbox row" "$(drivers_summary)" "VirtualBox: virtualbox-guest-utils"
FAKE_VIRT=kvm; detect_hardware
is "kvm row" "$(drivers_summary)" "QEMU/KVM: qemu-guest-agent"
FAKE_VIRT=microsoft; detect_hardware
is "a VM with nothing to install: no row" "$(drivers_summary)" ""
FAKE_VIRT=none

# ------------------------------------------------------------
# 32-bit drivers
# ------------------------------------------------------------

no_gpus; gpu 0000:01:00.0 0x030000 0x1002; detect_hardware
INSTALLED=""
is "AMD: its two" "$(missing_32bit_drivers | paste -sd' ')" "lib32-mesa lib32-vulkan-radeon"
INSTALLED="mesa vulkan-radeon lib32-mesa"
is "only the ones missing" "$(missing_32bit_drivers)" "lib32-vulkan-radeon"

# Viresta's NVIDIA driver already there: only its 32-bit part is missing.
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x2786
INSTALLED="nvidia-open-dkms nvidia-utils egl-wayland nvidia-settings libva-nvidia-driver"; detect_hardware
is "NVIDIA with its driver: the 32-bit one" "$(missing_32bit_drivers)" "lib32-nvidia-utils"
LSPCI_LINES["0000:01:00.0"]='01:00.0 VGA: NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)'
is "NVIDIA with its driver: only that in the row" "$(drivers_summary)" "GeForce RTX 4070: lib32-nvidia-utils"
unset 'LSPCI_LINES[0000:01:00.0]'
INSTALLED="nvidia-580xx-dkms nvidia-580xx-utils"
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x1c03; detect_hardware
is "580xx with its driver: its own 32-bit one" "$(missing_32bit_drivers)" "lib32-nvidia-580xx-utils"

# Without the NVIDIA driver, its 32-bit part would turn nouveau off and leave a black screen.
INSTALLED=""
no_gpus; gpu 0000:01:00.0 0x030000 0x10de 0x2786; detect_hardware
is "NVIDIA without its driver: not the 32-bit one" "$(missing_32bit_drivers)" ""
INSTALLED="nvidia-open"
is "their own driver: left alone" "$(card 0x2786; missing_32bit_drivers)" ""
INSTALLED=""

FAKE_VIRT=vmware; INSTALLED="mesa"; detect_hardware
is "a VM: none" "$(missing_32bit_drivers)" ""
FAKE_VIRT=none
printf 'ID=cachyos\n' >"$OS_RELEASE_FILE"; detect_hardware
is "CachyOS: left to chwd" "$(missing_32bit_drivers)" ""
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
INSTALLED=""

# ------------------------------------------------------------
# Kernel headers
# ------------------------------------------------------------

kernels() {
    rm -rf "$KERNEL_MODULES_DIR"
    mkdir -p "$KERNEL_MODULES_DIR"
    local kernel
    for kernel in "$@"; do
        mkdir -p "$KERNEL_MODULES_DIR/$kernel"
        printf '%s\n' "$kernel" >"$KERNEL_MODULES_DIR/$kernel/pkgbase"
    done
}
kernels linux
is "one kernel" "$(kernel_headers)" "linux-headers"
kernels linux linux-lts linux-zen
is "three kernels" "$(kernel_headers | sort | paste -sd,)" "linux-headers,linux-lts-headers,linux-zen-headers"
kernels
is "no pkgbase: linux" "$(kernel_headers)" "linux-headers"

finish
