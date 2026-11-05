#!/usr/bin/env bash

# load.sh
# Loads what install.sh, update.sh and uninstall.sh all use.

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
# shellcheck source=lib/system/version.sh
source "$SCRIPT_DIR/lib/system/version.sh"
# shellcheck source=lib/system/sudo.sh
source "$SCRIPT_DIR/lib/system/sudo.sh"
# shellcheck source=lib/system/services.sh
source "$SCRIPT_DIR/lib/system/services.sh"
# shellcheck source=lib/installers/pacman.sh
source "$SCRIPT_DIR/lib/installers/pacman.sh"
# shellcheck source=lib/installers/aur.sh
source "$SCRIPT_DIR/lib/installers/aur.sh"
# shellcheck source=setup/shared/shell.sh
source "$SCRIPT_DIR/setup/shared/shell.sh"
# shellcheck source=lib/installers/shell.sh
source "$SCRIPT_DIR/lib/installers/shell.sh"
# shellcheck source=lib/drivers/hardware/detect.sh
source "$SCRIPT_DIR/lib/drivers/hardware/detect.sh"
# shellcheck source=lib/drivers/hardware/list.sh
source "$SCRIPT_DIR/lib/drivers/hardware/list.sh"
# shellcheck source=lib/drivers/hardware/nvidia.sh
source "$SCRIPT_DIR/lib/drivers/hardware/nvidia.sh"
# shellcheck source=lib/drivers/install.sh
source "$SCRIPT_DIR/lib/drivers/install.sh"

# ------------------------------------------------------------
# Startup
# ------------------------------------------------------------

start_script() {
    ui_init

    trap run_cleanups EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
}
