#!/usr/bin/env bash

# install.sh
# Runs the Viresta install from start to finish.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
SKIP_VM=0
INSTALL_VICINAE=1
INSTALL_RENAME_WALLPAPERS=1
# Read by setup/setup.sh too.
SAVED_OPTIONS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/viresta/options"

# ------------------------------------------------------------
# Libraries
# ------------------------------------------------------------

# shellcheck source=lib/load.sh
source "$SCRIPT_DIR/lib/load.sh"

# ------------------------------------------------------------
# Flags and saved choices
# ------------------------------------------------------------

usage() {
    help_header "./install.sh [options]"
    help_option "--dry-run" "Show what would be done without changing anything"
    help_option "--no-vm" "Skip VM packages and services"
    help_option "--logs" "Show what failed in the last install, without installing anything"
    help_option "--verbose" "Show everything on screen instead of only the steps"
    help_option "-h, --help" "Show this help"
    printf '\n'
}

load_saved_options() {
    if grep -qx 'vicinae=0' "$SAVED_OPTIONS_FILE" 2>/dev/null; then
        INSTALL_VICINAE=0
    fi
    if grep -qx 'rename_wallpapers=0' "$SAVED_OPTIONS_FILE" 2>/dev/null; then
        INSTALL_RENAME_WALLPAPERS=0
    fi
}

save_options() {
    mkdir -p "$(dirname "$SAVED_OPTIONS_FILE")"
    printf 'vicinae=%s\nrename_wallpapers=%s\n' \
        "$INSTALL_VICINAE" "$INSTALL_RENAME_WALLPAPERS" >"$SAVED_OPTIONS_FILE"
}

load_saved_options

for arg in "$@"; do
    case "$arg" in
        # A dry run's only output is what it would do, so it is always verbose.
        --dry-run) DRY_RUN=1; VERBOSE=1 ;;
        --verbose) VERBOSE=1 ;;
        --no-vm) SKIP_VM=1 ;;
        --logs) show_failures; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done
export DRY_RUN
TOTAL_STEPS=$((TOTAL_STEPS - SKIP_VM))

start_script

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

# Starts from the saved choices.
ask_options() {
    [ "$DRY_RUN" -eq 0 ] || return 0

    add_option vicinae "Vicinae" "Faster, better looking app launcher than KDE's own" "$INSTALL_VICINAE"
    add_option rename_wallpapers "rename_wallpapers" "Script that organizes your wallpapers in Pictures" "$INSTALL_RENAME_WALLPAPERS"

    choose_options

    INSTALL_VICINAE=0
    if option_enabled vicinae; then INSTALL_VICINAE=1; fi
    INSTALL_RENAME_WALLPAPERS=0
    if option_enabled rename_wallpapers; then INSTALL_RENAME_WALLPAPERS=1; fi

    save_options
}

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

# Only asks if there is something to lose. Once Viresta is installed, those configs
# are its own, and update.sh looks after them.
offer_backup() {
    local setup="$SCRIPT_DIR/setup/setup.sh"
    local count

    [ "$DRY_RUN" -eq 0 ] || return 0
    [ ! -e "$VIRESTA_STATE_DIR/installed-files" ] || return 0

    count="$(bash "$setup" --list-replaced 2>/dev/null | grep -c '^/' || true)"
    [ "${count:-0}" -gt 0 ] || return 0

    if ask_yes_no "Found $count of your configs that Viresta will replace. Back them up first?" y; then
        bash "$setup" --back-up >>"$LOG_FILE" 2>&1 || die "Could not back up your configs."
        ok "Configs backed up. uninstall.sh puts them back."
    fi
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

summary() {
    local elapsed="$SECONDS"

    printf '\n'
    hr
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%bDry run complete - nothing was changed%b\n' "$C_WARN$C_BOLD" "$C_RESET"
    else
        printf '%bInstallation complete%b\n' "$C_OK$C_BOLD" "$C_RESET"
        emit "$C_OK" "$S_OK Time taken: $(format_duration "$elapsed")"
        if [ "$(failure_count)" -gt 0 ]; then
            emit "$C_WARN" "! $(failure_count) failed - run ./install.sh --logs to see them"
        fi
        emit "$C_OK" "$S_OK Temporary sudo rule removed on exit"
        emit "$C_OK" "$S_OK Install log: $LOG_FILE"
        emit "$C_OK" "$S_OK AUR build logs: $AUR_LOG_DIR"
        printf '\n'
        emit "$C_DIM" "$S_BULLET Reboot to start KDE Plasma (Wayland) from SDDM:"
        printf '%bsudo reboot%b\n' "$C_ACCENT" "$C_RESET"
    fi
    printf '\n'
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    reset_failures
    banner
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "DRY RUN: no changes will be made"
    fi

    ask_options
    offer_backup

    step "Checking your system"
    preflight

    step "Getting permission to install"
    if [ "$DRY_RUN" -eq 1 ]; then
        info "Would ask for your password once"
    else
        read_password
    fi
    enable_nopasswd

    # Starts here so the time spent typing the password does not count.
    SECONDS=0

    save_packages_before

    step "Updating system"
    update_system

    step "Installing system tools"
    install_group "System" "$SCRIPT_DIR/packages/base.txt"

    step "Installing KDE Plasma"
    install_group "KDE Plasma" "$SCRIPT_DIR/packages/kde.txt"

    step "Installing apps"
    install_group_optional "Applications" "$SCRIPT_DIR/packages/apps.txt"

    set_build_jobs

    step "Installing AUR apps"
    if bootstrap_paru; then
        install_aur
    else
        warn "paru unavailable; skipping AUR packages"
    fi

    if [ "$SKIP_VM" -eq 1 ]; then
        step_finish
        warn "Skipping VM packages and services"
    else
        step "Installing VM tools"
        install_vm_extras
    fi

    step "Setting up your desktop"
    configure_networkmanager
    if [ "$SKIP_VM" -eq 0 ]; then
        configure_vm_services
    fi
    configure_sddm
    configure_kde_configs
    configure_vscodium
    save_known_packages

    step_finish
    summary
}

main "$@"
