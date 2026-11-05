#!/usr/bin/env bash

# uninstall.sh
# Removes Viresta and leaves plain KDE Plasma.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR/setup"
DRY_RUN=0
REMOVE_APPS=1
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/uninstall.log"
FAILURE_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/viresta/uninstall-failures.log"

# shellcheck source=setup/shared/variables.sh
source "$SETUP_DIR/shared/variables.sh"
# shellcheck source=setup/desktop/sound.sh
source "$SETUP_DIR/desktop/sound.sh"
# shellcheck source=lib/load.sh
source "$SCRIPT_DIR/lib/load.sh"
# shellcheck source=lib/uninstall/files.sh
source "$SCRIPT_DIR/lib/uninstall/files.sh"
# shellcheck source=lib/uninstall/remove-pkgs.sh
source "$SCRIPT_DIR/lib/uninstall/remove-pkgs.sh"

TOTAL_STEPS=6

# ------------------------------------------------------------
# Flags
# ------------------------------------------------------------

usage() {
    help_header "./uninstall.sh [options]"
    help_option "--dry-run" "Show what would be removed without changing anything"
    help_option "--verbose" "Show everything on screen instead of only the steps"
    help_option "-h, --help" "Show this help"
    printf '\n'
    help_note "Removes Viresta and resets KDE to its defaults."
    help_note "Config files Viresta installed are deleted, including any changes you made to them."
    printf '\n'
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; VERBOSE=1 ;;
        --verbose) VERBOSE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done
export DRY_RUN

# Comes before the startup, which would create a log for nothing.
if ! viresta_is_installed; then
    printf 'Viresta is not installed, so there is nothing to remove.\n'
    exit 0
fi

start_script

# ------------------------------------------------------------
# Checks
# ------------------------------------------------------------

require_install_record() {
    [ -f "$INSTALLED_FILES" ] \
        || die "No record of what Viresta installed. Run ./update.sh once, then try again."
}

require_logged_out() {
    pgrep -u "$(id -u)" -x 'plasmashell|kwin_wayland|kwin_x11' >/dev/null 2>&1 || return 0

    error "Plasma is running, and it would write its configs back when it closes."
    printf '\nTo uninstall:\n'
    printf '  1. Log out of Plasma\n'
    printf '  2. Press Ctrl+Alt+F3 and log in\n'
    printf '  3. Run: cd %s && ./uninstall.sh\n\n' "$SCRIPT_DIR"
    exit 1
}

# ------------------------------------------------------------
# Preview
# ------------------------------------------------------------

dry_run() {
    local -a pkgs=()

    info "Would delete these files and folders:"
    sed 's/^/      /' "$INSTALLED_FILES"

    mapfile -t pkgs < <(packages_to_remove)
    info "Would ask, then remove these packages at most: ${pkgs[*]:-none}"
    info "Would keep: dolphin, paru and anything you had before Viresta"
    if [ -d "$BACKUP_DIR" ]; then
        info "Would put back your configs from before Viresta"
    fi
    printf '\n%bDry run complete - nothing was changed%b\n\n' "$C_WARN$C_BOLD" "$C_RESET"
}

# ------------------------------------------------------------
# Questions
# ------------------------------------------------------------

confirm_uninstall() {
    printf 'This removes Viresta and resets KDE to its defaults.\n'
    printf 'Config files Viresta installed will be deleted, including any changes you made.\n\n'
    ask_yes_no "Continue?" n || {
        printf 'Nothing was changed.\n'
        exit 0
    }

    printf '\n'
    REMOVE_APPS=0
    if ask_yes_no "Also remove the main apps Viresta installed? (Firefox, Kitty, VSCodium, Haruna, Fooyin and others)" n; then
        REMOVE_APPS=1
    fi
    printf '\n'
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

summary() {
    printf '\n'
    hr
    printf '%bViresta is removed%b\n' "$C_OK$C_BOLD" "$C_RESET"
    emit "$C_OK" "$S_OK Time taken: $(format_duration "$SECONDS")"
    print_failures
    emit "$C_OK" "$S_OK Uninstall log: $LOG_FILE"
    emit "$C_DIM" "$S_BULLET This Viresta folder was left in place, and you can delete it: $SCRIPT_DIR"
    printf '\n'
    emit "$C_DIM" "$S_BULLET Reboot to start plain KDE Plasma:"
    printf '%bsudo reboot%b\n\n' "$C_ACCENT" "$C_RESET"
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    reset_failures
    banner

    require_non_root
    require_sudo
    require_install_record
    require_logged_out

    if [ "$DRY_RUN" -eq 1 ]; then
        dry_run
        return 0
    fi

    confirm_uninstall

    step "Getting permission to uninstall"
    read_password
    enable_nopasswd

    # Starts here so the time spent typing the password does not count.
    SECONDS=0

    step "Stopping Viresta's services"
    systemctl --user disable --now "$THEME_SYNC_UNIT" "$VICINAE_UNIT" >/dev/null 2>&1 || true
    systemctl --user disable --now "$UPDATE_CHECK_UNIT" >/dev/null 2>&1 || true

    step "Removing Viresta's files"
    remove_viresta_files

    step "Bringing back KDE's themes"
    restore_removed_themes

    step "Removing packages"
    remove_packages

    step "Finishing up"
    finish_uninstall

    step_finish
    summary
}

main "$@"
