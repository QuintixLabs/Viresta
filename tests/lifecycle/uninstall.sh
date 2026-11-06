#!/usr/bin/env bash

# uninstall.sh
# Runs the real uninstall.sh on a fake system: the ways out before anything changes, what
# it removes and what it must keep, the packages, and an install from before tracking.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system
C="$HOME/.config"
ST="$HOME/.local/state"
V="$ST/viresta"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

# Someone's setup from before Viresta, backed up during the install.
mkdir -p "$C/kitty" "$HOME/Documents"
printf 'font_size 99\n' >"$C/kitty/kitty.conf"
printf '[General]\nmine=1\n' >"$C/kdeglobals"
printf 'my own file\n' >"$HOME/Documents/notes.txt"
printf 'my own config\n' >"$C/not-viresta.conf"
printf 'firefox\nhtop\n' >>"$FAKE_DB"
run_script ./install.sh "" "y" "hunter2"
is "the install before it finishes" "$STATUS" "0"

# Then their own things on top.
mkdir -p "$C/obs-studio"
printf 'my scene\n' >"$C/obs-studio/scene.json"
printf 'mine\n' >"$HOME/Pictures/Wallpapers/Viresta Dark/my-wallpaper.jpg"
printf 'my picture\n' >"$HOME/.face.icon"
sed -i 's/0.421875/0.1/g' "$ST/wireplumber/stream-properties"

# ------------------------------------------------------------
# The ways out
# ------------------------------------------------------------

snapshot >"$TEST_DIR/before"
cp "$FAKE_DB" "$TEST_DIR/packages-before"

PLASMA_RUNNING=1 run_script ./uninstall.sh "y" "n" "hunter2"
is "Plasma running: stops" "$STATUS" "1"
has "Plasma running: says how" "Log out of Plasma" "$OUT"
hasnt "Plasma running: asks nothing" "Continue?" "$OUT"

run_script "./uninstall.sh --dry-run"
is "dry run: finishes" "$STATUS" "0"
has "dry run: lists the files" "kitty.conf" "$OUT"
has "dry run: says nothing changed" "nothing was changed" "$OUT"
snapshot >"$TEST_DIR/after"
is "dry run: changes nothing" "$(changes "$TEST_DIR/before" "$TEST_DIR/after" | grep -v uninstall)" ""

run_script ./uninstall.sh ""
is "Enter at the warning: finishes" "$STATUS" "0"
has "Enter at the warning: cancelled" "Nothing was changed" "$OUT"
has "the warning is shown" "including any changes you made" "$OUT"
snapshot >"$TEST_DIR/after"
is "cancelling changes nothing" "$(changes "$TEST_DIR/before" "$TEST_DIR/after" | grep -v uninstall)" ""
is "cancelling keeps the packages" "$(cat "$FAKE_DB")" "$(cat "$TEST_DIR/packages-before")"

# ------------------------------------------------------------
# Uninstalling, keeping the apps
# ------------------------------------------------------------

# Lines that must never be followed, whatever ends up in the list.
for line in / /usr /usr/bin/bash /etc /usr/share "$HOME" "$C" "$HOME/Pictures" "$HOME/../outside" "$HOME/Documents/../.." relative/path; do
    echo "$line" >>"$V/installed-files"
