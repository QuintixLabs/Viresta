#!/usr/bin/env bash

# download.sh
# Downloads the newest release, or the latest commit with --dev, for update.sh.

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

# A release leaves the folder on its tag, which has no branch to pull from. If the
# download then fails, the folder goes back to that tag, so nothing was changed.
follow_latest_commit() {
    local release=""

    if ! git -C "$SCRIPT_DIR" symbolic-ref -q HEAD >/dev/null; then
        release="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
        git -C "$SCRIPT_DIR" checkout -q "$DEV_BRANCH" >>"$LOG_FILE" 2>&1 \
            || die "Could not switch to the latest commit. Nothing was changed."
    fi

    if ! git -C "$SCRIPT_DIR" pull --ff-only >>"$LOG_FILE" 2>&1; then
        if [ -n "$release" ]; then
            git -C "$SCRIPT_DIR" checkout -q "$release" >>"$LOG_FILE" 2>&1 || true
        fi
        die "Could not download the latest Viresta. Nothing was changed."
    fi
}

# Only ever forwards, so someone on a newer commit is not moved back to an older release.
follow_releases() {
    local release="$1"

    if is_newer_version "${release#v}" "$(viresta_version)"; then
        git -C "$SCRIPT_DIR" checkout -q "$release" >>"$LOG_FILE" 2>&1 \
            || die "Could not switch to $release. Nothing was changed."
    fi
}

ask_to_apply_again() {
    local version

    version="$(viresta_version)"
    step_finish
    emit "$C_OK" "$S_OK Viresta is up to date${version:+ (v$version)}"
    if ! ask_yes_no "Apply Viresta's configs again anyway?" n; then
        exit 0
    fi
    printf '\n'
}

# Bash reads a script as it runs, so a new version of update.sh needs a fresh start.
# VIRESTA_PULLED tells that fresh start the download is already done.
pull_latest() {
    local before before_version after_version release
    local -a flags=()

    git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "This folder is not a git clone, so it cannot download updates. Clone Viresta with git."
    [ -z "$(git -C "$SCRIPT_DIR" status --porcelain)" ] \
        || die "This folder has local edits, so nothing was changed. Commit them, then try again."

    before="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
    before_version="$(viresta_version)"

    git -C "$SCRIPT_DIR" fetch --tags origin >>"$LOG_FILE" 2>&1 \
        || die "Could not download the latest Viresta. Nothing was changed."
    release="$(newest_release)"

    if [ "$DEV" -eq 1 ] || [ -z "$release" ]; then
        follow_latest_commit
    else
        follow_releases "$release"
    fi

    if [ "$(git -C "$SCRIPT_DIR" rev-parse HEAD)" = "$before" ]; then
        ask_to_apply_again
        return 0
    fi

    step_finish
    after_version="$(viresta_version)"
    if [ "$after_version" != "$before_version" ]; then
        emit "$C_OK" "$S_OK Updating Viresta${before_version:+ v$before_version} to v$after_version"
    fi
    [ "$VERBOSE" -eq 0 ] || flags+=(--verbose)
    [ "$DEV" -eq 0 ] || flags+=(--dev)
    VIRESTA_PULLED=1 exec bash "$SCRIPT_DIR/update.sh" "${flags[@]}"
}
