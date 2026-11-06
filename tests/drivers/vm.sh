#!/usr/bin/env bash

# vm.sh
# Tests installing drivers from drivers.txt: the VM tools, clipway built with its options
# and put back on a failure, services, and that any row works without code for it.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
SCRIPT_DIR="$VIRESTA"
export PCI_DEVICES_DIR="$TEST_DIR/pci" OS_RELEASE_FILE="$TEST_DIR/os-release" CHASSIS_FILE="$TEST_DIR/chassis"
printf 'ID=arch\n' >"$OS_RELEASE_FILE"
source "$VIRESTA/lib/installers/aur.sh"
# shellcheck source=/dev/null
for file in "$VIRESTA"/lib/drivers/hardware/*.sh "$VIRESTA/lib/drivers/install.sh"; do source "$file"; done

# Everything that would change the system writes what it was asked to do to CALLS.
CALLS="$TEST_DIR/calls"
BUILT="$TEST_DIR/built"
PKGBUILD_TEXT='build() {
  ./configure \
    --prefix=/usr
}'
call() { printf '%s;' "$1" >>"$CALLS"; }
info() { printf 'info: %s\n' "$1"; }
ok() { printf 'ok: %s\n' "$1"; }
failure() { printf 'FAILURE: %s\n' "$1"; }
paru() { call "paru $4"; [ "$PARU_OK" -eq 1 ]; }
git() {
    call "clone $2"
    [ "$CLONE_OK" -eq 1 ] || return 1
    mkdir -p "$(basename "$2" .git)"
    printf '%s\n' "$PKGBUILD_TEXT" >"$(basename "$2" .git)/PKGBUILD"
}
makepkg() { call makepkg; cp PKGBUILD "$BUILT"; [ "$MAKEPKG_OK" -eq 1 ]; }
systemd-detect-virt() { printf '%s\n' "$FAKE_VIRT"; }
sudo() { call "sudo $2 $3"; [ "$SERVICE_OK" -eq 1 ]; }
lspci() { :; }
pkg_source() { printf '%s\n' "$SOURCE"; }
# THERE is the package already installed, and ALIAS another name that answers for it.
pacman() {
    [ "$THERE" != none ] || return 1
    if [ "$THERE" = "$2" ] || [ "$2" = "$ALIAS" ]; then printf '%s\n' "$THERE"; return 0; fi
    return 1
}
is_installed() { [ "$THERE" = "$1" ]; }
run_pacman() {
    call "pacman $1 $([ "$1" = -Rdd ] && echo "$3" || echo "$4")"
    case "$1" in
        -Rdd) [ "$REMOVE_OK" -eq 1 ] ;;
        -S) if [ "$4" = newtool ]; then [ "$NEW_OK" -eq 1 ]; else [ "$RESTORE_OK" -eq 1 ]; fi ;;
    esac
}
AUR_LOG_DIR="$TEST_DIR/logs"
LOG_FILE="$TEST_DIR/log"

SOURCE=repo DRY_RUN=0 THERE=none ALIAS="" PARU_OK=1 REMOVE_OK=1 RESTORE_OK=1 NEW_OK=1
CLONE_OK=1 MAKEPKG_OK=1 SERVICE_OK=1 FAKE_VIRT=none

gpu() {
    mkdir -p "$PCI_DEVICES_DIR/$1"
    printf '%s\n' "$2" >"$PCI_DEVICES_DIR/$1/class"
    printf '%s\n' "$3" >"$PCI_DEVICES_DIR/$1/vendor"
    printf '0x2786\n' >"$PCI_DEVICES_DIR/$1/device"
}
no_gpus() { rm -rf "$PCI_DEVICES_DIR"; mkdir -p "$PCI_DEVICES_DIR"; }

# installs <name> <calls wanted> <text it should say>
installs() {
    local said got
    : >"$CALLS"
    said="$(install_drivers)"
    got="$(cat "$CALLS")"
    if [ "$got" = "$2" ] && { [ -z "$3" ] || grep -qF "$3" <<<"$said"; }; then
        pass "$1"
    else
        fail "$1" "want: $2" "got:  $got" "said: $said"
    fi
}

# ------------------------------------------------------------
# Real hardware
# ------------------------------------------------------------

no_gpus; gpu 0000:01:00.0 0x030000 0x1002; detect_hardware
installs "AMD installs its packages" "pacman -S mesa;pacman -S vulkan-radeon;" "installing"
no_gpus; gpu 0000:00:02.0 0x030000 0x8086; gpu 0000:01:00.0 0x030000 0x1002; detect_hardware
installs "AMD and Intel install both" "pacman -S mesa;pacman -S vulkan-intel;pacman -S intel-media-driver;pacman -S libva-intel-driver;pacman -S mesa;pacman -S vulkan-radeon;" "installing"
no_gpus; detect_hardware
installs "no hardware: nothing" "" ""
: >"$CALLS"; configure_driver_services >/dev/null
is "no hardware: no services" "$(cat "$CALLS")" ""

# ------------------------------------------------------------
# Clipway on VMware
# ------------------------------------------------------------

CLIPWAY="https://aur.archlinux.org/open-vm-tools-clipway.git"
FAKE_VIRT=vmware SOURCE=aur
detect_hardware

rm -f "$BUILT"
installs "nothing installed: built with makepkg, not paru" "clone $CLIPWAY;makepkg;" "installed"
is "its option reaches ./configure" "$(sed -n 2p "$BUILT")" '  ./configure --without-gtk4 \'

THERE=open-vm-tools
installs "CachyOS: the old package goes first" "pacman -Rdd open-vm-tools;clone $CLIPWAY;makepkg;" "replacing"
THERE=open-vm-tools-clipway ALIAS=open-vm-tools
installs "clipway answering for the old name: nothing" "" "already installed"
THERE=open-vm-tools-clipway ALIAS=""
installs "clipway already there: nothing" "" "already installed"

THERE=open-vm-tools MAKEPKG_OK=0
installs "the build fails: the old package comes back" "pacman -Rdd open-vm-tools;clone $CLIPWAY;makepkg;pacman -S open-vm-tools;" "install failed"
RESTORE_OK=0
installs "build and restore fail: says how to try again" "pacman -Rdd open-vm-tools;clone $CLIPWAY;makepkg;pacman -S open-vm-tools;" "To try again"
MAKEPKG_OK=1 RESTORE_OK=1 CLONE_OK=0
installs "the download fails: the old package comes back" "pacman -Rdd open-vm-tools;clone $CLIPWAY;pacman -S open-vm-tools;" "install failed"

CLONE_OK=1 PKGBUILD_TEXT='build() { cmake .; }'
rm -f "$BUILT"
installs "no ./configure: no build, the old package comes back" "pacman -Rdd open-vm-tools;clone $CLIPWAY;pacman -S open-vm-tools;" "install failed"
missing "that never reached makepkg" "$BUILT"
is "the log says why" "$(tail -n 1 "$AUR_LOG_DIR/aur-open-vm-tools-clipway.log")" "No ./configure in the PKGBUILD to add --without-gtk4 to"
PKGBUILD_TEXT='./configure'

REMOVE_OK=0
installs "removing the old one fails: no build" "pacman -Rdd open-vm-tools;" "could not remove"
REMOVE_OK=1

DRY_RUN=1
installs "dry run: changes nothing" "" "Would build"
: >"$CALLS"
is "dry run: says the service" "$(configure_driver_services)" "info: Would enable vmtoolsd.service"
is "dry run: enables nothing" "$(cat "$CALLS")" ""
DRY_RUN=0

: >"$CALLS"; configure_driver_services >/dev/null
is "the service is turned on" "$(cat "$CALLS")" "sudo enable vmtoolsd.service;"
SERVICE_OK=0
is "a service failure is reported" "$(configure_driver_services)" "FAILURE: Could not enable vmtoolsd.service"
SERVICE_OK=1

# ------------------------------------------------------------
# Any row works
# ------------------------------------------------------------

# Nothing about a package is in the code, so made-up rows must work the same way.
cat >"$VIRESTA/packages/drivers.txt" <<'EOF'
kvm newtool new.service oldtool
oracle plaintool plain.service
qemu flagtool flag.service - --one --two
amd aftermarket - - --flag
EOF
HARDWARE=(kvm) SOURCE=repo THERE=oldtool
installs "a repo package that replaces another" "pacman -Rdd oldtool;pacman -S newtool;" "replacing"
NEW_OK=0
installs "its install fails: the old one comes back" "pacman -Rdd oldtool;pacman -S newtool;pacman -S oldtool;" "install failed"
NEW_OK=1 THERE=none DRY_RUN=1
installs "dry run: changes nothing" "" "Would install newtool"
DRY_RUN=0

HARDWARE=(oracle) SOURCE=aur
installs "no build options: paru as usual" "paru plaintool;" "installed"
is "- means it replaces nothing" "$(driver_replaces_for qemu flagtool)" ""
is "several options stay together" "$(driver_flags_for qemu flagtool)" "--one --two"
is "the service is still right with every column" "$(driver_services_for qemu)" "flag.service"
is "- means no service" "$(driver_services_for amd)" ""
HARDWARE=(qemu)
rm -f "$BUILT"
installs "options without replacing: built, nothing removed" "clone https://aur.archlinux.org/flagtool.git;makepkg;" "installed"
is "both options reach ./configure" "$(cat "$BUILT")" "./configure --one --two"

finish