done
mkdir -p "$TEST_DIR/outside"
: >"$TEST_DIR/home-marker"
: >"$FAKE_CALLS"
CANNOT_REMOVE=vicinae-bin run_script ./uninstall.sh "y" "n" "hunter2"
is "finishes" "$STATUS" "0"
missing "Viresta's list is gone" "$V/installed-files"
missing "kded5rc is gone, so the browser reminder is back" "$C/kded5rc"
missing "OBS's launcher is gone" "$HOME/.local/share/applications/com.obsproject.Studio.desktop"
missing "OBS's settings are gone" "$C/obs-studio/user.ini"
exists "OBS's scenes stay" "$C/obs-studio/scene.json"
exists "their documents stay" "$HOME/Documents/notes.txt"
exists "their other configs stay" "$C/not-viresta.conf"
exists "their own wallpaper stays" "$HOME/Pictures/Wallpapers/Viresta Dark/my-wallpaper.jpg"
is "bad list lines did nothing" "$([ -e "$TEST_DIR/outside" ] && [ -e "$TEST_DIR/home-marker" ] && echo yes)" "yes"
has "bad list lines are reported" "Did not remove /usr/bin/bash" "$OUT"
is "their picture stays" "$(cat "$HOME/.face.icon" 2>/dev/null)" "my picture"
has "their notification volume stays" '[0.1, 0.1]' "$(cat "$ST/wireplumber/stream-properties")"
is "kitty.conf from before Viresta is back" "$(cat "$C/kitty/kitty.conf")" "font_size 99"
is "kdeglobals from before Viresta is back" "$(cat "$C/kdeglobals")" "$(printf '[General]\nmine=1')"

for path in "$C/plasma-org.kde.plasma.desktop-appletsrc" "$C/kglobalshortcutsrc" "$C/kwinrc" "$C/kactivitymanagerdrc" \
    "$C/powerdevilrc" "$C/VSCodium/User/settings.json" "$C/vicinae/settings.json" "$C/fastfetch" "$C/panel-colorizer" \
    "$C/viresta" "$C/kcm-about-distrorc" "$C/starship.toml" "$HOME/.blerc" \
    "$HOME/.local/bin/viresta-theme-sync" "$HOME/.local/bin/viresta-update-check" \
    "$HOME/.local/share/plasma/look-and-feel/org.viresta.dark.desktop" "$HOME/.local/share/plasma/desktoptheme/viresta-dark" \
    "$HOME/.local/share/color-schemes/VirestaDark.colors" "$HOME/.local/share/icons/YAMIS" "$HOME/.local/share/icons/YAMIS-Light" \
    "$HOME/.local/share/kstyle" "$C/systemd/user/viresta-theme-sync.path" "$C/systemd/user/viresta-update-check.timer" \
    "$C/systemd/user/graphical-session.target.wants" "$SYS/usr/share/icons/Bibata" "$SYS/usr/share/wallpapers/Viresta" \
    "$SYS/var/lib/viresta" "$SYS/etc/sddm.conf.d/viresta.conf" "$SYS/etc/firefox" \
    "$SYS/etc/pacman.d/hooks/viresta-remove-themes.hook" "$SYS/etc/pacman.d/hooks/viresta-default-cursor.hook" \
    "$SYS/usr/share/sddm/themes/breeze/theme.conf.user" "$SYS/usr/share/sddm/themes/breeze/faces/.face.icon" \
    "$SYS/var/lib/sddm/.config/kdeglobals" "$SYS/usr/share/vicinae/themes/viresta-dark.toml" "$SYS/usr/local/bin/viresta" \
    "$SYS/usr/share/bash-completion/completions/viresta" "$SYS/usr/share/fish/vendor_completions.d/viresta.fish"; do
    # An empty folder left behind is fine, and a file or link is not.
    if [ -n "$(find "$path" \( -type f -o -type l \) 2>/dev/null | head -n 1)" ]; then
        fail "gone: ${path#"$HOME"/}"
    else
        pass "gone: ${path#"$HOME"/}"
    fi
done
is "nothing in the home folder still mentions Viresta" "$(grep -rIl -e org.viresta -e viresta- "$C" "$HOME/.local/share" 2>/dev/null)" ""
is "the Viresta lines are out of .bashrc" "$(cat "$HOME/.bashrc" 2>/dev/null | grep -c Viresta)" "0"
is "other SDDM configs stay" "$(cat "$SYS/etc/sddm.conf.d/other.conf")" "keep me"
is "the login theme is KDE's" "$(cat "$SYS/etc/sddm.conf.d/kde_settings.conf")" "$(printf '[Theme]\nCurrent=breeze')"

