#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0

# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/system.sh
source "$SCRIPT_DIR/lib/system.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

usage() {
    cat <<'EOF'
Viresta - Arch Linux + KDE Plasma 6 installer

Usage: ./install.sh [options]

Options:
  --dry-run   Show what would be done without changing anything
  -h, --help  Show this help
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n\n' "$arg" >&2; usage; exit 2 ;;
    esac
done
export DRY_RUN

ui_init

trap run_cleanups EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

summary() {
    printf '\n'
    hr
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%b  Dry run complete - nothing was changed%b\n' "$C_WARN$C_BOLD" "$C_RESET"
    else
        printf '%b  Installation complete%b\n' "$C_OK$C_BOLD" "$C_RESET"
        ok "Temporary sudo rule removed on exit"
        ok "Install log: $LOG_FILE"
        ok "AUR build logs: $AUR_LOG_DIR"
        printf '\n'
        info "Reboot to start KDE Plasma (Wayland) from SDDM:"
        printf '      %bsudo reboot%b\n' "$C_ACCENT" "$C_RESET"
    fi
    printf '\n'
}

main() {
    banner
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "DRY RUN: no changes will be made"
    fi

    step "Preflight checks"
    preflight

    step "Temporary passwordless sudo"
    if [ "$DRY_RUN" -eq 1 ]; then
        info "Would ask for your password once"
    else
        read_password
    fi
    enable_nopasswd

    step "Updating system"
    update_system

    step "Installing system packages"
    install_group "System" "$SCRIPT_DIR/packages/base.txt"

    step "Installing KDE Plasma"
    install_group "KDE Plasma" "$SCRIPT_DIR/packages/kde.txt"

    step "Installing applications"
    install_group "Applications" "$SCRIPT_DIR/packages/apps.txt"

    step "Installing paru & AUR packages"
    if bootstrap_paru; then
        install_aur
    else
        warn "paru unavailable; skipping AUR packages"
    fi

    step "Installing VM extras"
    install_vm_extras

    step "Services, theme & login"
    configure_networkmanager
    configure_vm_services
    configure_sddm
    configure_default_session
    apply_dark_theme

    summary
}

main "$@"
