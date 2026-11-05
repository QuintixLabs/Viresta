#!/usr/bin/env bash

# install.sh
# Runs the Viresta install from start to finish.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR/setup"
DRY_RUN=0
DRIVERS_STEP=1

# ------------------------------------------------------------
# Libraries
# ------------------------------------------------------------

# shellcheck source=setup/shared/variables.sh
source "$SETUP_DIR/shared/variables.sh"
# shellcheck source=lib/load.sh
source "$SCRIPT_DIR/lib/load.sh"

# ------------------------------------------------------------
# Flags and saved choices
# ------------------------------------------------------------

usage() {
    help_header "${VIRESTA_RUN_AS:-./install.sh} [options]"
    help_option "--dry-run" "Show what would be done without changing anything"
    help_option "--logs" "Show what failed in the last install, without installing anything"
    help_option "--verbose" "Show everything on screen instead of only the steps"
    help_option "-h, --help" "Show this help"
    printf '\n'
}

# Every variable starting with USE_, so a new option is saved without being listed here.
save_options() {
    local name option

    mkdir -p "$(dirname "$SAVED_OPTIONS_FILE")"
    for name in $(compgen -v USE_); do
        option="${name#USE_}"
        printf '%s=%s\n' "${option,,}" "${!name}"
    done >"$SAVED_OPTIONS_FILE"
}

load_saved_options

for arg in "$@"; do
    case "$arg" in
        # A dry run's only output is what it would do, so it is always verbose.
        --dry-run) DRY_RUN=1; VERBOSE=1 ;;
        --verbose) VERBOSE=1 ;;
        --logs) show_failures; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done
export DRY_RUN

if [ "$DRY_RUN" -eq 0 ]; then
    use_newest_release "$@"
fi

start_script

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

# Starts from the saved choices.
ask_options() {
    local drivers

    [ "$DRY_RUN" -eq 0 ] || return 0

    drivers="$(drivers_summary)"

    add_option vicinae "Vicinae" "Faster, better looking app launcher than KDE's own" "$USE_VICINAE" "Applications"
    add_option rename_wallpapers "rename_wallpapers.py" "Renames your wallpapers in ~/Pictures/Wallpapers" "$USE_RENAME_WALLPAPERS" "Scripts"
    if [ -n "$drivers" ]; then
        add_option drivers "Install drivers" "$drivers" "$USE_DRIVERS" "Drivers"
    fi

    choose_options

    USE_VICINAE=0
    if option_enabled vicinae; then USE_VICINAE=1; fi
    USE_RENAME_WALLPAPERS=0
    if option_enabled rename_wallpapers; then USE_RENAME_WALLPAPERS=1; fi
    if [ -n "$drivers" ]; then
        USE_DRIVERS=0
        if option_enabled drivers; then USE_DRIVERS=1; fi
    fi

    save_options
}

# Decided here and not at the top, since the step count depends on the menu.
plan_drivers() {
    if [ "$USE_DRIVERS" -eq 0 ] || [ -z "$(missing_drivers)" ]; then
        DRIVERS_STEP=0
        TOTAL_STEPS=$((TOTAL_STEPS - 1))
    fi
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

    detect_hardware
    if has_hardware nvidia-580xx || has_hardware nvidia-laptop; then
        warn "Your NVIDIA setup has not been tested on real hardware yet. See the FAQ if the desktop does not start."
    fi
    if has_hardware nvidia-old; then
        warn "Your NVIDIA card is too old for the current drivers, so it stays on nouveau."
    fi

    ask_options
    plan_drivers
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
    install_shell_packages

    if [ "$DRIVERS_STEP" -eq 1 ]; then
        step "Installing drivers"
        install_drivers
    fi

    step "Setting up your desktop"
    configure_networkmanager
    if [ "$USE_DRIVERS" -eq 1 ]; then
        configure_driver_services
    fi
    configure_sddm
    configure_kde_configs
    configure_vscodium
    save_known_packages

    step_finish
    summary
}

main "$@"
