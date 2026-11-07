#!/usr/bin/env bash

# alerts.sh
# Tests the update alerts: one notification for each new release, its buttons, turning
# them off and on, and staying quiet when something is missing.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
make_clone 1.0.0

# notify-send says what it was asked to show, and clicks whatever is in $FAKE/click.
export FAKE="$TEST_DIR/fake"
mkdir -p "$FAKE"
cat >"$BIN/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE/notify-args"
echo x >>"$FAKE/notify-count"
[ ! -e "$FAKE/notify-fails" ] || exit 1
cat "$FAKE/click" 2>/dev/null
exit 0
EOF
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >"$FAKE/kitty-args"\n' >"$BIN/kitty"
chmod +x "$BIN/notify-send" "$BIN/kitty"

# Installed the way setup.sh does it, with sudo doing nothing.
(
    SETUP_DIR="$VIRESTA/setup"
    source "$SETUP_DIR/shared/variables.sh"
    source "$SETUP_DIR/shared/tracking.sh"
    source "$SETUP_DIR/viresta/command.sh"
    source "$SETUP_DIR/viresta/update-check.sh"
    sudo() { :; }
    install_viresta_command >/dev/null
    install_update_check >/dev/null
)
STATE="$HOME/.local/state/viresta"
CHECK="$HOME/.local/bin/viresta-update-check"
OPTIONS="$HOME/.config/viresta/options"
: >"$STATE/installed-files"

