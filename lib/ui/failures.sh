#!/usr/bin/env bash

# failures.sh
# Keeps track of what failed, for install.sh --logs.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

FAILURE_LOG="${FAILURE_LOG:-$VIRESTA_STATE_DIR/failures.log}"

# ------------------------------------------------------------
# Recording
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Results
# ------------------------------------------------------------

failure_count() {
    if [ -f "$FAILURE_LOG" ]; then
        wc -l <"$FAILURE_LOG"
    else
        printf '0\n'
    fi
}

print_failures() {
    if [ "$(failure_count)" -gt 0 ]; then
        printf '\n'
        _emit "$C_WARN" "! $(failure_count) failed:"
        sed 's/^/  - /' "$FAILURE_LOG"
    fi
}

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
