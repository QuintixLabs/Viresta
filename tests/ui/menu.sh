#!/usr/bin/env bash

# menu.sh
# Tests the install menu in a real terminal, saving and reading its options, and the
# help screens of the three scripts.

source "$(dirname "$0")/../shared/helpers.sh"

copy_viresta

# ------------------------------------------------------------
# The menu
# ------------------------------------------------------------

# The real menu, with a description far too long for the terminal.
cat >"$TEST_DIR/menu.sh" <<'EOF'
SCRIPT_DIR="$1"; VERBOSE=0
source "$SCRIPT_DIR/lib/ui/messages.sh"; source "$SCRIPT_DIR/lib/ui/menu.sh"
ui_init 2>/dev/null
add_option a "Vicinae" "Short" 1 "Applications"
add_option s "rename" "Other" 1 "Scripts"
add_option drivers "Install drivers" "UHD Graphics 770 + Radeon RX 6600/6600 XT/6600M: mesa, vulkan-intel, intel-media-driver, libva-intel-driver, vulkan-radeon" 1 "Drivers"
choose_options
option_enabled drivers && echo RESULT=on || echo RESULT=off
EOF
# menu <keys> <columns>: what was on screen.
menu() { printf '%s' "$1" | script -qec "stty cols $2; bash '$TEST_DIR/menu.sh' '$VIRESTA'" /dev/null 2>/dev/null; }
plain() { strip_colors | sed 's/\r$//'; }

# Down, down, space, enter turns Drivers off. An 80 column terminal leaves 50 for the text.
screen="$(menu $'jj \n' 80 | plain)"
is "every package is shown" "$(for p in 'UHD Graphics 770' mesa vulkan-intel intel-media-driver libva-intel-driver vulkan-radeon; do grep -qF "$p" <<<"$screen" && echo yes; done | wc -l)" "6"
longest="$(grep -E 'Install drivers|^ {25}' <<<"$screen" | awk '{ if (length($0) > m) m = length($0) } END { print m }')"
is "no line reaches the edge" "$([ "$longest" -le 79 ] && echo yes || echo "no, $longest")" "yes"
is "wrapped lines line up with the text" "$(grep -cE '^ {25}[^ ]' <<<"$screen")" "8"
is "toggling a row works" "$(grep -c 'RESULT=off' <<<"$screen")" "1"
is "the category titles are shown" "$(grep -cE '^(Applications|Scripts|Drivers)$' <<<"$screen")" "12"

# 3 titles, 2 gaps, 3 rows and 2 extra lines of text is 10, and the footer and its gap make 12.
raw="$(menu $'j\n' 80)"
is "a redraw goes back up over every line" "$(grep -c $'\e\[12A' <<<"$raw")" "1"
is "a redraw draws exactly those lines" "$(printf '%s' "$raw" | tr -d '\r' | perl -0ne 'print $1 if /\e\[12A(.*?)\e\[2B/s' | grep -c '')" "10"
is "a narrow terminal still shows everything" "$(menu $'j\n' 50 | plain | grep -cF 'libva-intel-driver')" "2"

cat >"$TEST_DIR/menu2.sh" <<'EOF'
SCRIPT_DIR="$1"; VERBOSE=0
source "$SCRIPT_DIR/lib/ui/messages.sh"; source "$SCRIPT_DIR/lib/ui/menu.sh"
ui_init 2>/dev/null
add_option a "Vicinae" "one" 1 "Applications"
add_option b "a_really_long_script_name_here.py" "two" 1 "Scripts"
choose_options
EOF
long="$(printf '\n' | script -qec "stty cols 80; bash '$TEST_DIR/menu2.sh' '$VIRESTA'" /dev/null 2>/dev/null | plain)"
is "a long label: the same gap" "$(grep -c 'a_really_long_script_name_here.py  two' <<<"$long")" "1"
is "a short label lines up with it" "$(grep -c 'Vicinae                     *one' <<<"$long")" "1"
is "descriptions start in the same column" "$(grep -E '(one|two)$' <<<"$long" | awk '{ print index($0, $NF) }' | sort -u | wc -l)" "1"

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
# Help screens
# ------------------------------------------------------------

