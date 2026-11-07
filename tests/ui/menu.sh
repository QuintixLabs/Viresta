#!/usr/bin/env bash

# menu.sh
# Tests the install menu in a real terminal, and saving and reading its options.

source "$(dirname "$0")/../shared/helpers.sh"

copy_viresta

# ------------------------------------------------------------
# The menu
# ------------------------------------------------------------

cat >"$TEST_DIR/menu.sh" <<'EOF'
SCRIPT_DIR="$1"; VERBOSE=0
source "$SCRIPT_DIR/lib/ui/messages.sh"; source "$SCRIPT_DIR/lib/ui/menu.sh"
ui_init 2>/dev/null
add_option a "Vicinae" "Short" 1 "Applications"
add_option s "rename" "Other" 1 "Scripts"
add_option drivers "Install drivers" "mesa, vulkan-radeon" 1 "Drivers"
choose_options
option_enabled drivers && echo RESULT=on || echo RESULT=off
EOF

# Down, down, space, enter turns Drivers off.
screen="$(printf '%s' $'jj \n' | script -qec "stty cols 80; bash '$TEST_DIR/menu.sh' '$VIRESTA'" /dev/null 2>/dev/null)"
is "toggling a row works" "$(grep -c 'RESULT=off' <<<"$screen")" "1"

# ------------------------------------------------------------
# Saved options
# ------------------------------------------------------------

(
    SETUP_DIR="$VIRESTA/setup"
    source "$SETUP_DIR/shared/variables.sh"
    eval "$(sed -n '/^save_options() {/,/^}/p' "$VIRESTA/install.sh")"
    fresh() {
        unset USE_NEW_THING
        USE_VICINAE=1 USE_RENAME_WALLPAPERS=1 USE_DRIVERS=1
        rm -f "$SAVED_OPTIONS_FILE"
        mkdir -p "$(dirname "$SAVED_OPTIONS_FILE")"
    }
    all() { printf '%s %s %s' "$USE_VICINAE" "$USE_RENAME_WALLPAPERS" "$USE_DRIVERS"; }

    fresh; load_saved_options
    is "no file: the defaults" "$(all)" "1 1 1"
    fresh; printf 'vicinae=0\nrename_wallpapers=1\ndrivers=1\n' >"$SAVED_OPTIONS_FILE"; load_saved_options
    is "read back: vicinae off" "$(all)" "0 1 1"
    fresh; printf 'vicinae=1\nrename_wallpapers=0\n' >"$SAVED_OPTIONS_FILE"; load_saved_options
    is "a file from before drivers existed" "$(all)" "1 0 1"
    fresh; printf 'drivers=0' >"$SAVED_OPTIONS_FILE"; load_saved_options
    is "no newline at the end: still read" "$(all)" "1 1 0"
    fresh; USE_DRIVERS=0; printf 'drivers=1\n' >"$SAVED_OPTIONS_FILE"; load_saved_options
    is "a saved choice beats a default that is off" "$USE_DRIVERS" "1"

    fresh
    printf 'bad line\n=1\nvicinae=maybe\nVICINAE=0\nrm -rf /=1\n$(touch %s/pwned)=0\ndrivers=0\n\n' "$TEST_DIR" >"$SAVED_OPTIONS_FILE"
    load_saved_options
    is "damaged lines are skipped, good ones read" "$(all)" "1 1 0"
    missing "nothing in the file gets run" "$TEST_DIR/pwned"

    fresh; USE_VICINAE=0; USE_DRIVERS=0; save_options
    is "every option is saved" "$(sort "$SAVED_OPTIONS_FILE" | paste -sd,)" "drivers=0,gaming=1,rename_wallpapers=1,update_notifications=1,update_script=1,vicinae=0"
    fresh; USE_RENAME_WALLPAPERS=0; save_options; saved="$(cat "$SAVED_OPTIONS_FILE")"
    USE_RENAME_WALLPAPERS=1; load_saved_options
    is "saved and read back" "$(all)" "1 0 1"
    save_options
    is "saving again changes nothing" "$(cat "$SAVED_OPTIONS_FILE")" "$saved"
    fresh; USE_NEW_THING=0; save_options
    is "a new option needs no list" "$(grep -c '^new_thing=0$' "$SAVED_OPTIONS_FILE")" "1"
    unset USE_NEW_THING; load_saved_options
    is "and is read back" "${USE_NEW_THING:-unset}" "0"

    # Like GitHub's USE_BAZEL_FALLBACK_VERSION, which once ended up in the file.
    fresh; export USE_OTHER_PROGRAM=silent; save_options
    is "another program's USE_ setting is not saved" "$(grep -c '^other_program=' "$SAVED_OPTIONS_FILE")" "0"
    unset USE_OTHER_PROGRAM

    printf 'vicinae=0\ndrivers=1\n' >"$SAVED_OPTIONS_FILE"
    save_option drivers 0
    is "changing one option keeps the others" "$(sort "$SAVED_OPTIONS_FILE" | paste -sd,)" "drivers=0,vicinae=0"
    echo "=== $PASSED $FAILED" >"$TEST_DIR/counts"
)
read -r _ PASSED FAILED <"$TEST_DIR/counts"

# ------------------------------------------------------------
# Options and logs
# ------------------------------------------------------------

for option in --fast --no-aur --no-vicinae --no-rename-wallpapers --no-vm; do
    is "install.sh refuses the old $option" "$(cd "$VIRESTA" && bash ./install.sh "$option" >/dev/null 2>&1 </dev/null; echo $?)" "2"
done

STATE="$HOME/.local/state/viresta"
mkdir -p "$STATE"
for pair in install:failures.log update:update-failures.log uninstall:uninstall-failures.log; do
    script="${pair%%:*}"
    log="$STATE/${pair#*:}"
    printf 'Could not install: foo\n' >"$log"
    has "$script --logs: shows what failed" "Could not install: foo" "$(cd "$VIRESTA" && bash "./$script.sh" --logs)"
    rm -f "$log"
done

LOG="$STATE/install.log"
echo keep >"$LOG"
(cd "$VIRESTA" && bash ./install.sh --help >/dev/null)
is "help leaves the log alone" "$(cat "$LOG")" "keep"

finish
