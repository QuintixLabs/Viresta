#!/usr/bin/env bash

# command.sh
# Installs the viresta command, which runs the scripts from anywhere.

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# ~/.local/bin is not where Arch's shells look for commands, so it goes in the system
# folder. The folder is saved on every update, which also finds it again after a move.
# The update alerts read it too.
install_viresta_command() {
    sudo install -Dm755 "$VIRESTA_COMMAND_SOURCE" "$VIRESTA_COMMAND"
    track "$VIRESTA_COMMAND"
    printf 'Installed %s\n' "$VIRESTA_COMMAND"

    mkdir -p "$(dirname "$VIRESTA_FOLDER_FILE")"
    printf '%s\n' "$REPO_DIR" >"$VIRESTA_FOLDER_FILE"
}
