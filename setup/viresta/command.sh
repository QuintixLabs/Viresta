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

    # Both go in, since the login shell can change later. Each does nothing without its shell.
    sudo install -Dm644 "$BASH_COMPLETION_SOURCE" "$BASH_COMPLETION_FILE"
    sudo install -Dm644 "$FISH_COMPLETION_SOURCE" "$FISH_COMPLETION_FILE"
    track "$BASH_COMPLETION_FILE"
    track "$FISH_COMPLETION_FILE"
    printf 'Installed %s and %s\n' "$BASH_COMPLETION_FILE" "$FISH_COMPLETION_FILE"

    mkdir -p "$(dirname "$VIRESTA_FOLDER_FILE")"
    printf '%s\n' "$REPO_DIR" >"$VIRESTA_FOLDER_FILE"
}
