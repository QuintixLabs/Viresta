#!/usr/bin/env bash

# pacman.sh
# Tests turning on the multilib repository in pacman.conf, for every way the file can
# look, and that the temporary copy for faster downloads leaves the real one alone.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
VIRESTA_STATE_DIR="$HOME/.local/state/viresta"
source "$VIRESTA/lib/installers/pacman.sh"

DRY_RUN=0
said=""
info() { said="$said|info: $1"; }
ok() { said="$said|ok: $1"; }
failure() { said="$said|FAILURE: $1"; }
sudo() { "$@"; }
register_cleanup() { :; }

turn_on() { said=""; enable_multilib; }
repos() { grep -E '^\[' "$SYSTEM_PACMAN_CONF" | paste -sd' '; }

# ------------------------------------------------------------
# Arch as installed
# ------------------------------------------------------------

fake_pacman_conf
turn_on
is "turned on" "$(repos)" "[options] [core] [extra] [multilib]"
is "its Include line too" "$(grep -A1 '^\[multilib\]$' "$SYSTEM_PACMAN_CONF" | tail -n 1)" "Include = /etc/pacman.d/mirrorlist"
is "multilib-testing stays off" "$(grep -c '^#\[multilib-testing\]$' "$SYSTEM_PACMAN_CONF")" "1"
has "says so" "ok: multilib repository turned on" "$said"

before="$(cat "$SYSTEM_PACMAN_CONF")"
turn_on
is "already on: the file is unchanged" "$(cat "$SYSTEM_PACMAN_CONF")" "$before"
is "already on: says nothing" "$said" ""

# ------------------------------------------------------------
# Other ways the file can look
# ------------------------------------------------------------

printf '[options]\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n' >"$SYSTEM_PACMAN_CONF"
turn_on
is "no multilib lines at all: added" "$(repos)" "[options] [core] [multilib]"
is "added with its Include line" "$(tail -n 1 "$SYSTEM_PACMAN_CONF")" "Include = /etc/pacman.d/mirrorlist"

# The section header without its Include line right under it is left as it is.
printf '[options]\n#[multilib]\n#SigLevel = Never\n#Include = /etc/pacman.d/mirrorlist\n' >"$SYSTEM_PACMAN_CONF"
turn_on
is "an unusual layout: one new section added" "$(grep -c '^\[multilib\]$' "$SYSTEM_PACMAN_CONF")" "1"
is "an unusual layout: its own lines stay off" "$(grep -c '^#SigLevel = Never$' "$SYSTEM_PACMAN_CONF")" "1"

printf '[options]\n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >"$SYSTEM_PACMAN_CONF"
before="$(cat "$SYSTEM_PACMAN_CONF")"
turn_on
is "on already, like CachyOS: unchanged" "$(cat "$SYSTEM_PACMAN_CONF")" "$before"

fake_pacman_conf
DRY_RUN=1
turn_on
is "dry run: says what it would do" "$said" "|info: Would turn on the multilib repository, for 32-bit apps like Steam"
is "dry run: the file is unchanged" "$(grep -c '^\[multilib\]' "$SYSTEM_PACMAN_CONF")" "0"
DRY_RUN=0

rm "$SYSTEM_PACMAN_CONF"
turn_on
is "no pacman.conf, not Arch: does nothing" "$said" ""

# ------------------------------------------------------------
# The copy for faster downloads
# ------------------------------------------------------------

fake_pacman_conf
before="$(cat "$SYSTEM_PACMAN_CONF")"
prepare_pacman_conf
is "the copy downloads 5 at a time" "$(grep -c '^ParallelDownloads = 5$' "$PACMAN_CONF")" "1"
is "the real file keeps its own setting" "$(cat "$SYSTEM_PACMAN_CONF")" "$before"
cleanup_pacman_conf

finish
