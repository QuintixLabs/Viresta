#!/usr/bin/env bash

# version.sh
# Knows which version this folder is on, and which release is the newest.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

DEV_BRANCH="master"
RELEASES_URL="https://github.com/QuintixLabs/Viresta/releases"

# ------------------------------------------------------------
# Versions
# ------------------------------------------------------------

viresta_version() {
    if [ -f "$SCRIPT_DIR/VERSION" ]; then
        tr -d '[:space:]' <"$SCRIPT_DIR/VERSION"
    fi
}

# Publishing a release is what creates its tag, so a repo with no tags has no releases.
newest_release() {
    git -C "$SCRIPT_DIR" tag --list 'v[0-9]*' --sort=-v:refname 2>/dev/null | sed -n 1p
}

# Asks GitHub without changing the folder. Only plain numbers count, since the result is
# shown to the user. It never waits for a password, as nobody is there to type one.
newest_online_release() {
    GIT_TERMINAL_PROMPT=0 timeout 30 git -C "$SCRIPT_DIR" ls-remote --tags --refs origin 2>/dev/null \
        | sed -n 's|.*refs/tags/\(v[0-9][0-9.]*\)$|\1|p' \
        | sort -V \
        | tail -n 1
}

# Someone on another branch is there to test it, so releases are not for them. A release
# leaves the folder on its tag, which has no branch at all.
follows_releases() {
    local branch

    branch="$(git -C "$SCRIPT_DIR" symbolic-ref -q --short HEAD || true)"
    [ -z "$branch" ] || [ "$branch" = "$DEV_BRANCH" ]
}

# An older folder has no VERSION file, so any release counts as newer.
is_newer_version() {
    local new="$1" current="$2"

    [ "$new" != "$current" ] || return 1
    case "$current" in
        [0-9]*) ;;
        *) return 0 ;;
    esac
    [ "$(printf '%s\n%s\n' "$new" "$current" | sort -V | tail -n 1)" = "$new" ]
}

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# A plain git clone is on the latest commit, which may not be ready for anyone yet. Bash
# reads a script as it runs, so the release's own install.sh needs a fresh start. With no
# releases, or local edits to keep, this folder is installed as it is. So is any other
# branch, since someone on one is there to test it.
use_newest_release() {
    local release

    git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    follows_releases || return 0

    git -C "$SCRIPT_DIR" fetch -q --tags origin >/dev/null 2>&1 || true
    release="$(newest_release)"
    [ -n "$release" ] || return 0

    if [ "$(git -C "$SCRIPT_DIR" rev-parse HEAD)" = "$(git -C "$SCRIPT_DIR" rev-parse "$release^{commit}")" ]; then
        return 0
    fi
    if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]; then
        printf 'This folder has local edits, so it is installed as it is and not as %s.\n' "$release"
        return 0
    fi

    git -C "$SCRIPT_DIR" checkout -q "$release" || return 0
    exec bash "$SCRIPT_DIR/install.sh" "$@"
}