alerts() { if [ -f "$FAKE/notify-count" ]; then wc -l <"$FAKE/notify-count"; else echo 0; fi; }
clean() { rm -f "$FAKE"/* "$STATE/notified-version"; }
check() { bash "$CHECK"; echo $?; }
title() { tail -n 1 "$FAKE/notify-args"; }

# ------------------------------------------------------------
# Installing
# ------------------------------------------------------------

is "script installed and runnable" "$([ -x "$CHECK" ] && echo yes)" "yes"
is "folder saved" "$(cat "$STATE/folder")" "$VIRESTA"
is "timer turned on for the session" "$(readlink "$HOME/.config/systemd/user/graphical-session.target.wants/viresta-update-check.timer")" "../viresta-update-check.timer"

# ------------------------------------------------------------
# Once for each release
# ------------------------------------------------------------

clean
is "up to date: exits fine" "$(check)" "0"
is "up to date: no alert" "$(alerts)" "0"

release 1.1.0
clean
before="$(git -C "$VIRESTA" rev-parse HEAD)"
is "new release: exits fine" "$(check)" "0"
is "new release: one alert" "$(alerts)" "1"
is "new release: title" "$(title)" "Viresta 1.1.0 is available"
is "new release: update button" "$(grep -c -x -- '--action=update=Update' "$FAKE/notify-args")" "1"
is "new release: off button" "$(grep -c -x -- "--action=off=Don't show again" "$FAKE/notify-args")" "1"
is "new release: stays on screen" "$(grep -c -x -- '--expire-time=0' "$FAKE/notify-args")" "1"
is "version remembered" "$(cat "$STATE/notified-version")" "1.1.0"
is "the folder is not moved" "$(git -C "$VIRESTA" rev-parse HEAD)" "$before"
is "no tags are downloaded" "$(git -C "$VIRESTA" tag)" "v1.0.0"
missing "the X changes no setting" "$OPTIONS"
missing "the X opens nothing" "$FAKE/kitty-args"

check >/dev/null
is "same release: no second alert" "$(alerts)" "1"
release 1.2.0
check >/dev/null
is "next release: alerts again" "$(alerts)" "2"
is "next release: newest number" "$(title)" "Viresta 1.2.0 is available"

release 1.10.0
for tag in v9.0.0-rc1 'v8<b>x' other; do git -C "$DEV" tag "$tag"; done
git -C "$DEV" push -q origin v9.0.0-rc1 'v8<b>x' other
clean
check >/dev/null
is "1.10.0 beats 1.2.0, and odd tags are ignored" "$(title)" "Viresta 1.10.0 is available"

# ------------------------------------------------------------
# Buttons
# ------------------------------------------------------------

clean
echo update >"$FAKE/click"
is "update button: exits fine" "$(check)" "0"
is "update button: opens kitty in the folder" "$(sed -n '1,2p' "$FAKE/kitty-args" | tr '\n' ' ')" "--directory $VIRESTA "
is "update button: remembered" "$(cat "$STATE/notified-version")" "1.10.0"

# What kitty runs, with an update that stops like Ctrl+C does and a shell that says it
# started. The window ends up in the shell, and nothing failed as far as kitty knows.
mapfile -t kitty_args <"$FAKE/kitty-args"
printf '#!/bin/sh\necho UPDATE RAN\nexit 130\n' >"$TEST_DIR/stopped-update"
printf '#!/bin/sh\necho SHELL STARTED\n' >"$TEST_DIR/fake-shell"
chmod +x "$TEST_DIR/stopped-update" "$TEST_DIR/fake-shell"
kitty_args[$((${#kitty_args[@]} - 1))]="$TEST_DIR/stopped-update"
out="$(SHELL="$TEST_DIR/fake-shell" "${kitty_args[@]:2}")"
is "update button: kitty sees no failure" "$?" "0"
is "update button: the update runs, then the shell" "$(tr '\n' ' ' <<<"$out")" "UPDATE RAN SHELL STARTED "

mkdir -p "$(dirname "$OPTIONS")"
printf 'vicinae=0\ndrivers=1\n' >"$OPTIONS"
clean
echo off >"$FAKE/click"
is "off button: exits fine" "$(check)" "0"
is "off button: saved" "$(grep -c -x 'update_notifications=0' "$OPTIONS")" "1"
is "off button: other options kept" "$(grep -c -E '^(vicinae=0|drivers=1)$' "$OPTIONS")" "2"
missing "off button: opens nothing" "$FAKE/kitty-args"

release 2.0.0
clean
check >/dev/null
is "turned off: the next release is quiet" "$(alerts)" "0"

# ------------------------------------------------------------
# Turning them off and on
# ------------------------------------------------------------

is "on: message" "$(viresta update --notifications-on)" "Update notifications are on."
is "on: saved" "$(grep -c -x 'update_notifications=1' "$OPTIONS")" "1"
is "on: one line only" "$(grep -c '^update_notifications=' "$OPTIONS")" "1"
is "on: other options kept" "$(grep -c -E '^(vicinae=0|drivers=1)$' "$OPTIONS")" "2"
check >/dev/null
is "turned on: alerts" "$(alerts)" "1"

echo 2.0.0 >"$STATE/notified-version"
viresta update --notifications-off >/dev/null
is "off: saved" "$(grep -c -x 'update_notifications=0' "$OPTIONS")" "1"
is "off: keeps what was alerted" "$(cat "$STATE/notified-version")" "2.0.0"
viresta update --notifications-on >/dev/null
missing "on: forgets what was alerted" "$STATE/notified-version"
is "the option leaves the folder alone" "$(git -C "$VIRESTA" rev-parse HEAD)" "$before"
missing "the option leaves no update log" "$STATE/update.log"

help="$(viresta update --help | strip_colors)"
is "help: off" "$(grep -c -- '--notifications-off Stop alerting' <<<"$help")" "1"
is "help: on lines up" "$(grep -c -- '--notifications-on  Alert' <<<"$help")" "1"

# A saved "off" survives what install.sh does with the options.
viresta update --notifications-off >/dev/null
saved="$(
    SETUP_DIR="$VIRESTA/setup"
    source "$SETUP_DIR/shared/variables.sh"
    eval "$(sed -n '/^save_options() {/,/^}/p' "$VIRESTA/install.sh")"
    load_saved_options
    save_options
    cat "$SAVED_OPTIONS_FILE"
)"
is "install keeps it off" "$(grep -c -x 'update_notifications=0' <<<"$saved")" "1"
rm -f "$OPTIONS"
is "on by default" "$(SETUP_DIR="$VIRESTA/setup"; source "$SETUP_DIR/shared/variables.sh"; load_saved_options; echo "$USE_UPDATE_NOTIFICATIONS")" "1"

# ------------------------------------------------------------
# Branches
# ------------------------------------------------------------

clean
git -C "$VIRESTA" checkout -q master
git -C "$VIRESTA" reset -q --hard "$before"
check >/dev/null
is "master: alerts" "$(alerts)" "1"
clean
git -C "$VIRESTA" checkout -q -b dev
check >/dev/null
is "another branch: quiet" "$(alerts)" "0"
git -C "$VIRESTA" checkout -q v1.0.0

# ------------------------------------------------------------
# Quiet when something is missing
# ------------------------------------------------------------

clean
: >"$FAKE/notify-fails"
is "alert fails: exits fine" "$(check)" "0"
missing "alert fails: tries again next time" "$STATE/notified-version"

clean
no_internet
is "no internet: exits fine" "$(check)" "0"
is "no internet: no alert" "$(alerts)" "0"
internet_back

clean
mv "$VIRESTA" "$TEST_DIR/Moved"
is "folder moved: exits fine" "$(check)" "0"
is "folder moved: no alert" "$(alerts)" "0"
mv "$TEST_DIR/Moved" "$VIRESTA"

# A folder from before the alerts, like one moved back to an older release.
mkdir -p "$TEST_DIR/old/setup/shared" "$TEST_DIR/old/lib/system"
printf 'CONFIG_DIR="$HOME/.config"\n' >"$TEST_DIR/old/setup/shared/variables.sh"
printf 'viresta_version() { echo 0.1.0; }\n' >"$TEST_DIR/old/lib/system/version.sh"
echo "$TEST_DIR/old" >"$STATE/folder"
clean
is "old folder: quiet, no error" "$(bash "$CHECK" 2>&1; echo "exit=$?")" "exit=0"
is "old folder: no alert" "$(alerts)" "0"

rm -f "$STATE/folder"
is "no saved folder: exits fine" "$(check)" "0"
is "no saved folder: no alert" "$(alerts)" "0"

# ------------------------------------------------------------
# The timer
# ------------------------------------------------------------

timer="$VIRESTA/config/systemd/viresta-update-check.timer"
is "timer: after login" "$(grep -c -x 'OnActiveSec=1min' "$timer")" "1"
is "timer: every 6 hours" "$(grep -c -x 'OnUnitActiveSec=6h' "$timer")" "1"
is "timer: only in a desktop session" "$(grep -c -x 'WantedBy=graphical-session.target' "$timer")" "1"
is "service: runs the script" "$(grep -c -x 'ExecStart=%h/.local/bin/viresta-update-check' "$VIRESTA/config/systemd/viresta-update-check.service")" "1"

finish
