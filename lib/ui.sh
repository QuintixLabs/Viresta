#!/usr/bin/env bash
# Viresta - terminal UI, logging and prompt helpers.
# Sourced by install.sh. Not meant to be executed directly.

LOG_FILE="${LOG_FILE:-/tmp/viresta-install.log}"
STEP=0
TOTAL_STEPS=9

# Populated by ui_init().
C_RESET=''
C_BOLD=''
C_DIM=''
C_ACCENT=''
C_OK=''
C_WARN=''
C_ERR=''
S_OK='[ok]'
S_ERR='[!!]'
S_ARROW='->'
S_BULLET='*'

CLEANUPS=()

ui_init() {
    : >"$LOG_FILE" 2>/dev/null || true

    local utf8=0
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf8*|*UTF8*|*utf-8*) utf8=1 ;;
    esac

    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
        C_RESET=$'\e[0m'
        C_BOLD=$'\e[1m'
        C_DIM=$'\e[38;5;245m'
        C_ACCENT=$'\e[38;5;39m'
        C_OK=$'\e[38;5;42m'
        C_WARN=$'\e[38;5;214m'
        C_ERR=$'\e[38;5;203m'
    fi

    if [ "$utf8" -eq 1 ]; then
        S_OK='✓'
        S_ERR='✗'
        S_ARROW='→'
        S_BULLET='•'
    fi
}

banner() {
    printf '\n'
    printf '%b  V I R E S T A%b\n' "$C_ACCENT$C_BOLD" "$C_RESET"
    printf '%b  Arch Linux + KDE Plasma 6 setup%b\n' "$C_DIM" "$C_RESET"
    printf '%b  system %s kde %s apps %s aur %s vm %s finish%b\n' \
        "$C_DIM" "$S_ARROW" "$S_ARROW" "$S_ARROW" "$S_ARROW" "$S_ARROW" "$C_RESET"
    printf '%b  ------------------------------------------------------------%b\n' "$C_DIM" "$C_RESET"
    printf '\n'
}

step() {
    STEP=$((STEP + 1))
    printf '\n%b[%s/%s]%b %b%s%b\n' \
        "$C_ACCENT" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
    printf '[%s/%s] %s\n' "$STEP" "$TOTAL_STEPS" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

# _emit <color> <message>
_emit() {
    local color="$1"
    shift
    printf '%b%s%b\n' "$color" "$*" "$C_RESET"
    printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true
}

info() { _emit "$C_DIM" "  $S_BULLET $*"; }
ok()   { _emit "$C_OK" "  $S_OK $*"; }
warn() { _emit "$C_WARN" "  ! $*"; }
error(){ _emit "$C_ERR" "  $S_ERR $*"; }
die()  { error "$*"; exit 1; }

hr() {
    printf '%b------------------------------------------------------------%b\n' "$C_DIM" "$C_RESET"
}

# Register a function to run on exit (including Ctrl+C / TERM).
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

# Reads a password without echoing it. Stored in ADMIN_PW, cleared after use.
read_password() {
    local pw=''
    printf '%b?%b Password for %s (asked once, used for sudo): ' \
        "$C_ACCENT" "$C_RESET" "${USER:-$(id -un)}" >&2
    if [ -r /dev/tty ]; then
        IFS= read -rs pw </dev/tty || true
    else
        IFS= read -rs pw || true
    fi
    printf '\n' >&2
    [ -n "$pw" ] || die "No password provided."
    ADMIN_PW="$pw"
}

confirm() {
    local ans=''
    printf '%b?%b %s [y/N] ' "$C_ACCENT" "$C_RESET" "$1" >&2
    if [ -r /dev/tty ]; then
        read -r ans </dev/tty || ans=''
    else
        read -r ans || ans=''
    fi
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}
