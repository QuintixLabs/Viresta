#!/usr/bin/env bash

# list.sh
# Reads what each kind of hardware needs from drivers.txt.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

DRIVERS_FILE="$SCRIPT_DIR/packages/drivers.txt"

# ------------------------------------------------------------
# drivers.txt
# ------------------------------------------------------------

driver_pkgs_for() {
    local hardware="$1" v pkg rest
    [ -f "$DRIVERS_FILE" ] || return 0
    while read -r v pkg rest; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$hardware" ] && [ -n "$pkg" ]; then
            printf '%s\n' "$pkg"
        fi
    done <"$DRIVERS_FILE"
}

driver_services_for() {
    local hardware="$1" v pkg svc rest
    [ -f "$DRIVERS_FILE" ] || return 0
    while read -r v pkg svc rest; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$hardware" ] && [ -n "$svc" ] && [ "$svc" != "-" ]; then
            printf '%s\n' "$svc"
        fi
    done <"$DRIVERS_FILE"
}

driver_replaces_for() {
    local hardware="$1" wanted="$2" v pkg svc replaces rest
    [ -f "$DRIVERS_FILE" ] || return 0
    while read -r v pkg svc replaces rest; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$hardware" ] && [ "$pkg" = "$wanted" ] && [ -n "$replaces" ] && [ "$replaces" != "-" ]; then
            printf '%s\n' "$replaces"
            return 0
        fi
    done <"$DRIVERS_FILE"
}

driver_flags_for() {
    local hardware="$1" wanted="$2" v pkg svc replaces flags
    [ -f "$DRIVERS_FILE" ] || return 0
    while read -r v pkg svc replaces flags; do
        case "$v" in ''|\#*) continue ;; esac
        if [ "$v" = "$hardware" ] && [ "$pkg" = "$wanted" ] && [ -n "$flags" ]; then
            printf '%s\n' "$flags"
            return 0
        fi
    done <"$DRIVERS_FILE"
}