packages="$(cat "$FAKE_DB")"
hasnt "Panel Colorizer is removed" "plasma6-applets-panel-colorizer" "$packages"
hasnt "starship is removed" "starship" "$packages"
has "kitty is kept: they said no" "kitty" "$packages"
has "paru is kept" "paru" "$packages"
has "a package that cannot go is reported" "vicinae-bin was kept" "$OUT"
has "KDE's themes come back with a reinstall" "default-cursors" "$(grep -- '-S --noconfirm' "$FAKE_CALLS")"
is "only the logs are left" "$(ls "$V" | tr '\n' ' ')" "uninstall-failures.log uninstall.log "
is "multilib stays on, for what was installed from it" "$(grep -c '^\[multilib\]$' "$SYSTEM_PACMAN_CONF")" "1"

run_script ./uninstall.sh
is "run again: nothing to do" "$STATUS" "0"
has "run again: says why" "Viresta is not installed" "$OUT"

# ------------------------------------------------------------
# Removing the apps too, on a fresh system
# ------------------------------------------------------------

rm -rf "$HOME/.config" "$HOME/.local" "$HOME/Pictures" "$HOME/Documents" "$HOME/.face.icon" "$HOME/.cache" "$SYS"
fake_system_folders
printf 'paru\nfirefox\ndolphin\n' >"$FAKE_DB"
run_script ./install.sh "" "hunter2"
is "a fresh install finishes" "$STATUS" "0"
exists "Viresta set the profile picture" "$HOME/.face.icon"
: >"$FAKE_CALLS"
run_script ./uninstall.sh "y" "y" "hunter2"
is "uninstalling with the apps finishes" "$STATUS" "0"
missing "Viresta's picture is gone" "$HOME/.face.icon"
hasnt "Viresta's notification volume is gone" "media.role:Notification" "$(cat "$ST/wireplumber/stream-properties" 2>/dev/null)"
packages="$(cat "$FAKE_DB")"
hasnt "a package under another name is removed by its real name" "otf-outfit" "$packages"
hasnt "and it is not reported as kept" "was kept" "$OUT"
hasnt "kitty is removed" "kitty" "$packages"
hasnt "haruna is removed" "haruna" "$packages"
hasnt "Vicinae is removed" "vicinae-bin" "$packages"
has "firefox stays: it was there before" "firefox" "$packages"
has "dolphin stays" "dolphin" "$packages"
has "Konsole is added, so there is a terminal" "konsole" "$packages"
has "paru stays" "paru" "$packages"
is "KDE's own packages are never removed" "$(grep -- '-Rs' "$FAKE_CALLS" | grep -cE 'plasma-|sddm|breeze|networkmanager|dolphin|firefox')" "0"

# ------------------------------------------------------------
# An install from before tracking existed
# ------------------------------------------------------------

rm -rf "$HOME/.config" "$HOME/.local" "$HOME/Pictures" "$HOME/.face.icon"
printf 'paru\n' >"$FAKE_DB"
run_script ./install.sh "" "hunter2"
sed -i '1i # edited before tracking' "$C/kitty/kitty.conf"
rm -rf "$V/installed-files" "$V/base" "$V/known-packages" "$V/packages-before" "$V/backup"
run_script ./uninstall.sh ""
is "no record: asks for one update first" "$STATUS" "1"
has "no record: says what to do" "Run ./update.sh once" "$OUT"
sed -i '/^haruna$/d' "$FAKE_DB"
VIRESTA_PULLED=1 run_script ./update.sh "hunter2"
is "that update finishes" "$STATUS" "0"
has "their edited kitty.conf is kept" "# edited before tracking" "$(cat "$C/kitty/kitty.conf")"
exists "the new version is saved next to it" "$C/kitty/kitty.conf.viresta-new"
hasnt "a removed app does not come back" "haruna" "$(cat "$FAKE_DB")"
has "the KDE configs are on the list now" "kglobalshortcutsrc" "$(cat "$V/installed-files")"
run_script ./uninstall.sh "y" "n" "hunter2"
is "now uninstall works" "$STATUS" "0"
missing "the KDE configs are gone" "$C/kglobalshortcutsrc"
missing "kitty.conf is gone" "$C/kitty/kitty.conf"
missing "the saved new version is gone" "$C/kitty/kitty.conf.viresta-new"

finish
