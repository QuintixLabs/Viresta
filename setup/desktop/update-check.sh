#!/usr/bin/env bash

# update-check.sh
# Installs the check that alerts the user about new releases.

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# The timer stays on even with alerts turned off, since the check reads that setting
# itself. Saving the folder on every update also finds it again after a move.
install_update_check() {
    local wants_dir="$CONFIG_DIR/systemd/user/graphical-session.target.wants"

    install -Dm755 "$UPDATE_CHECK_SOURCE" "$UPDATE_CHECK_SCRIPT"
    printf 'Installed %s\n' "$UPDATE_CHECK_SCRIPT"

    mkdir -p "$(dirname "$VIRESTA_FOLDER_FILE")" "$wants_dir"
    printf '%s\n' "$REPO_DIR" >"$VIRESTA_FOLDER_FILE"

    ln -sfn "../$UPDATE_CHECK_UNIT" "$wants_dir/$UPDATE_CHECK_UNIT"
    printf 'Enabled %s\n' "$UPDATE_CHECK_UNIT"
}
