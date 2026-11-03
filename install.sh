#!/usr/bin/env bash

# install.sh
# Runs the Viresta install from start to finish.

set -euo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
SKIP_AUR=0
SKIP_VM=0
INSTALL_VICINAE=1
INSTALL_RENAME_WALLPAPERS=1
# Set when a flag already answered the question, so the menu does not ask it.
VICINAE_FLAG=0
RENAME_WALLPAPERS_FLAG=0
# Read by setup/setup.sh too.
SAVED_OPTIONS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/viresta/options"

# ------------------------------------------------------------
# Libraries
# ------------------------------------------------------------

# shellcheck source=lib/ui/messages.sh
source "$SCRIPT_DIR/lib/ui/messages.sh"
# shellcheck source=lib/ui/steps.sh
source "$SCRIPT_DIR/lib/ui/steps.sh"
# shellcheck source=lib/ui/menu.sh
source "$SCRIPT_DIR/lib/ui/menu.sh"
# shellcheck source=lib/ui/failures.sh
source "$SCRIPT_DIR/lib/ui/failures.sh"
# shellcheck source=lib/system/checks.sh
source "$SCRIPT_DIR/lib/system/checks.sh"
# shellcheck source=lib/system/sudo.sh
source "$SCRIPT_DIR/lib/system/sudo.sh"
# shellcheck source=lib/system/services.sh
source "$SCRIPT_DIR/lib/system/services.sh"
# shellcheck source=lib/installers/pacman.sh
source "$SCRIPT_DIR/lib/installers/pacman.sh"
# shellcheck source=lib/installers/aur.sh
source "$SCRIPT_DIR/lib/installers/aur.sh"
# shellcheck source=lib/installers/vm.sh
source "$SCRIPT_DIR/lib/installers/vm.sh"

# ------------------------------------------------------------
# Flags and saved choices
# ------------------------------------------------------------

usage() {
    cat <<'EOF'
Viresta - Arch Linux + KDE Plasma 6 installer

Usage: ./install.sh [options]

Options:
  --dry-run   Show what would be done without changing anything
  --no-aur    Skip paru and the AUR packages in packages/aur.txt
  --no-vm     Skip VM packages and services
  --fast      Same as --no-aur --no-vm, for quick test installs
  --no-vicinae
              Use the normal KDE app launcher instead of Vicinae
  --no-rename-wallpapers
              Skip the rename_wallpapers.py script
  --logs      Show what failed in the last install, without installing anything
  --verbose   Show everything on screen instead of only the steps
  -h, --help  Show this help

Vicinae comes from the AUR, so --no-aur and --fast use the KDE app launcher too.
What you choose is remembered for the next run.
EOF
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
        --no-aur) SKIP_AUR=1 ;;
        --no-vm) SKIP_VM=1 ;;
        --fast) SKIP_AUR=1; SKIP_VM=1 ;;
        --no-vicinae) INSTALL_VICINAE=0; VICINAE_FLAG=1 ;;
        --no-rename-wallpapers) INSTALL_RENAME_WALLPAPERS=0; RENAME_WALLPAPERS_FLAG=1 ;;
        --logs) show_failures; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done
export DRY_RUN
TOTAL_STEPS=$((TOTAL_STEPS - SKIP_AUR - SKIP_VM))

# ------------------------------------------------------------
# Startup
# ------------------------------------------------------------

ui_init

trap run_cleanups EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

# Starts from the saved choices, and only asks what the flags have not answered.
# --fast and --no-aur are for one run, so they neither ask about Vicinae nor change
# what is saved for it.
ask_options() {
    local ask_vicinae=0 ask_rename_wallpapers=0

    if [ "$DRY_RUN" -eq 0 ]; then
        if [ "$VICINAE_FLAG" -eq 0 ] && [ "$SKIP_AUR" -eq 0 ]; then
            ask_vicinae=1
            add_option vicinae "Vicinae" "Faster, better looking app launcher than KDE's own" "$INSTALL_VICINAE"
        fi
        if [ "$RENAME_WALLPAPERS_FLAG" -eq 0 ]; then
            ask_rename_wallpapers=1
            add_option rename_wallpapers "rename_wallpapers" "Script that organizes your wallpapers in Pictures" "$INSTALL_RENAME_WALLPAPERS"
        fi

        choose_options

        if [ "$ask_vicinae" -eq 1 ]; then
            INSTALL_VICINAE=0
            if option_enabled vicinae; then INSTALL_VICINAE=1; fi
        fi
        if [ "$ask_rename_wallpapers" -eq 1 ]; then
            INSTALL_RENAME_WALLPAPERS=0
            if option_enabled rename_wallpapers; then INSTALL_RENAME_WALLPAPERS=1; fi
        fi

        save_options
    fi

    if [ "$SKIP_AUR" -eq 1 ]; then
        INSTALL_VICINAE=0
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
        _emit "$C_OK" "$S_OK Time taken: $(format_duration "$elapsed")"
        if [ "$(failure_count)" -gt 0 ]; then
            _emit "$C_WARN" "! $(failure_count) failed - run ./install.sh --logs to see them"
        fi
        _emit "$C_OK" "$S_OK Temporary sudo rule removed on exit"
        _emit "$C_OK" "$S_OK Install log: $LOG_FILE"
        if [ "$SKIP_AUR" -eq 0 ]; then
            _emit "$C_OK" "$S_OK AUR build logs: $AUR_LOG_DIR"
        fi
        printf '\n'
        _emit "$C_DIM" "$S_BULLET Reboot to start KDE Plasma (Wayland) from SDDM:"
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

    step "Updating system"
    update_system

    step "Installing system tools"
    install_group "System" "$SCRIPT_DIR/packages/base.txt"

    step "Installing KDE Plasma"
    install_group "KDE Plasma" "$SCRIPT_DIR/packages/kde.txt"

    step "Installing apps"
    install_group_optional "Applications" "$SCRIPT_DIR/packages/apps.txt"

    if [ "$SKIP_AUR" -eq 1 ]; then
        step_finish
        warn "Skipping paru and AUR packages: anything in packages/aur.txt will be missing"
    else
        step "Installing AUR apps"
        if bootstrap_paru; then
            install_aur
        else
            warn "paru unavailable; skipping AUR packages"
        fi
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

    step_finish
    summary
}

main "$@"
