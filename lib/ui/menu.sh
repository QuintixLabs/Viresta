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
OPTION_CATEGORIES=()
OPTION_TEXT_WIDTH=52

# ------------------------------------------------------------
# Options
# ------------------------------------------------------------

add_option() {
    OPTION_NAMES+=("$1")
    OPTION_LABELS+=("$2")
    OPTION_TEXTS+=("$3")
    OPTION_STATES+=("$4")
    OPTION_CATEGORIES+=("$5")
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

draw_options() {
    local current="$1" i pointer box category=''

    for i in "${!OPTION_NAMES[@]}"; do
        if [ "${OPTION_CATEGORIES[$i]}" != "$category" ]; then
            category="${OPTION_CATEGORIES[$i]}"
            if [ "$i" -gt 0 ]; then
                printf '\e[2K\n'
            fi
            printf '\e[2K%b%s%b\n' "$C_BOLD" "$category" "$C_RESET"
        fi

        pointer=' '
        box='[ ]'
        [ "$i" -ne "$current" ] || pointer='>'
        [ "${OPTION_STATES[$i]}" -ne 1 ] || box='[x]'
        printf '\e[2K  %b%s%b %b%s%b %-18s %b%.*s%b\n' \
            "$C_ACCENT" "$pointer" "$C_RESET" "$C_OK" "$box" "$C_RESET" \
            "${OPTION_LABELS[$i]}" "$C_DIM" "$OPTION_TEXT_WIDTH" "${OPTION_TEXTS[$i]}" "$C_RESET"
    done
}

# The options, plus a title for each category and a blank line between them.
menu_line_count() {
    local i lines=0 category=''

    for i in "${!OPTION_NAMES[@]}"; do
        if [ "${OPTION_CATEGORIES[$i]}" != "$category" ]; then
            category="${OPTION_CATEGORIES[$i]}"
            lines=$((lines + 1))
            if [ "$i" -gt 0 ]; then
                lines=$((lines + 1))
            fi
        fi
        lines=$((lines + 1))
    done
    printf '%s\n' "$lines"
}

# Text that wraps onto a second line would break moving back up to redraw the menu.
# Everything before the text takes 27 columns, and the last column stays free.
set_option_text_width() {
    local columns

    columns="$(stty size </dev/tty 2>/dev/null | awk '{ print $2 }' || true)"
    if [ -n "$columns" ] && [ "$columns" -gt 28 ]; then
        OPTION_TEXT_WIDTH=$((columns - 28))
    fi
}

# An arrow key menu in plain bash, since tools like dialog may not be installed yet.
# Without a terminal to answer from, everything stays ticked.
choose_options() {
    local count="${#OPTION_NAMES[@]}" current=0 key rest i lines

    [ "$count" -gt 0 ] && [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ] || return 0

    set_option_text_width
    lines="$(menu_line_count)"

    printf '%bChoose what to install%b\n' "$C_BOLD" "$C_RESET"
    printf '%bThese are recommended, but you can turn them off.%b\n\n' "$C_DIM" "$C_RESET"
    printf '\e[?25l'
    draw_options "$current"
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
        printf '\e[%dA' "$((lines + 2))"
        draw_options "$current"
        printf '\e[2B'
    done

    printf '\e[?25h\n'
    for i in "${!OPTION_NAMES[@]}"; do
        log "Option ${OPTION_NAMES[$i]}: ${OPTION_STATES[$i]}"
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
    log "$question $hint: ${answer:-$default}"

    case "${answer:-$default}" in
        y|Y|yes|Yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