in_terminal() {
    script -qec "cd '$VIRESTA' && bash $1" "$TEST_DIR/raw" >/dev/null 2>&1
    sed -e '1{/^Script started/d}' -e '${/^Script done/d}' -e 's/\r$//' "$TEST_DIR/raw"
}
for script in install update uninstall; do
    screen="$(in_terminal "./$script.sh --help")"
    is "$script: a blank line at the top" "$(sed -n 1p <<<"$screen")" ""
    is "$script: colors in a terminal" "$(grep -c $'\e\[' <<<"$screen" | awk '{ print ($1 > 0) }')" "1"
    is "$script: the usage line" "$(strip_colors <<<"$screen" | sed -n 2p)" "Usage: ./$script.sh [options]"
    is "$script: no colors through a pipe" "$(cd "$VIRESTA" && bash "./$script.sh" --help | grep -c $'\e')" "0"
done

for option in --fast --no-aur --no-vicinae --no-rename-wallpapers --no-vm; do
    is "install.sh refuses the old $option" "$(cd "$VIRESTA" && bash ./install.sh "$option" >/dev/null 2>&1 </dev/null; echo $?)" "2"
done
is "setup.sh has a help" "$(cd "$VIRESTA" && bash setup/setup.sh --help | sed -n 2p)" "Usage: setup.sh [options]"

# ------------------------------------------------------------
# Ctrl+C
# ------------------------------------------------------------

# A question, then Ctrl+C, in a real terminal.
cat >"$TEST_DIR/question.sh" <<'EOF'
SCRIPT_DIR="$1"; VERBOSE=0
source "$SCRIPT_DIR/lib/load.sh"
start_script
ask_yes_no "Apply Viresta's configs again anyway?" n
echo "NOT STOPPED"
EOF
{ sleep 0.5; printf '\003'; sleep 0.3; } | script -qec "bash '$TEST_DIR/question.sh' '$VIRESTA'" /dev/null >"$TEST_DIR/ctrl-c" 2>/dev/null
hasnt "Ctrl+C at a question: stops" "NOT STOPPED" "$(cat "$TEST_DIR/ctrl-c")"
has "Ctrl+C at a question: the question was on screen" "anyway? [y/N]" "$(strip_colors <"$TEST_DIR/ctrl-c")"
# The last visible thing on screen, which before was the ^C. The script also shows the
# cursor again on its way out, which is a code and not text, so that is left out.
is "Ctrl+C at a question: the line is finished, so the prompt starts on its own" \
    "$(strip_colors <"$TEST_DIR/ctrl-c" | tr -d '\r' | tail -c 1 | od -An -c | tr -d ' ')" '\n'

# ------------------------------------------------------------
# What failed last time
# ------------------------------------------------------------

STATE="$HOME/.local/state/viresta"
mkdir -p "$STATE"
for pair in install:failures.log update:update-failures.log uninstall:uninstall-failures.log; do
    script="${pair%%:*}"
    log="$STATE/${pair#*:}"
    rm -f "$log"
    is "$script --logs: nothing recorded yet" "$(cd "$VIRESTA" && bash "./$script.sh" --logs)" "No $script has been recorded yet."
    : >"$log"
    is "$script --logs: nothing failed" "$(cd "$VIRESTA" && bash "./$script.sh" --logs)" "Nothing failed in the last $script."
    printf 'Could not install: foo\n' >"$log"
    is "$script --logs: what failed" "$(cd "$VIRESTA" && bash "./$script.sh" --logs)" "Failed in the last $script:
  - Could not install: foo"
    rm -f "$log"
done

LOG="$STATE/install.log"
mkdir -p "$(dirname "$LOG")"
echo keep >"$LOG"
(cd "$VIRESTA" && bash ./install.sh --help >/dev/null)
is "help leaves the log alone" "$(cat "$LOG")" "keep"

finish
