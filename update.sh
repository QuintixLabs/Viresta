#!/usr/bin/env bash

# update.sh
# Updates Viresta without touching what belongs to the user.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR/setup"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update.log"
FAILURE_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update-failures.log"
UPDATE_NOTES_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/update-notes"
DEV=0
CHECK=0
NOTIFICATIONS=""

# shellcheck source=setup/shared/variables.sh
source "$SETUP_DIR/shared/variables.sh"
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
    local HELP_OPTION_WIDTH=19

    help_header "${VIRESTA_RUN_AS:-./update.sh} [options]"
    help_option "--dev" "Update to the latest commit instead of the newest release"
    help_option "--check" "Only say whether a new release is out, without updating"
    help_option "--notifications-off" "Stop alerting you about new releases, without updating"
    help_option "--notifications-on" "Alert you about new releases again, without updating"
    help_option "--logs" "Show what failed in the last update, without updating anything"
    help_option "--verbose" "Show everything on screen instead of only the steps"
    help_option "-h, --help" "Show this help"
    printf '\n'
}

for arg in "$@"; do
    case "$arg" in
        --dev) DEV=1 ;;
        --check) CHECK=1 ;;
        --notifications-off) NOTIFICATIONS=0 ;;
        --notifications-on) NOTIFICATIONS=1 ;;
        --logs) show_failures update; exit 0 ;;
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

# Only changes the setting. Turning alerts on also forgets the last one, so someone who
# turned them off and came back still hears about a release they have not installed.
if [ -n "$NOTIFICATIONS" ]; then
    save_option update_notifications "$NOTIFICATIONS"
    if [ "$NOTIFICATIONS" -eq 1 ]; then
        rm -f -- "$NOTIFIED_VERSION_FILE"
        printf 'Update notifications are on.\n'
    else
        printf 'Update notifications are off.\n'
    fi
    exit 0
fi

# Asks GitHub the same way the alerts do, so nothing in the folder changes.
if [ "$CHECK" -eq 1 ]; then
    current="$(viresta_version)"
    if ! release="$(newest_online_release)"; then
        printf 'Could not check for a new release. Check your internet connection.\n' >&2
        exit 1
    fi
    if [ -n "$release" ] && is_newer_version "${release#v}" "$current"; then
        printf "Viresta %s is out. You're on %s. Run %s to get it.\n" \
            "${release#v}" "${current:-an older version}" "${VIRESTA_RUN_AS:-./update.sh}"
    else
        printf 'Viresta is up to date%s.\n' "${current:+ (v$current)}"
    fi
    exit 0
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
    emit "$C_OK" "$S_OK Time taken: $(format_duration "$SECONDS")"
    if [ -n "${VIRESTA_NEW_RELEASE:-}" ]; then
        emit "$C_OK" "$S_OK See what's new: $RELEASES_URL/tag/$VIRESTA_NEW_RELEASE"
    fi
    if [ -s "$UPDATE_NOTES_FILE" ]; then
        printf '\n'
        while IFS= read -r line; do
            emit "$C_WARN" "! $line"
        done <"$UPDATE_NOTES_FILE"
    fi
    print_failures
    emit "$C_OK" "$S_OK Update log: $LOG_FILE"
    printf '\n'
    emit "$C_DIM" "$S_BULLET Some changes appear the next time you log in."
    printf '\n'
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    reset_failures

    require_non_root
    require_sudo

    # After the restart in pull_latest, the banner and this step are already on screen.
    if [ -z "${VIRESTA_PULLED:-}" ]; then
        banner
        step "Downloading the latest Viresta"
        pull_latest
    else
        STEP=1
    fi

    step "Getting permission to update"
    read_password
    enable_nopasswd

    # Starts here so the time spent typing the password does not count.
    SECONDS=0

    step "Installing new packages"
    install_new_repo_packages
    install_new_aur_packages
    install_shell_packages

    step "Updating Viresta"
    configure_kde_configs --update
    remember_packages

    step_finish
    summary
}

main "$@"
