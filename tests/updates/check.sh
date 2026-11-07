#!/usr/bin/env bash

# check.sh
# Tests update --check, which says whether a new release is out without updating.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
make_clone 1.0.0
mark_installed
before="$(git -C "$VIRESTA" rev-parse HEAD)"

# ------------------------------------------------------------
# Tests
# ------------------------------------------------------------

is "up to date" "$(viresta update --check)" "Viresta is up to date (v1.0.0)."

release 1.1.0
is "new release" "$(viresta update --check)" "Viresta 1.1.0 is out. You're on 1.0.0. Run viresta update to get it."
is "run from the folder" "$(bash "$VIRESTA/update.sh" --check)" "Viresta 1.1.0 is out. You're on 1.0.0. Run ./update.sh to get it."
is "the folder is not moved" "$(git -C "$VIRESTA" rev-parse HEAD)" "$before"
is "no tags are downloaded" "$(git -C "$VIRESTA" tag)" "v1.0.0"
missing "no update log is made" "$HOME/.local/state/viresta/update.log"

git -C "$VIRESTA" checkout -q -b my-change
is "works on a branch too" "$(viresta update --check | cut -c1-21)" "Viresta 1.1.0 is out."
git -C "$VIRESTA" checkout -q v1.0.0

no_internet
is "no internet" "$(viresta update --check 2>&1; echo "exit=$?")" "Could not check for a new release. Check your internet connection.
exit=1"
internet_back

finish
