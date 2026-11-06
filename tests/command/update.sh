#!/usr/bin/env bash

# update.sh
# Tests the update script: what it says is waiting, asking once, the order it updates in,
# and stopping cleanly when something fails.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
UPDATE="$VIRESTA/config/shell/scripts/update"

# Each fake says what it was asked to do, and how many updates it has from $FAKE.
export FAKE="$TEST_DIR/fake" CALLS="$TEST_DIR/calls"
mkdir -p "$FAKE"
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$BIN/$1"; chmod +x "$BIN/$1"; }
fake pacman 'echo "pacman $*" >>"$CALLS"'
fake sudo 'echo "sudo $*" >>"$CALLS"; [ ! -e "$FAKE/fail-pacman" ]'
fake checkupdates 'n="$(cat "$FAKE/official" 2>/dev/null || echo 0)"; [ "$n" -gt 0 ] || exit 2; for i in $(seq "$n"); do echo "pkg$i 1 -> 2"; done'
fake paru 'if [ "$1" = -Qua ]; then n="$(cat "$FAKE/aur" 2>/dev/null || echo 0)"; for i in $(seq "$n"); do echo "aur$i 1 -> 2"; done; else echo "paru $*" >>"$CALLS"; [ ! -e "$FAKE/fail-pacman" ]; fi'
fake flatpak 'if [ "$1" = remote-ls ]; then n="$(cat "$FAKE/flatpak" 2>/dev/null || echo 0)"; for i in $(seq "$n"); do echo "org.app$i"; done; else echo "flatpak $*" >>"$CALLS"; fi'
fake viresta '[ -e "$FAKE/viresta-out" ] && echo "Viresta 9.9.9 is out. You'"'"'re on 1.0.0. Run viresta update to get it." || echo "Viresta is up to date (v1.0.0)."'
fake uname 'echo 6.0-test'
export KERNEL_MODULES_DIR="$TEST_DIR/modules"
mkdir -p "$KERNEL_MODULES_DIR/6.0-test"

waiting() { echo "$1" >"$FAKE/official"; echo "$2" >"$FAKE/aur"; echo "$3" >"$FAKE/flatpak"; }
# run_update <answer> [options]: in a real terminal, with the answer typed in.
run_update() {
    local answer="$1"
    shift
    : >"$CALLS"
    { sleep 0.4; printf '%s\n' "$answer"; sleep 0.2; } \
        | script -qec "bash '$UPDATE' $*" "$TEST_DIR/screen" >/dev/null 2>&1
    STATUS=$?
    OUT="$(sed -e '1{/^Script started/d}' -e '${/^Script done/d}' "$TEST_DIR/screen" | strip_colors | tr -d '\r')"
}
calls() { paste -sd';' "$CALLS"; }

# ------------------------------------------------------------
# What is waiting
# ------------------------------------------------------------

waiting 12 1 0
run_update n
has "official updates are counted" "Official   12 updates" "$OUT"
has "one AUR update" "AUR        1 update" "$OUT"
has "Flatpak with nothing waiting" "Flatpak    up to date" "$OUT"
has "asks once" "Update now? [Y/n]" "$OUT"
has "said no: says so" "Nothing was changed." "$OUT"
is "said no: nothing is run" "$(calls)" ""

waiting 0 0 0
run_update ""
has "nothing waiting: says so" "Your apps are up to date." "$OUT"
hasnt "nothing waiting: no question" "Update now?" "$OUT"
is "nothing waiting: nothing is run" "$(calls)" ""

: >"$FAKE/viresta-out"
waiting 0 0 0
run_update ""
has "a new Viresta is shown" "Viresta    9.9.9 is out, run viresta update" "$OUT"
rm "$FAKE/viresta-out"

waiting 3 0 0
run_update "" --check
has "--check: shows what is waiting" "Official   3 updates" "$OUT"
hasnt "--check: no question" "Update now?" "$OUT"
is "--check: nothing is run" "$(calls)" ""

# ------------------------------------------------------------
# Updating
# ------------------------------------------------------------

waiting 2 1 3
run_update ""
is "Enter is yes: paru, then Flatpak" "$(calls)" "paru -Syu;flatpak update -y"
has "says each step" "[1/2] Updating official and AUR packages" "$OUT"
has "the Flatpak step" "[2/2] Updating Flatpak apps" "$OUT"
has "finishes" "Update complete" "$OUT"
has "and how long it took" "Time taken:" "$OUT"
hasnt "the same kernel: no reboot hint" "Reboot" "$OUT"

waiting 2 0 0
run_update "" --yes
is "--yes: no question" "$(grep -c 'Update now?' <<<"$OUT")" "0"
is "nothing for Flatpak: only paru" "$(calls)" "paru -Syu"
has "one step" "[1/1] Updating official and AUR packages" "$OUT"

rm "$BIN/paru"
waiting 2 0 0
run_update ""
is "no paru: pacman" "$(calls)" "sudo pacman -Syu"
hasnt "no paru: no AUR line" "AUR" "$OUT"
fake paru 'if [ "$1" = -Qua ]; then :; else echo "paru $*" >>"$CALLS"; [ ! -e "$FAKE/fail-pacman" ]; fi'

rm -r "$KERNEL_MODULES_DIR/6.0-test"
waiting 1 0 0
run_update ""
has "a new kernel: says to reboot" "A new kernel was installed. Reboot to start using it." "$OUT"
mkdir -p "$KERNEL_MODULES_DIR/6.0-test"

: >"$FAKE/fail-pacman"
waiting 1 0 2
run_update ""
is "the package update fails: stops" "$STATUS" "1"
has "the package update fails: says so" "The package update stopped. Nothing else was updated." "$OUT"
hasnt "the package update fails: no Flatpak" "flatpak update" "$(calls)"
rm "$FAKE/fail-pacman"

# ------------------------------------------------------------
# Refusing
# ------------------------------------------------------------

is "an unknown option" "$(bash "$UPDATE" --nope 2>&1 >/dev/null | head -n 1)" "Unknown option: --nope"
is "an unknown option fails" "$(bash "$UPDATE" --nope >/dev/null 2>&1; echo $?)" "2"
is "help" "$(bash "$UPDATE" --help | grep -c 'update \[options\]')" "1"
fake id 'echo 0'
is "as root: refuses" "$(bash "$UPDATE" 2>&1; echo "exit=$?")" "Run update as your normal user. It asks for your password when it needs it.
exit=1"
rm "$BIN/id"
rm "$BIN/pacman"
if ! command -v pacman >/dev/null 2>&1; then
    is "not Arch: refuses" "$(bash "$UPDATE" 2>&1 | head -n 1)" "update is for Arch Linux and distros based on it, like CachyOS."
else
    skip "not Arch: this system has a real pacman"
fi

finish
