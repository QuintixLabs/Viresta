#!/usr/bin/env bash

# fish.sh
# Runs Viresta's Fish file in a real Fish, with a fake starship, to check the prompt and
# the suggestion color only change when they should.

source "$(dirname "$0")/../shared/helpers.sh"

need fish

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
FISH="$(command -v fish)"
VENDOR="$TEST_DIR/vendor"
mkdir -p "$TEST_DIR/tools" "$VENDOR/fish/vendor_functions.d"
printf '#!/bin/sh\necho '\''function fish_prompt; echo FROM_STARSHIP; end'\''\n' >"$TEST_DIR/tools/starship"
chmod +x "$TEST_DIR/tools/starship"
# What a distro's own prompt looks like, such as Pure on CachyOS.
echo 'function fish_prompt; echo FROM_DISTRO; end' >"$VENDOR/fish/vendor_functions.d/fish_prompt.fish"

WITH="$TEST_DIR/tools:/usr/bin:/bin"
WITHOUT="/usr/bin:/bin"

# run <term> <path> <fish lines first> [their own prompt]: what the prompt and color end up as.
# setsid gives Fish no terminal of its own, so it cannot take over the one the tests run in.
run() {
    local home="$TEST_DIR/fish-home"
    rm -rf "$home" "$TEST_DIR/result"
    mkdir -p "$home/.config/fish/conf.d" "$home/.config/fish/functions"
    cp "$VIRESTA/config/shell/fish/viresta.fish" "$home/.config/fish/conf.d/viresta.fish"
    {
        printf 'set -g fish_function_path %s %s\n' "$home/.config/fish/functions" "$VENDOR/fish/vendor_functions.d"
        printf '%s\n' "$3"
    } >"$home/.config/fish/conf.d/000-before.fish"
    if [ -n "${4:-}" ]; then printf '%s\n' "$4" >"$home/.config/fish/functions/fish_prompt.fish"; fi
    env -i HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_DIRS="$VENDOR" PATH="$2" TERM="$1" \
        LANG=C.UTF-8 RESULT="$TEST_DIR/result" ${LD_LIBRARY_PATH:+LD_LIBRARY_PATH="$LD_LIBRARY_PATH"} \
        setsid "$FISH" -i -C 'source $XDG_CONFIG_HOME/fish/conf.d/000-before.fish; source $XDG_CONFIG_HOME/fish/conf.d/viresta.fish; begin; echo PROMPT=(fish_prompt); echo COLOR=$fish_color_autosuggestion; end >$RESULT; exit' \
        </dev/null >/dev/null 2>"$TEST_DIR/errors"
    cat "$TEST_DIR/result" 2>/dev/null
}
prompt() { grep -oE '^PROMPT=[A-Z_]*' <<<"$1" | tail -n 1; }
color() { grep -E '^COLOR=' <<<"$1" | tail -n 1; }

# ------------------------------------------------------------
# Tests
# ------------------------------------------------------------

out="$(run xterm "$WITH" "")"
is "no errors from the file" "$(wc -c <"$TEST_DIR/errors")" "0"
is "starship replaces the distro's prompt" "$(prompt "$out")" "PROMPT=FROM_STARSHIP"
is "the color follows the terminal" "$(color "$out")" "COLOR=brblack"

is "no starship: the distro's prompt stays" "$(prompt "$(run xterm "$WITHOUT" "")")" "PROMPT=FROM_DISTRO"
is "text login: starship stays off" "$(prompt "$(run linux "$WITH" "")")" "PROMPT=FROM_DISTRO"
is "their own prompt stays" "$(prompt "$(run xterm "$WITH" "" 'function fish_prompt; echo THEIR_OWN; end')")" "PROMPT=THEIR_OWN"
is "tide stays" "$(prompt "$(run xterm "$WITH" 'function _tide_prompt; end')")" "PROMPT=FROM_DISTRO"
is "a color they chose stays" "$(color "$(run xterm "$WITH" 'set -g fish_color_autosuggestion ff00ff')")" "COLOR=ff00ff"
is "Fish's default color is replaced" "$(color "$(run xterm "$WITH" 'set -g fish_color_autosuggestion 555 brblack')")" "COLOR=brblack"

# Scripts do nothing, so nothing slows them down or prints.
out="$(env -i HOME="$TEST_DIR/fish-home" XDG_CONFIG_HOME="$TEST_DIR/fish-home/.config" PATH="$WITH" TERM=xterm \
    ${LD_LIBRARY_PATH:+LD_LIBRARY_PATH="$LD_LIBRARY_PATH"} \
    "$FISH" -c 'source $XDG_CONFIG_HOME/fish/conf.d/viresta.fish; echo PROMPT=(fish_prompt); echo "COLOR=$fish_color_autosuggestion"' 2>&1)"
hasnt "not interactive: starship does not run" "FROM_STARSHIP" "$out"
is "not interactive: no color set" "$(tail -n 1 <<<"$out")" "COLOR="

finish
