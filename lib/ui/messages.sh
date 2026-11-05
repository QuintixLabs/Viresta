#!/usr/bin/env bash

# messages.sh
# Handles colors, the banner, messages and cleanup.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

# Kept outside /tmp so both are still there after the reboot.
VIRESTA_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/viresta"
LOG_FILE="${LOG_FILE:-$VIRESTA_STATE_DIR/install.log}"

# 1 shows everything on screen, 0 shows only the steps and what went wrong.
VERBOSE=0

C_RESET=''
C_BOLD=''
C_DIM=''
C_ACCENT=''
C_OK=''
C_WARN=''
C_ERR=''
S_OK='[ok]'
S_ERR='[!!]'
S_BULLET='*'

CLEANUPS=()

# ------------------------------------------------------------
# Startup
# ------------------------------------------------------------

ui_colors() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
        C_RESET=$'\e[0m'
        C_BOLD=$'\e[1m'
        C_DIM=$'\e[38;5;245m'
        C_ACCENT=$'\e[38;5;39m'
        C_OK=$'\e[38;5;42m'
        C_WARN=$'\e[38;5;214m'
        C_ERR=$'\e[38;5;203m'
    fi
}

ui_init() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    : >"$LOG_FILE" 2>/dev/null || true
    register_cleanup spinner_stop
    register_cleanup show_cursor

    local utf8=0
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf8*|*UTF8*|*utf-8*) utf8=1 ;;
    esac

    ui_colors

    if [ "$utf8" -eq 1 ]; then
        S_OK='✓'
        S_ERR='✗'
        S_BULLET='•'
    fi

    # The Linux console font has no ✓ or ✗, but it does have these.
    if [ "$utf8" -eq 1 ] && [ "${TERM:-}" = "linux" ]; then
        S_OK='√'
        S_ERR='×'
    fi
}

# The version sits after the logo's last line, so its length never matters.
banner() {
    local version

    version="$(viresta_version)"
    printf '\n%b' "$C_ACCENT$C_BOLD"
    printf '%s\n' \
        '█   █ ▀ ▄ ▄▄  ▄▄   ▄▄▄ ▄█▄   ▄▄▄' \
        '▀▄ ▄▀ █ █▀   █▀▀▀ ▀▀▄▄  █   █  █'
    printf '%s%b' '  ▀   ▀ ▀     ▀▀▀ ▀▀▀    ▀▀  ▀▀▀▀' "$C_RESET"
    if [ -n "$version" ]; then
        printf ' %bv%s%b' "$C_DIM" "$version" "$C_RESET"
    fi
    printf '\n\n'
    printf '%bThe clean, stable and user-friendly dots for everyone!%b\n' "$C_DIM" "$C_RESET"
    hr
    printf '\n'
}

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

# Help runs before ui_init, which would empty the log.
help_header() {
    ui_colors
    printf '\n%bUsage:%b %s\n\n' "$C_ACCENT$C_BOLD" "$C_RESET" "$1"
    printf '%bOptions:%b\n' "$C_ACCENT$C_BOLD" "$C_RESET"
}

help_option() {
    printf '  %b%-*s%b %s\n' "$C_OK" "${HELP_OPTION_WIDTH:-12}" "$1" "$C_RESET" "$2"
}

help_note() {
    printf '%b%s%b\n' "$C_DIM" "$1" "$C_RESET"
}

# ------------------------------------------------------------
# Messages
# ------------------------------------------------------------

log() {
    printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true
}

emit() {
    local color="$1"
    shift
    printf '%b%s%b\n' "$color" "$*" "$C_RESET"
    log "$*"
}

# Progress messages stay in the log while a step's spinner is showing.
progress() {
    if [ -n "$STEP_TITLE" ]; then
        log "$2"
    else
        emit "$1" "$2"
    fi
}

info() { progress "$C_DIM" "  $S_BULLET $*"; }
ok()   { progress "$C_OK" "  $S_OK $*"; }

warn() {
    if [ -n "$STEP_TITLE" ]; then
        STEP_MARK="$C_WARN!$C_RESET"
        STEP_WARNINGS+=("  ! $*")
        log "  ! $*"
    else
        emit "$C_WARN" "  ! $*"
    fi
}

error() { emit "$C_ERR" "  $S_ERR $*"; }

die() {
    STEP_MARK="$C_ERR$S_ERR$C_RESET"
    step_finish
    error "$*"
    record_failure "$*"
    printf '%b  Full log: %s%b\n' "$C_DIM" "$LOG_FILE" "$C_RESET"
    exit 1
}

# As wide as the banner's tagline, so every line on screen matches.
hr() {
    printf '%b------------------------------------------------------%b\n' "$C_DIM" "$C_RESET"
}

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

show_cursor() {
    [ ! -t 1 ] || printf '\e[?25h'
}

register_cleanup() {
    CLEANUPS+=("$1")
}

run_cleanups() {
    local fn
    if [ "${#CLEANUPS[@]}" -gt 0 ]; then
        for fn in "${CLEANUPS[@]}"; do
            [ -n "$fn" ] && "$fn" || true
        done
    fi
}
