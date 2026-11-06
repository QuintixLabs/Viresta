#!/usr/bin/env bash

# update.sh
# Runs the real update.sh on a fake system after an install: what it keeps of the user's,
# how it merges configs both sides changed, and new packages. download.sh does the rest.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system
C="$HOME/.config"
ST="$HOME/.local/state"
V="$ST/viresta"

run_script ./install.sh "" "hunter2"
is "the install before it finishes" "$STATUS" "0"

# Updates run as if the download already happened. download.sh tests downloading.
update() { VIRESTA_PULLED=1 run_script ./update.sh "$@"; }

# ------------------------------------------------------------
# Nothing new
# ------------------------------------------------------------

snapshot >"$TEST_DIR/before"
update "hunter2"
is "finishes" "$STATUS" "0"
snapshot >"$TEST_DIR/after"
is "nothing of the user's changes" "$(changes "$TEST_DIR/before" "$TEST_DIR/after" | grep -v '\.local/state/viresta/')" ""

# ------------------------------------------------------------
# The user changes things, and Viresta does too
# ------------------------------------------------------------

mkdir -p "$C/obs-studio"
printf 'my scene\n' >"$C/obs-studio/scene.json"
sed -i 's/^Theme=.*/Theme=com.obsproject.Yami.Grey/' "$C/obs-studio/user.ini"
sed -i 's/^PowerButtonAction=.*/PowerButtonAction=1/' "$C/powerdevilrc"
sed -i 's|^Image=.*|Image=file:///my/own.jpg|' "$C/plasma-org.kde.plasma.desktop-appletsrc"
printf '\n[Mine]\nkey=1\n' >>"$C/kglobalshortcutsrc"
printf '\nLookAndFeelPackage=org.viresta.light.desktop\n' >>"$C/kdeglobals"
printf '%s\n' org.viresta.light.desktop >"$V/applied-theme"
ln -sfn /my/own.jpg "$SYS/var/lib/viresta/login-wallpaper.jpg"
printf 'my colors\n' >"$SYS/var/lib/viresta/login-colors"
printf 'my picture\n' >"$HOME/.face.icon"
sed -i 's/0.421875/0.1/g' "$ST/wireplumber/stream-properties"
printf 'vicinae=1\nrename_wallpapers=0\nmine=1\n' >"$C/viresta/options"
rm "$C/systemd/user/graphical-session.target.wants/vicinae.service"
rm "$HOME/Pictures/Wallpapers/Viresta Dark/01. Viresta Dark.jpg"
printf 'mine\n' >"$HOME/Pictures/Wallpapers/Viresta Dark/my-wallpaper.jpg"
sed -i 's/"workbench.colorTheme": "Vesper"/"workbench.colorTheme": "MyTheme"/' "$C/VSCodium/User/settings.json"
sed -i '1i # my kitty comment' "$C/kitty/kitty.conf"
rm "$C/kitty/light-theme.auto.conf"
# Apps the user removed must not come back, and the Gaming row is never added by an update.
sed -i '/^haruna$/d; /^steam$/d' "$FAKE_DB"

# And a new version of Viresta.
jq '."window.zoomLevel" = 1 | ."workbench.colorTheme" = "ViresTheme"' "$VIRESTA/config/vscodium/settings.json" >"$TEST_DIR/new.json"
cp "$TEST_DIR/new.json" "$VIRESTA/config/vscodium/settings.json"
printf 'changed\n' >>"$VIRESTA/config/kde/power/desktop-powerdevilrc"
printf '\n# new from viresta\nenable_audio_bell no\n' >>"$VIRESTA/config/kitty/kitty.conf"
printf 'new from viresta\n' >"$VIRESTA/config/kitty/light-theme.auto.conf"
printf 'new-wallpaper\n' >"$VIRESTA/config/wallpapers/Viresta Dark/10. Viresta.jpg"
printf '# changed\n' >>"$VIRESTA/config/themes/viresta-theme-sync"
printf '\nnewrepoapp\n' >>"$VIRESTA/packages/apps/pacman.txt"
printf '\nnewauraapp\n' >>"$VIRESTA/packages/apps/aur.txt"

snapshot >"$TEST_DIR/before"
: >"$FAKE_CALLS"
update "hunter2"
is "finishes with both sides changed" "$STATUS" "0"
snapshot >"$TEST_DIR/after"
changed="$(changes "$TEST_DIR/before" "$TEST_DIR/after" | grep -v '\.local/state/viresta/')"
for file in plasma-org.kde.plasma.desktop-appletsrc kglobalshortcutsrc kdeglobals viresta/options powerdevilrc obs-studio/user.ini; do
    hasnt "$file untouched" "$file" "$changed"
done
is "the chosen theme is kept" "$(cat "$V/applied-theme")" "org.viresta.light.desktop"
is "the login wallpaper is kept" "$(readlink "$SYS/var/lib/viresta/login-wallpaper.jpg")" "/my/own.jpg"
is "the login colors are kept" "$(cat "$SYS/var/lib/viresta/login-colors")" "my colors"
is "the profile picture is kept" "$(cat "$HOME/.face.icon")" "my picture"
has "the notification volume is kept" '[0.1, 0.1]' "$(cat "$ST/wireplumber/stream-properties")"
missing "Vicinae turned off stays off" "$C/systemd/user/graphical-session.target.wants/vicinae.service"
missing "a deleted wallpaper stays deleted" "$HOME/Pictures/Wallpapers/Viresta Dark/01. Viresta Dark.jpg"
exists "their own wallpaper stays" "$HOME/Pictures/Wallpapers/Viresta Dark/my-wallpaper.jpg"
exists "a new wallpaper arrives" "$HOME/Pictures/Wallpapers/Viresta Dark/10. Viresta.jpg"
has "Viresta's own script is replaced" "# changed" "$(cat "$HOME/.local/bin/viresta-theme-sync")"
is "the new script gets the login path filled in" "$(grep -c "^LOGIN_WALLPAPER=\"$SYS" "$HOME/.local/bin/viresta-theme-sync")" "1"

