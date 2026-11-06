#!/usr/bin/env bash

# bash.sh
# Tests the shell setup: which login shell gets what, the lines in ~/.bashrc, and that
# Bash still starts cleanly with them, before and after an uninstall.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
source "$VIRESTA/setup/shared/shell.sh"
source "$VIRESTA/setup/apps/shell.sh"
source "$VIRESTA/lib/installers/shell.sh"

SCRIPT_DIR="$VIRESTA"
SETUP_MODE=install
SHELL_SOURCE_DIR="$VIRESTA/config/shell"
CONFIG_DIR="$HOME/.config"
BASHRC_ADDED_FILE="$TEST_DIR/bashrc-added"
NOTES="$TEST_DIR/notes"
CALLS="$TEST_DIR/shell-calls"
DRY_RUN=0
INSTALLED=no
FAKE_SHELL=/bin/bash

note() { printf '%s\n' "$1" >>"$NOTES"; }
install_shared_file() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }
getent() { printf 'frost:x:1000:1000::/home/frost:%s\n' "$FAKE_SHELL"; }
info() { :; }
failure() { printf 'FAILURE: %s\n' "$1"; }
is_installed() { [ "$INSTALLED" = yes ]; }
pkg_source() { case "$1" in blesh-git) echo aur ;; *) echo repo ;; esac; }
aur_install_one() { printf 'aur %s;' "$1" >>"$CALLS"; }
run_pacman() { printf 'pacman %s;' "$4" >>"$CALLS"; }
read_package_list() { sed -e 's/#.*//' -e '/^$/d' "$1"; }

clean() { rm -rf "$BASHRC_FILE" "$BASHRC_ADDED_FILE" "$NOTES" "$HOME/.blerc" "$CALLS" "$HOME/.config"; }
THEIRS=$'# My bashrc\n[[ $- != *i* ]] && return\nalias ll="ls -l"\nexport MINE=1'

# The uninstall step, taken from files.sh as it is.
eval "$(sed -n '/^remove_bash_setup() {/,/^}/p' "$VIRESTA/lib/uninstall/files.sh")"

# ------------------------------------------------------------
# Which shell
# ------------------------------------------------------------

for FAKE_SHELL in /bin/bash /usr/bin/bash; do is "$FAKE_SHELL" "$(login_shell)" "bash"; done
for FAKE_SHELL in /usr/bin/fish /bin/fish; do is "$FAKE_SHELL" "$(login_shell)" "fish"; done
FAKE_SHELL=/bin/zsh; is "zsh" "$(login_shell)" "zsh"
FAKE_SHELL=''; is "no shell" "$(login_shell)" ""
FAKE_SHELL=/bin/bash

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------

packages_for() { FAKE_SHELL="$1"; : >"$CALLS"; install_shell_packages; cat "$CALLS"; FAKE_SHELL=/bin/bash; }
is "bash: its packages" "$(packages_for /bin/bash)" "pacman starship;aur blesh-git;pacman bash-completion;"
is "fish: only starship" "$(packages_for /usr/bin/fish)" "pacman starship;"
is "zsh: nothing" "$(packages_for /bin/zsh)" ""
is "no shell: nothing" "$(packages_for '')" ""
INSTALLED=yes
is "already installed: nothing" "$(packages_for /bin/bash)" ""
INSTALLED=no

# ------------------------------------------------------------
# Other shells
# ------------------------------------------------------------

clean
printf '%s\n' "$THEIRS" >"$BASHRC_FILE"
FAKE_SHELL=/bin/zsh; install_shell_setup; FAKE_SHELL=/bin/bash
is "zsh: .bashrc untouched" "$(cat "$BASHRC_FILE")" "$THEIRS"
missing "zsh: no starship config" "$HOME/.config/starship.toml"
missing "zsh: no fish file" "$HOME/.config/fish/conf.d/viresta.fish"

clean
printf '%s\n' "$THEIRS" >"$BASHRC_FILE"
mkdir -p "$HOME/.config/fish"
printf 'set MINE 1\n' >"$HOME/.config/fish/config.fish"
FAKE_SHELL=/usr/bin/fish; install_shell_setup; FAKE_SHELL=/bin/bash
is "fish: .bashrc untouched" "$(cat "$BASHRC_FILE")" "$THEIRS"
missing "fish: no blerc" "$HOME/.blerc"
exists "fish: starship config" "$HOME/.config/starship.toml"
exists "fish: its file in conf.d" "$HOME/.config/fish/conf.d/viresta.fish"
is "fish: their config.fish untouched" "$(cat "$HOME/.config/fish/config.fish")" "set MINE 1"

clean
install_shell_setup >/dev/null
missing "bash: no fish file" "$HOME/.config/fish/conf.d/viresta.fish"
exists "bash: blerc" "$HOME/.blerc"

# ------------------------------------------------------------
# Installing the lines
# ------------------------------------------------------------

