#!/usr/bin/env bash

# menu.sh
# Shows the menu for choosing what to install, and asks yes or no questions.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

OPTION_NAMES=()
OPTION_LABELS=()
OPTION_TEXTS=()
OPTION_STATES=()

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

add_option() {
    OPTION_NAMES+=("$1")
    OPTION_LABELS+=("$2")
    OPTION_TEXTS+=("$3")
    OPTION_STATES+=("$4")
}

option_enabled() {
    local i
    for i in "${!OPTION_NAMES[@]}"; do
        if [ "${OPTION_NAMES[$i]}" = "$1" ]; then
            [ "${OPTION_STATES[$i]}" -eq 1 ]
            return
        fi
    done
    return 0
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

_draw_options() {
    local current="$1" i pointer box

    for i in "${!OPTION_NAMES[@]}"; do
        pointer=' '
        box='[ ]'
        [ "$i" -ne "$current" ] || pointer='>'
        [ "${OPTION_STATES[$i]}" -ne 1 ] || box='[x]'
        printf '\e[2K  %b%s%b %b%s%b %-18s %b%s%b\n' \
            "$C_ACCENT" "$pointer" "$C_RESET" "$C_OK" "$box" "$C_RESET" \
            "${OPTION_LABELS[$i]}" "$C_DIM" "${OPTION_TEXTS[$i]}" "$C_RESET"
    done
}

# An arrow key menu in plain bash, since tools like dialog may not be installed yet.
# Without a terminal to answer from, everything stays ticked.
choose_options() {
    local count="${#OPTION_NAMES[@]}" current=0 key rest i

    [ "$count" -gt 0 ] && [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ] || return 0

    printf '%bChoose what to install%b\n' "$C_BOLD" "$C_RESET"
    printf '%bThese are recommended, but you can turn them off.%b\n\n' "$C_DIM" "$C_RESET"
    printf '\e[?25l'
    _draw_options "$current"
    printf '\n%bUp/Down move   Space toggle   Enter continue%b\n' "$C_ACCENT$C_BOLD" "$C_RESET"

    while :; do
        IFS= read -rsn1 key </dev/tty || key=''
        case "$key" in
            '') break ;;
            ' ') OPTION_STATES[current]=$((1 - OPTION_STATES[current])) ;;
            k) current=$(((current + count - 1) % count)) ;;
            j) current=$(((current + 1) % count)) ;;
            $'\e')
                IFS= read -rsn2 -t 0.1 rest </dev/tty || rest=''
                case "$rest" in
                    '[A') current=$(((current + count - 1) % count)) ;;
                    '[B') current=$(((current + 1) % count)) ;;
                esac
                ;;
        esac
        # Back up over the footer line, the blank line and the options.
        printf '\e[%dA' "$((count + 2))"
        _draw_options "$current"
        printf '\e[2B'
    done

    printf '\e[?25h\n'
    for i in "${!OPTION_NAMES[@]}"; do
        _log "Option ${OPTION_NAMES[$i]}: ${OPTION_STATES[$i]}"
    done
}

# ------------------------------------------------------------
# Questions
# ------------------------------------------------------------

# The default is used for a plain Enter, or without a terminal to answer from.
ask_yes_no() {
    local question="$1" default="$2" hint='[y/N]' answer=''

    [ "$default" != "y" ] || hint='[Y/n]'

    if [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
        printf '%b?%b %s %s ' "$C_ACCENT" "$C_RESET" "$question" "$hint"
        IFS= read -r answer </dev/tty || answer=''
    fi
    _log "$question $hint: ${answer:-$default}"

    case "${answer:-$default}" in
        y|Y|yes|Yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