settings="$C/VSCodium/User/settings.json"
is "both changed the theme: theirs stays" "$(jq -r '."workbench.colorTheme"' "$settings")" "MyTheme"
is "they left the zoom alone: the new one arrives" "$(jq -r '."window.zoomLevel"' "$settings")" "1"
has "they are told about the theme" "Kept your workbench.colorTheme" "$OUT"
has "kitty: their line stays" "# my kitty comment" "$(cat "$C/kitty/kitty.conf")"
has "kitty: the new line arrives" "enable_audio_bell no" "$(cat "$C/kitty/kitty.conf")"
missing "kitty: a file they deleted stays deleted" "$C/kitty/light-theme.auto.conf"
hasnt "Steam they removed is not brought back" "steam" "$(cat "$FAKE_DB")"
has "a new repo package is installed" "newrepoapp" "$(cat "$FAKE_DB")"
has "a new AUR package is installed" "newauraapp" "$(cat "$FAKE_DB")"
hasnt "a removed app is not brought back" "haruna" "$(cat "$FAKE_DB")"
hasnt "no full system update" "-Syu" "$(cat "$FAKE_CALLS")"

update "hunter2"
hasnt "the same update again: not told twice" "Kept your workbench.colorTheme" "$OUT"
is "the same update again: still their theme" "$(jq -r '."workbench.colorTheme"' "$settings")" "MyTheme"

jq '."editor.fontLigatures" = false' "$VIRESTA/config/vscodium/settings.json" >"$TEST_DIR/new.json"
cp "$TEST_DIR/new.json" "$VIRESTA/config/vscodium/settings.json"
update "hunter2"
is "a setting they never changed follows Viresta" "$(jq -r '."editor.fontLigatures"' "$settings")" "false"
is "and theirs still stays" "$(jq -r '."workbench.colorTheme"' "$settings")" "MyTheme"

# ------------------------------------------------------------
# Merging, when it gets hard
# ------------------------------------------------------------

# A comment makes settings.json something jq cannot read.
sed -i '1i // my comment' "$settings"
sed -i 's/"workbench.preferredLightColorTheme": "Light 2026"/"workbench.preferredLightColorTheme": "MyLight"/' "$settings"
jq '."workbench.preferredLightColorTheme" = "VirestaLightNew"' "$VIRESTA/config/vscodium/settings.json" >"$TEST_DIR/new.json"
cp "$TEST_DIR/new.json" "$VIRESTA/config/vscodium/settings.json"
cp "$settings" "$TEST_DIR/settings-before"
update "hunter2"
is "comments in settings.json: the file is unchanged" "$(cat "$settings")" "$(cat "$TEST_DIR/settings-before")"
missing "comments in settings.json: no new file needed" "$settings.viresta-new"
has "comments in settings.json: they are told" "Kept some of your settings in .config/VSCodium/User/settings.json" "$OUT"
sed -i '1d' "$settings"

kitty="$C/kitty/kitty.conf"
sed -i 's/^enable_audio_bell no/enable_audio_bell maybe/' "$kitty"
sed -i 's/^enable_audio_bell no/enable_audio_bell yes/' "$VIRESTA/config/kitty/kitty.conf"
sed -i 's/^font_size .*/font_size 11/' "$VIRESTA/config/kitty/kitty.conf"
update "hunter2"
has "the same line changed: theirs stays" "enable_audio_bell maybe" "$(cat "$kitty")"
hasnt "the same line changed: Viresta's does not arrive" "enable_audio_bell yes" "$(cat "$kitty")"
has "the same line changed: other changes still arrive" "font_size 11" "$(cat "$kitty")"
hasnt "no conflict markers" "<<<<<<<" "$(cat "$kitty")"
missing "no new file needed" "$kitty.viresta-new"
has "they are told" "Kept some of your settings in .config/kitty/kitty.conf" "$OUT"
update
hasnt "not told again next time" "Kept some of your settings in .config/kitty" "$OUT"
has "and their line still stays" "enable_audio_bell maybe" "$(cat "$kitty")"

# ------------------------------------------------------------
# A new package that needs a system update
# ------------------------------------------------------------

printf 'needsupgrade\n' >>"$VIRESTA/packages/apps/pacman.txt"
export NEEDS_UPGRADE=needsupgrade
rm -f "$FAKE_DB.upgraded"
update "hunter2" "n"
has "asks first" "may need a full system update" "$OUT"
hasnt "said no: not installed" "needsupgrade" "$(cat "$FAKE_DB")"
has "said no: listed as failed" "Could not install: needsupgrade" "$OUT"
missing "said no: no system update" "$FAKE_DB.upgraded"
hasnt "said no: tried again next time" "needsupgrade" "$(cat "$V/known-packages")"
update "hunter2" "y"
has "said yes next time: installed" "needsupgrade" "$(cat "$FAKE_DB")"
exists "said yes: the system was updated" "$FAKE_DB.upgraded"
unset NEEDS_UPGRADE

finish