clean
printf '%s\n' "$THEIRS" >"$BASHRC_FILE"
install_bash_setup >/dev/null
is "ble.sh loads on the first line" "$(sed -n 2p "$BASHRC_FILE" | grep -c 'attach=none')" "1"
is "ble.sh attaches on the last line" "$(tail -n 2 "$BASHRC_FILE" | head -n 1)" '[[ ! ${BLE_VERSION-} ]] || ble-attach'
is "starship comes before that" "$(tail -n 3 "$BASHRC_FILE" | head -n 1 | grep -c 'starship init bash')" "1"
is "their lines are all there, in order" "$(cp "$BASHRC_FILE" "$TEST_DIR/copy"; BASHRC_FILE="$TEST_DIR/copy" remove_bashrc_lines; cat "$TEST_DIR/copy")" "$THEIRS"
install_bash_setup >/dev/null
is "installed again: still one set" "$(grep -cxF "$BASHRC_START" "$BASHRC_FILE")" "2"
is "the result is valid Bash" "$(bash -n "$BASHRC_FILE" 2>&1; echo $?)" "0"

# With the packages gone, like after removing them by hand.
out="$(PATH=/usr/bin:/bin bash --noprofile --rcfile "$BASHRC_FILE" -ic 'echo MINE=$MINE; alias ll' 2>&1)"
is "no packages: no errors" "$(grep -c 'not found\|No such file\|error' <<<"$out")" "0"
is "no packages: their settings load" "$(grep -c 'MINE=1' <<<"$out")" "1"
is "not interactive: nothing runs" "$(PATH=/usr/bin:/bin bash --noprofile --rcfile "$BASHRC_FILE" -c 'echo fine' 2>&1)" "fine"

# A fake starship, to see it really runs, but not on the plain text login.
printf '#!/bin/sh\necho '\''PS1="STARSHIP> "; echo STARSHIP_RAN'\''\n' >"$BIN/starship"
chmod +x "$BIN/starship"
is "in a terminal: starship runs" "$(TERM=xterm bash --noprofile --rcfile "$BASHRC_FILE" -i </dev/null 2>/dev/null | grep -c STARSHIP_RAN)" "1"
is "text login: starship stays off" "$(TERM=linux bash --noprofile --rcfile "$BASHRC_FILE" -i </dev/null 2>/dev/null | grep -c STARSHIP_RAN)" "0"
rm "$BIN/starship"

# ------------------------------------------------------------
# Updating
# ------------------------------------------------------------

clean
printf '%s\n' "$THEIRS" >"$BASHRC_FILE"
SETUP_MODE=update
install_bash_setup >/dev/null
is "first update: adds the lines" "$(grep -cxF "$BASHRC_START" "$BASHRC_FILE")" "2"
missing "first update: no note" "$NOTES"
install_bash_setup >/dev/null
is "second update: still one set" "$(grep -cxF "$BASHRC_START" "$BASHRC_FILE")" "2"
printf 'alias mine=1\n' >>"$BASHRC_FILE"
install_bash_setup >/dev/null
is "update: a new line of theirs stays" "$(grep -c 'alias mine=1' "$BASHRC_FILE")" "1"
is "update: attach is last again" "$(tail -n 2 "$BASHRC_FILE" | head -n 1)" '[[ ! ${BLE_VERSION-} ]] || ble-attach'
remove_bashrc_lines
before="$(cat "$BASHRC_FILE")"
install_bash_setup >/dev/null
is "taken out on purpose: stays out" "$(cat "$BASHRC_FILE")" "$before"
missing "taken out on purpose: says nothing" "$NOTES"
SETUP_MODE=install
install_bash_setup >/dev/null
is "a new install puts them back" "$(grep -cxF "$BASHRC_START" "$BASHRC_FILE")" "2"

# ------------------------------------------------------------
# Uninstalling
# ------------------------------------------------------------

clean
printf '%s\n' "$THEIRS" >"$BASHRC_FILE"
install_bash_setup >/dev/null
remove_bash_setup
is "uninstall: exactly what they had" "$(cat "$BASHRC_FILE")" "$THEIRS"

clean
install_bash_setup >/dev/null
remove_bash_setup
missing "no .bashrc before: none after" "$BASHRC_FILE"

clean
printf 'no newline at the end' >"$BASHRC_FILE"
install_bash_setup >/dev/null
is "no last newline: nothing gets joined" "$(grep -cx 'no newline at the end' "$BASHRC_FILE")" "1"
remove_bash_setup
is "no last newline: comes back the same" "$(cat "$BASHRC_FILE")" "no newline at the end"

clean
printf '%s\n' "$THEIRS" >"$TEST_DIR/dotfile"
ln -s "$TEST_DIR/dotfile" "$BASHRC_FILE"
install_bash_setup >/dev/null
is "a linked .bashrc stays a link" "$([ -L "$BASHRC_FILE" ] && echo yes)" "yes"
is "the real file gets the lines" "$(grep -cxF "$BASHRC_START" "$TEST_DIR/dotfile")" "2"
remove_bash_setup
rm -f "$BASHRC_FILE"

# ------------------------------------------------------------
# The configs
# ------------------------------------------------------------

if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' 2>/dev/null; then
    is "starship config is valid" "$(python3 -I -c 'import tomllib,sys; d=tomllib.load(open(sys.argv[1],"rb")); print(d["format"], d["add_newline"])' "$SHELL_SOURCE_DIR/starship.toml")" \
        '$directory$git_branch$git_commit$git_status$character False'
else
    skip "starship config: needs Python 3.11 or newer to read it"
fi
is "the prompt has no line break" "$(grep -c 'line_break' "$SHELL_SOURCE_DIR/starship.toml")" "0"
is "blerc is valid Bash" "$(bash -n "$SHELL_SOURCE_DIR/bash/blerc" 2>&1; echo $?)" "0"

finish
