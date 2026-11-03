#!/usr/bin/env bash
# Viresta - terminal UI, logging and prompt helpers.
# Sourced by install.sh. Not meant to be executed directly.

# Kept outside /tmp so both are still there after the reboot.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/viresta"
LOG_FILE="${LOG_FILE:-$STATE_DIR/install.log}"
FAILURE_LOG="$STATE_DIR/failures.log"
STEP=0
TOTAL_STEPS=9

# 1 shows everything on screen, 0 shows only the steps and what went wrong.
VERBOSE=0
STEP_TITLE=''
STEP_STARTED=0
STEP_MARK=''
STEP_WARNINGS=()
SPINNER_PID=''

# Filled by add_option() for choose_options().
OPTION_NAMES=()
OPTION_LABELS=()
OPTION_TEXTS=()
OPTION_STATES=()

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
S_BULLET='*'

CLEANUPS=()

ui_init() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    : >"$LOG_FILE" 2>/dev/null || true
    register_cleanup spinner_stop
    register_cleanup show_cursor

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
        S_BULLET='•'
    fi

    # The Linux console font has no ✓ or ✗, but it does have these.
    if [ "$utf8" -eq 1 ] && [ "${TERM:-}" = "linux" ]; then
        S_OK='√'
        S_ERR='×'
    fi
}

banner() {
    printf '\n%b' "$C_ACCENT$C_BOLD"
    cat <<'EOF'
  █   █ ▀ ▄ ▄▄  ▄▄   ▄▄▄ ▄█▄   ▄▄▄
  ▀▄ ▄▀ █ █▀   █▀▀▀ ▀▀▄▄  █   █  █
    ▀   ▀ ▀     ▀▀▀ ▀▀▀    ▀▀  ▀▀▀▀
EOF
    printf '%b\n' "$C_RESET"
    printf '%b  The clean, stable and user-friendly dots for everyone to use!%b\n' "$C_DIM" "$C_RESET"
    printf '%b  ------------------------------------------------------------%b\n' "$C_DIM" "$C_RESET"
    printf '\n'
}

# add_option <name> <label> <description> <1 to start ticked, 0 not to>
add_option() {
    OPTION_NAMES+=("$1")
    OPTION_LABELS+=("$2")
    OPTION_TEXTS+=("$3")
    OPTION_STATES+=("$4")
}

# True if the option is ticked.
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

show_cursor() {
    [ ! -t 1 ] || printf '\e[?25h'
}

format_duration() {
    local total="$1"

    if [ "$total" -ge 3600 ]; then
        printf '%dh %02dm %02ds' "$((total / 3600))" "$((total % 3600 / 60))" "$((total % 60))"
    elif [ "$total" -ge 60 ]; then
        printf '%dm %02ds' "$((total / 60))" "$((total % 60))"
    else
        printf '%ds' "$total"
    fi
}

_log() {
    printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true
}

# _step_line <mark> <time>
_step_line() {
    printf '%b[%s/%s]%b %b%-36s%b %s  %b%s%b' \
        "$C_ACCENT" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$STEP_TITLE" "$C_RESET" \
        "$1" "$C_DIM" "$2" "$C_RESET"
}

# The frames are plain ASCII because the Linux console font has no braille dots.
spinner_start() {
    [ -n "$STEP_TITLE" ] && [ -z "$SPINNER_PID" ] && [ -t 1 ] || return 0

    printf '\e[?25l'
    (
        frames='|/-\'
        i=0
        # Stops by itself if the installer is killed too hard to clean up.
        while kill -0 "$$" 2>/dev/null; do
            printf '\r\e[2K'
            _step_line "${frames:i++%4:1}" "$(format_duration "$((EPOCHSECONDS - STEP_STARTED))")"
            sleep 0.2
        done
    ) &
    SPINNER_PID=$!
}

spinner_stop() {
    [ -n "$SPINNER_PID" ] || return 0
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=''
    printf '\r\e[2K\e[?25h'
}

# Warnings wait until the step's line is printed, so they appear underneath it.
step_finish() {
    local line

    [ -n "$STEP_TITLE" ] || return 0
    spinner_stop
    _step_line "$STEP_MARK" "$(format_duration "$((EPOCHSECONDS - STEP_STARTED))")"
    printf '\n'
    for line in "${STEP_WARNINGS[@]}"; do
        printf '%b%s%b\n' "$C_WARN" "$line" "$C_RESET"
    done
    STEP_TITLE=''
    STEP_WARNINGS=()
}

step() {
    step_finish
    STEP=$((STEP + 1))
    _log "[$STEP/$TOTAL_STEPS] $1"

    if [ "$VERBOSE" -eq 1 ]; then
        printf '\n%b[%s/%s]%b %b%s%b\n' \
            "$C_ACCENT" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
        return 0
    fi

    STEP_TITLE="$1"
    STEP_STARTED="$EPOCHSECONDS"
    STEP_MARK="$C_OK$S_OK$C_RESET"
    spinner_start
}

# _emit <color> <message>
_emit() {
    local color="$1"
    shift
    printf '%b%s%b\n' "$color" "$*" "$C_RESET"
    _log "$*"
}

# Progress messages stay in the log while a step's spinner is showing.
_progress() {
    if [ -n "$STEP_TITLE" ]; then
        _log "$2"
    else
        _emit "$1" "$2"
    fi
}

info() { _progress "$C_DIM" "  $S_BULLET $*"; }
ok()   { _progress "$C_OK" "  $S_OK $*"; }

warn() {
    if [ -n "$STEP_TITLE" ]; then
        STEP_MARK="$C_WARN!$C_RESET"
        STEP_WARNINGS+=("  ! $*")
        _log "  ! $*"
    else
        _emit "$C_WARN" "  ! $*"
    fi
}

error() { _emit "$C_ERR" "  $S_ERR $*"; }

die() {
    STEP_MARK="$C_ERR$S_ERR$C_RESET"
    step_finish
    error "$*"
    record_failure "$*"
    printf '%b  Full log: %s%b\n' "$C_DIM" "$LOG_FILE" "$C_RESET"
    exit 1
}

# Something failed but the install can carry on.
failure() { warn "$*"; record_failure "$*"; }

reset_failures() {
    [ "${DRY_RUN:-0}" -eq 0 ] || return 0
    mkdir -p "$(dirname "$FAILURE_LOG")"
    : >"$FAILURE_LOG"
}

record_failure() {
    [ "${DRY_RUN:-0}" -eq 0 ] || return 0
    [ -f "$FAILURE_LOG" ] || return 0
    printf '%s\n' "$*" >>"$FAILURE_LOG"
}

failure_count() {
    if [ -f "$FAILURE_LOG" ]; then
        wc -l <"$FAILURE_LOG"
    else
        printf '0\n'
    fi
}

# What install.sh --logs prints.
show_failures() {
    if [ ! -f "$FAILURE_LOG" ]; then
        printf 'No install has been recorded yet.\n'
    elif [ ! -s "$FAILURE_LOG" ]; then
        printf 'Nothing failed in the last install.\n'
    else
        printf 'Failed in the last install:\n'
        sed 's/^/  - /' "$FAILURE_LOG"
    fi
}

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
    spinner_stop
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
    spinner_start
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
