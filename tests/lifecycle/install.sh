#!/usr/bin/env bash

# install.sh
# Runs the real install.sh on a fake system: over someone's existing setup, again on top
# of itself, and on a fresh system. Then checks what it put in place.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system
C="$HOME/.config"
V="$HOME/.local/state/viresta"
LIST="$V/installed-files"

# ------------------------------------------------------------
# Over someone's existing setup
# ------------------------------------------------------------

mkdir -p "$C/kitty" "$HOME/Documents"
printf 'font_size 99\n' >"$C/kitty/kitty.conf"
printf '[General]\nmine=1\n' >"$C/kdeglobals"
printf 'firefox\nhtop\n' >>"$FAKE_DB"

# The menu, the backup question and the password.
run_script ./install.sh "" "y" "hunter2"
is "finishes" "$STATUS" "0"
has "asks about a backup" "of your configs that Viresta will replace" "$OUT"
has "counts the two existing configs" "Found 2 of your configs" "$OUT"
is "kitty.conf is backed up" "$(cat "$V/backup/.config/kitty/kitty.conf" 2>/dev/null)" "font_size 99"
is "kdeglobals is backed up" "$(sed -n 2p "$V/backup/.config/kdeglobals" 2>/dev/null)" "mine=1"
is "the uninstall list is written" "$([ -s "$LIST" ] && echo yes)" "yes"
is "the uninstall list has no repeats" "$(sort "$LIST" | uniq -d | wc -l)" "0"
exists "a base copy of kitty.conf, for merging updates" "$V/base/.config/kitty/kitty.conf"
has "firefox is noted as already there" "firefox" "$(cat "$V/packages-before")"
has "new packages are noted" "kitty" "$(cat "$V/known-packages")"
hasnt "the password is never on screen" "hunter2" "$OUT"

is "multilib is turned on" "$(grep -c '^\[multilib\]$' "$SYSTEM_PACMAN_CONF")" "1"
has "before the system update, so its packages are known" "pacman --config" "$(grep -m1 -- '-Sy' "$FAKE_CALLS")"

run_script ./install.sh "" "hunter2"
is "a second install finishes" "$STATUS" "0"
hasnt "a second install does not ask about a backup" "Back them up first" "$OUT"
is "a second install: multilib is still there once" "$(grep -c '^\[multilib\]$' "$SYSTEM_PACMAN_CONF")" "1"

# ------------------------------------------------------------
# What it put in place
# ------------------------------------------------------------

exists "Vicinae starts at login" "$C/systemd/user/graphical-session.target.wants/vicinae.service"
is "update alerts start at login" "$(readlink "$C/systemd/user/graphical-session.target.wants/viresta-update-check.timer")" "../viresta-update-check.timer"
exists "the update check is installed" "$HOME/.local/bin/viresta-update-check"
is "the viresta command is installed" "$([ -x "$SYS/usr/local/bin/viresta" ] && echo yes)" "yes"
exists "Bash completion is installed" "$SYS/usr/share/bash-completion/completions/viresta"
exists "Fish completion is installed" "$SYS/usr/share/fish/vendor_completions.d/viresta.fish"
is "the folder is saved" "$(cat "$V/folder")" "$VIRESTA"
is "About this System shows the version" "$(cat "$C/kcm-about-distrorc")" "$(printf '[General]\nVariant=Viresta %s' "$(folder_version)")"
is "the browser reminder is turned off" "$(cat "$C/kded5rc")" "$(printf '[Module-browserintegrationreminder]\nautoload=false')"
has "kded5rc is on the uninstall list" "$C/kded5rc" "$(cat "$LIST")"
is "power settings" "$([ -s "$C/powerdevilrc" ] && echo yes)" "yes"
has "power settings are on the uninstall list" "$C/powerdevilrc" "$(cat "$LIST")"
for stray in desktop-powerdevilrc laptop-powerdevilrc; do missing "no stray $stray" "$C/$stray"; done
hasnt "the power profiles are not on the list" "-powerdevilrc" "$(cat "$LIST")"

launcher="$HOME/.local/share/applications/com.obsproject.Studio.desktop"
has "OBS's launcher sets its theme first" "viresta-theme-sync --obs; exec obs" "$(cat "$launcher")"
has "OBS's launcher is on the uninstall list" "$launcher" "$(cat "$LIST")"
is "only OBS's settings, nothing else of it" "$(ls "$C/obs-studio")" "user.ini"
has "OBS's settings are on the uninstall list" "$C/obs-studio/user.ini" "$(cat "$LIST")"

is "the Viresta lines are in .bashrc" "$(grep -cxF '# Viresta: start' "$HOME/.bashrc")" "2"
exists "starship config" "$C/starship.toml"
exists "ble.sh config" "$HOME/.blerc"
missing "the shell folder is not copied into .config" "$C/shell"
missing "the wallpapers are not copied into .config" "$C/wallpapers"
is "the wallpapers reach Pictures" "$(ls "$HOME/Pictures/Wallpapers/Viresta Dark" | wc -l)" "6"
is "the dark wallpaper reaches the system" "$([ -s "$SYS/usr/share/wallpapers/Viresta/Viresta Dark.jpg" ] && echo yes)" "yes"
is "the light wallpaper reaches the system" "$([ -s "$SYS/usr/share/wallpapers/Viresta/Viresta Light.jpg" ] && echo yes)" "yes"

# ------------------------------------------------------------
# A fresh system
# ------------------------------------------------------------

rm -rf "$HOME/.config" "$HOME/.local" "$HOME/Pictures" "$HOME/Documents" "$HOME/.face.icon" "$HOME/.cache" \
    "$HOME/.bashrc" "$HOME/.blerc" "$SYS"
fake_system_folders
printf 'paru\nfirefox\ndolphin\n' >"$FAKE_DB"
run_script ./install.sh "" "hunter2"
is "a fresh install finishes" "$STATUS" "0"
hasnt "nothing to back up: no question" "Back them up" "$OUT"
missing "nothing to back up: no backup folder" "$V/backup"
exists "Viresta's profile picture is set" "$HOME/.face.icon"

finish
