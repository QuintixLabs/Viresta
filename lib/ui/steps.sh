#!/usr/bin/env bash

# steps.sh
# Shows the install steps, the spinner and the time.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

STEP=0
TOTAL_STEPS=10
STEP_TITLE=''
STEP_STARTED=0
STEP_MARK=''
STEP_WARNINGS=()
SPINNER_PID=''

# ------------------------------------------------------------
# Time
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Spinner
# ------------------------------------------------------------

step_line() {
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
            line="$(step_line "${frames:i%4:1}" "$(format_duration "$((EPOCHSECONDS - STEP_STARTED))")")"
            # One write that overwrites the old text, since clearing first would flicker.
            printf '\r%s\e[K' "$line"
            # Counted out here, because a change made inside $(...) would be lost.
            i=$((i + 1))
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

# ------------------------------------------------------------
# Steps
# ------------------------------------------------------------

# Warnings wait until the step's line is printed, so they appear underneath it.
step_finish() {
    local line

    [ -n "$STEP_TITLE" ] || return 0
    spinner_stop
    step_line "$STEP_MARK" "$(format_duration "$((EPOCHSECONDS - STEP_STARTED))")"
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
    log "[$STEP/$TOTAL_STEPS] $1"

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
