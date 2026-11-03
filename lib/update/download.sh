#!/usr/bin/env bash

# download.sh
# Downloads the latest Viresta for update.sh.

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

# Bash reads a script as it runs, so a new version of update.sh needs a fresh start.
pull_latest() {
    local before
    local -a flags=(--no-pull)

    git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "This folder is not a git clone. Use --no-pull to use its files as they are."
    [ -z "$(git -C "$SCRIPT_DIR" status --porcelain)" ] \
        || die "This folder has local edits, so nothing was changed. Commit them, or use --no-pull."

    before="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
    git -C "$SCRIPT_DIR" pull --ff-only >>"$LOG_FILE" 2>&1 \
        || die "Could not download the latest Viresta. Nothing was changed."

    if [ "$(git -C "$SCRIPT_DIR" rev-parse HEAD)" != "$before" ]; then
        step_finish
        [ "$VERBOSE" -eq 0 ] || flags+=(--verbose)
        exec bash "$SCRIPT_DIR/update.sh" "${flags[@]}"
    fi
}
