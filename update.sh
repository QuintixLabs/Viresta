#!/usr/bin/env bash

# update.sh
# Updates Viresta without touching what belongs to the user.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update.log"
FAILURE_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update-failures.log"
UPDATE_NOTES_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update-notes"

# shellcheck source=lib/load.sh
source "$SCRIPT_DIR/lib/load.sh"
# shellcheck source=lib/update/download.sh
source "$SCRIPT_DIR/lib/update/download.sh"
# shellcheck source=lib/update/install-pkgs.sh
source "$SCRIPT_DIR/lib/update/install-pkgs.sh"

TOTAL_STEPS=4

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------

usage() {
    help_header "./update.sh [options]"
    help_option "--verbose" "Show everything on screen instead of only the steps"
    help_option "-h, --help" "Show this help"
    printf '\n'
}

for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done

# Comes before the startup, which would create a log for nothing.
if ! viresta_is_installed; then
    printf 'Viresta is not installed. Run ./install.sh first.\n' >&2
    exit 1
fi

start_script

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

summary() {
    local line

    printf '\n'
    hr
    printf '%bUpdate complete%b\n' "$C_OK$C_BOLD" "$C_RESET"
    _emit "$C_OK" "$S_OK Time taken: $(format_duration "$SECONDS")"
    if [ -s "$UPDATE_NOTES_FILE" ]; then
        printf '\n'
        while IFS= read -r line; do
            _emit "$C_WARN" "! $line"
        done <"$UPDATE_NOTES_FILE"
    fi
    print_failures
    _emit "$C_OK" "$S_OK Update log: $LOG_FILE"
    printf '\n'
    _emit "$C_DIM" "$S_BULLET Some changes appear the next time you log in."
    printf '\n'
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    reset_failures
    banner

    require_non_root
    require_sudo

    step "Downloading the latest Viresta"
    pull_latest

    step "Getting permission to update"
    read_password
    enable_nopasswd

    # Starts here so the time spent typing the password does not count.
    SECONDS=0

    step "Installing new packages"
    install_new_repo_packages
    install_new_aur_packages

    step "Updating Viresta"
    configure_kde_configs --update
    remember_packages

    step_finish
    summary
}

main "$@"
