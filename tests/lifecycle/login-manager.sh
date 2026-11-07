#!/usr/bin/env bash

# login-manager.sh
# Runs the real install.sh and uninstall.sh on a fake system where another login screen
# is on, like Plasma Login Manager on CachyOS with KDE. Only one can be on at a time.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system
V="$HOME/.local/state/viresta"
login_screen() { local t; t="$(readlink "$FAKE_DM_LINK" 2>/dev/null)"; t="${t##*/}"; echo "${t%.service}"; }

# Plasma Login Manager is on, the way CachyOS sets it up.
mkdir -p "$(dirname "$FAKE_DM_LINK")"
ln -s /usr/lib/systemd/system/plasmalogin.service "$FAKE_DM_LINK"

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

run_script ./install.sh "" "hunter2"
is "another login screen on: the install finishes" "$STATUS" "0"
hasnt "no failure about SDDM" "Failed to enable sddm" "$OUT"
is "SDDM is the login screen now" "$(login_screen)" "sddm"
is "the old one is remembered" "$(cat "$V/login-manager-before" 2>/dev/null)" "plasmalogin"
has "the log says it switched" "Switched the login screen from plasmalogin to SDDM" "$(cat "$V/install.log")"

# Again, as after viresta install: SDDM is already on, so nothing switches.
run_script ./install.sh "" "hunter2"
is "again: finishes" "$STATUS" "0"
is "again: still SDDM" "$(login_screen)" "sddm"
is "again: still remembers the first one" "$(cat "$V/login-manager-before" 2>/dev/null)" "plasmalogin"

# ------------------------------------------------------------
# Uninstall
# ------------------------------------------------------------

run_script "./uninstall.sh --dry-run"
has "dry run: says it would turn it back on" "Would turn plasmalogin back on" "$OUT"
is "dry run: changes nothing" "$(login_screen)" "sddm"

run_script ./uninstall.sh "y" "n" "hunter2"
is "uninstall: finishes" "$STATUS" "0"
is "uninstall: the old login screen is back" "$(login_screen)" "plasmalogin"
has "uninstall: says so" "Turned plasmalogin back on" "$(cat "$V/uninstall.log")"

# ------------------------------------------------------------
# The old one cannot come back
# ------------------------------------------------------------

run_script ./install.sh "" "hunter2"
is "installed again: SDDM" "$(login_screen)" "sddm"
export FAKE_DM_BROKEN=plasmalogin.service
run_script ./uninstall.sh "y" "n" "hunter2"
unset FAKE_DM_BROKEN
is "cannot come back: SDDM stays, so there is a login screen" "$(login_screen)" "sddm"
has "cannot come back: says so" "Could not turn plasmalogin back on, so SDDM stays your login screen" "$OUT"

finish
