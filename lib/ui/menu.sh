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
OPTION_LABEL_WIDTH=0
OPTION_TEXT_INDENT=0
OPTION_TEXT_WIDTH=50

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
    local current="$1" i pointer box category='' line
    local -a text=()

    for i in "${!OPTION_NAMES[@]}"; do
        if [ "${OPTION_CATEGORIES[$i]}" != "$category" ]; then
            category="${OPTION_CATEGORIES[$i]}"
            if [ "$i" -gt 0 ]; then
                printf '\e[2K\n'
            fi
            printf '\e[2K%b%s%b\n' "$C_BOLD" "$category" "$C_RESET"
        fi

        mapfile -t text < <(option_text_lines "$i")

        pointer=' '
        box='[ ]'
        [ "$i" -ne "$current" ] || pointer='>'
        [ "${OPTION_STATES[$i]}" -ne 1 ] || box='[x]'
        printf '\e[2K  %b%s%b %b%s%b %-*s  %b%s%b\n' \
            "$C_ACCENT" "$pointer" "$C_RESET" "$C_OK" "$box" "$C_RESET" \
            "$OPTION_LABEL_WIDTH" "${OPTION_LABELS[$i]}" "$C_DIM" "${text[0]}" "$C_RESET"
        for line in "${text[@]:1}"; do
            printf '\e[2K%*s%b%s%b\n' "$OPTION_TEXT_INDENT" '' "$C_DIM" "$line" "$C_RESET"
        done
    done
}

# The description of an option, wrapped at spaces to fit next to its label.
option_text_lines() {
    printf '%s\n' "${OPTION_TEXTS[$1]}" | fold -s -w "$OPTION_TEXT_WIDTH" | sed 's/ *$//'
}

# The options with all their lines, plus a title for each category and a blank line
# between them.
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
        lines=$((lines + $(option_text_lines "$i" | wc -l)))
    done
    printf '%s\n' "$lines"
}

# The descriptions start 2 spaces after the longest label, after the 8 columns taken by
# the pointer and box. If the terminal wrapped a line itself, the menu could not count it
# to move back up and redraw, so the last column stays free.
set_option_layout() {
    local label columns

    OPTION_LABEL_WIDTH=0
    for label in "${OPTION_LABELS[@]}"; do
        if [ "${#label}" -gt "$OPTION_LABEL_WIDTH" ]; then
            OPTION_LABEL_WIDTH="${#label}"
        fi
    done
    OPTION_TEXT_INDENT=$((8 + OPTION_LABEL_WIDTH + 2))

    columns="$(stty size </dev/tty 2>/dev/null | awk '{ print $2 }' || true)"
    if [ -n "$columns" ] && [ "$columns" -gt "$((OPTION_TEXT_INDENT + 1))" ]; then
        OPTION_TEXT_WIDTH=$((columns - OPTION_TEXT_INDENT - 1))
    fi
}

# An arrow key menu in plain bash, since tools like dialog may not be installed yet.
# Without a terminal to answer from, everything stays ticked.
choose_options() {
    local count="${#OPTION_NAMES[@]}" current=0 key rest i lines

    [ "$count" -gt 0 ] && [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ] || return 0

    set_option_layout
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
