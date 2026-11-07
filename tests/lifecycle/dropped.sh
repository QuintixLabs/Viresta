#!/usr/bin/env bash

# dropped.sh
# Runs the real update.sh on a fake system after an install, once Viresta stops including
# some apps: asking once, keeping or removing them, and remembering the answer only once
# the update is done.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system
V="$HOME/.local/state/viresta"
APPS="$SYS/usr/share/applications"

run_script ./install.sh "" "hunter2"
is "the install before it finishes" "$STATUS" "0"

update() { VIRESTA_PULLED=1 run_script ./update.sh "$@"; }
installed() { if grep -qxF "$1" "$FAKE_DB"; then echo yes; else echo no; fi; }

# ------------------------------------------------------------
# Viresta stops including some apps
# ------------------------------------------------------------

# Menu entries, the way pacman -Ql finds them. jq has none, since it is no app.
printf '[Desktop Entry]\nName=Haruna\nGenericName=Media Player\n' >"$APPS/org.kde.haruna.desktop"
printf '[Desktop Entry]\nName=Gwenview\n' >"$APPS/org.kde.gwenview.desktop"
printf '[Desktop Entry]\nName=fooyin\nGenericName=fooyin Music Player\n' >"$APPS/org.fooyin.fooyin.desktop"
printf '[Desktop Entry]\nName=Firefox\nGenericName=Web Browser\n' >"$APPS/firefox.desktop"
printf '%s\n' "haruna $APPS/org.kde.haruna.desktop" "gwenview $APPS/org.kde.gwenview.desktop" \
    "fooyin $APPS/org.fooyin.fooyin.desktop" "firefox $APPS/firefox.desktop" \
    "jq /usr/bin/jq" >"$FAKE_DB.files"

# Three apps dropped, plus Firefox, which was there before Viresta, and jq, which is no app.
sed -i '/^haruna$/d; /^gwenview$/d; /^firefox$/d' "$VIRESTA/packages/apps/pacman.txt"
sed -i '/^fooyin$/d' "$VIRESTA/packages/apps/aur.txt"
sed -i '/^jq$/d' "$VIRESTA/packages/system/base.txt"
echo firefox >>"$V/packages-before"

# ------------------------------------------------------------
# Kept
# ------------------------------------------------------------

update "n" "hunter2"
is "kept: finishes" "$STATUS" "0"
has "asks about them" "Viresta no longer includes these apps:" "$OUT"
hasnt "not what was there before Viresta" "firefox" "$OUT"
hasnt "not what is no app" "jq" "$(grep -A6 'no longer includes' <<<"$OUT")"
has "asked before the password" "Remove them?" "$(sed -n '/Password for/q;p' <<<"$OUT")"
is "kept: still installed" "$(installed haruna)$(installed gwenview)$(installed fooyin)" "yesyesyes"
is "kept: remembered" "$(tr '\n' ' ' <"$V/kept-apps")" "fooyin gwenview haruna "

update "hunter2"
is "kept: finishes again" "$STATUS" "0"
hasnt "kept: not asked again" "no longer includes" "$OUT"

# ------------------------------------------------------------
# Stopped before it was done
# ------------------------------------------------------------

rm "$V/kept-apps"
update "y" ""
is "stopped at the password: stops" "$STATUS" "1"
is "stopped at the password: nothing removed" "$(installed haruna)$(installed gwenview)$(installed fooyin)" "yesyesyes"
missing "stopped at the password: nothing remembered" "$V/kept-apps"

update "n" ""
is "said no, then stopped: stops" "$STATUS" "1"
missing "said no, then stopped: not remembered" "$V/kept-apps"

# ------------------------------------------------------------
# Removed
# ------------------------------------------------------------

export CANNOT_REMOVE=gwenview
update "y" "hunter2"
unset CANNOT_REMOVE
is "removed: finishes" "$STATUS" "0"
has "removed: asked again after the stops" "no longer includes" "$OUT"
is "removed: gone" "$(installed haruna)$(installed fooyin)" "nono"
is "needed by something else: kept" "$(installed gwenview)" "yes"
is "needed by something else: not asked again" "$(cat "$V/kept-apps")" "gwenview"
is "the others stay" "$(installed firefox)$(installed jq)" "yesyes"

# ------------------------------------------------------------
# The install run again
# ------------------------------------------------------------

# It must not forget the apps Viresta stopped including, or they are never offered.
echo haruna >>"$FAKE_DB"
run_script ./install.sh "" "hunter2"
is "installed again: finishes" "$STATUS" "0"
has "installed again: still knows the dropped app" "haruna" "$(cat "$V/known-packages")"
update "n" "hunter2"
has "installed again: the update still asks" "haruna" "$(grep -A4 'no longer includes' <<<"$OUT")"

finish
