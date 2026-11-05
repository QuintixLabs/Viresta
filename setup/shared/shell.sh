#!/usr/bin/env bash

# shell.sh
# Knows the user's shell, and keeps Viresta's lines in ~/.bashrc apart from their own.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

BASHRC_FILE="$HOME/.bashrc"
BASHRC_START="# Viresta: start"
BASHRC_END="# Viresta: end"
BLESH_SCRIPT="/usr/share/blesh/ble.sh"

# ------------------------------------------------------------
# Shell
# ------------------------------------------------------------

# Read from the system, as the shell this script runs in is always Bash.
login_shell() {
    local shell
    shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
    printf '%s\n' "${shell##*/}"
}

# ------------------------------------------------------------
# ~/.bashrc
# ------------------------------------------------------------

bashrc_has_viresta_lines() {
    grep -qxF "$BASHRC_START" "$BASHRC_FILE" 2>/dev/null
}

# cat keeps the file itself in place, in case it is a link to someone's own dotfiles.
remove_bashrc_lines() {
    local temp_file

    [ -f "$BASHRC_FILE" ] || return 0

    temp_file="$(mktemp)"
    awk -v start="$BASHRC_START" -v end="$BASHRC_END" '
        $0 == start { skipping = 1; next }
        $0 == end { skipping = 0; next }
        !skipping
    ' "$BASHRC_FILE" >"$temp_file"
    cat "$temp_file" >"$BASHRC_FILE"
    rm -f "$temp_file"
}
