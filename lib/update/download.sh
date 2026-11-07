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
        git -C "$SCRIPT_DIR" checkout -q "$RELEASE_BRANCH" >>"$LOG_FILE" 2>&1 \
            || die "Could not switch to the latest commit. Nothing was changed."
    fi

    if ! download git -C "$SCRIPT_DIR" pull --ff-only; then
        if [ -n "$release" ]; then
            git -C "$SCRIPT_DIR" checkout -q "$release" >>"$LOG_FILE" 2>&1 || true
        fi
        die "$DOWNLOAD_ERROR"
    fi
}

download() {
    local output status=0

    output="$("$@" 2>&1)" || status=$?
    [ -z "$output" ] || printf '%s\n' "$output" >>"$LOG_FILE"
    [ "$status" -ne 0 ] || return 0

    if grep -qiE 'could not resolve host|failed to connect|could not connect|connection timed out|network is unreachable|connection refused' <<<"$output"; then
        DOWNLOAD_ERROR="Could not reach GitHub. Check your internet connection, then try again. Nothing was changed."
    else
        DOWNLOAD_ERROR="Could not download the latest Viresta. Nothing was changed."
    fi
    return "$status"
}

# Only ever forwards, so someone on a newer commit is not moved back to an older release.
# Asks first, since after this the folder is on the new version.
follow_releases() {
    local release="$1"

    if is_newer_version "${release#v}" "$(viresta_version)"; then
        ask_to_update "$release"
        git -C "$SCRIPT_DIR" checkout -q "$release" >>"$LOG_FILE" 2>&1 \
            || die "Could not switch to $release. Nothing was changed."
    fi
}

# ------------------------------------------------------------
# Questions
# ------------------------------------------------------------

# Only one of these is ever asked. Yes always means the whole update, configs too.
ask_to_update() {
    local version

    version="$(viresta_version)"
    step_finish
    # After an update that stopped halfway, the folder is on a version the system is not.
    if [ -s "$UPDATE_PENDING_FILE" ]; then
        emit "$C_OK" "$S_OK Viresta ${1#v} is out (the last update, to $(cat "$UPDATE_PENDING_FILE"), didn't finish)"
    else
        emit "$C_OK" "$S_OK Viresta ${1#v} is out (you're on ${version:-an older version})"
    fi
    if ! ask_yes_no "Update now?" y; then
        printf 'Nothing was changed.\n'
        exit 0
    fi
    printf '\n'
}

ask_to_finish() {
    step_finish
    emit "$C_WARN" "! The last update to $(cat "$UPDATE_PENDING_FILE") didn't finish"
    if ! ask_yes_no "Finish it now?" y; then
        exit 0
    fi
    printf '\n'
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
# VIRESTA_PULLED tells that fresh start the download is already done, and
# VIRESTA_NEW_RELEASE which release it moved to, for the summary.
pull_latest() {
    local before before_version after_version release new_release=""
    local -a flags=()

    git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "This folder is not a git clone, so it cannot download updates. Clone Viresta with git."
    [ -z "$(git -C "$SCRIPT_DIR" status --porcelain)" ] \
        || die "This folder has local edits, so nothing was changed. Commit them, then try again."

    before="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
    before_version="$(viresta_version)"

    download git -C "$SCRIPT_DIR" fetch --tags origin || die "$DOWNLOAD_ERROR"
    release="$(newest_release)"

    if [ "$DEV" -eq 1 ] || [ -z "$release" ]; then
        follow_latest_commit
    else
        follow_releases "$release"
    fi

    # Nothing new to download, but the last update may have stopped after its download, so
    # the folder only looks up to date.
    if [ "$(git -C "$SCRIPT_DIR" rev-parse HEAD)" = "$before" ]; then
        if [ -s "$UPDATE_PENDING_FILE" ]; then
            ask_to_finish
        else
            ask_to_apply_again
        fi
        return 0
    fi

    step_finish
    after_version="$(viresta_version)"

    # The folder is on the new version now, and update.sh removes this once it is done.
    mkdir -p "$(dirname "$UPDATE_PENDING_FILE")"
    if [ "$DEV" -eq 1 ] || [ -z "$release" ]; then
        printf 'the latest commit\n' >"$UPDATE_PENDING_FILE"
    else
        printf 'v%s\n' "$after_version" >"$UPDATE_PENDING_FILE"
    fi

    if [ "$after_version" != "$before_version" ]; then
        emit "$C_OK" "$S_OK Updating Viresta${before_version:+ v$before_version} to v$after_version"
        if [ "$DEV" -eq 0 ]; then
            new_release="v$after_version"
        fi
    fi
    [ "$VERBOSE" -eq 0 ] || flags+=(--verbose)
    [ "$DEV" -eq 0 ] || flags+=(--dev)
    VIRESTA_PULLED=1 VIRESTA_NEW_RELEASE="$new_release" exec bash "$SCRIPT_DIR/update.sh" "${flags[@]}"
}
