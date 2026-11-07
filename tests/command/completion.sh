#!/usr/bin/env bash

# completion.sh
# Tests Tab completion for the viresta command, in Bash and in Fish.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

copy_viresta
mark_installed
cp "$VIRESTA/config/shell/commands/viresta" "$BIN/viresta"
chmod +x "$BIN/viresta"

# ------------------------------------------------------------
# Bash
# ------------------------------------------------------------

# complete_bash <words...>: what Tab offers for the last word.
complete_bash() {
    bash -c '
        source "$1"; shift
        COMP_WORDS=("$@"); COMP_CWORD=$(($# - 1))
        _viresta
        printf "%s\n" "${COMPREPLY[@]}" | sort | paste -sd" "
    ' _ "$VIRESTA/config/shell/bash/completions/viresta.bash" "$@"
}

is "bash: the commands" "$(complete_bash viresta '')" "--help --version install uninstall update"
is "bash: update's options" "$(complete_bash viresta update --)" "--check --dev --help --logs --notifications-off --notifications-on --verbose"

# ------------------------------------------------------------
# Fish
# ------------------------------------------------------------

if command -v fish >/dev/null 2>&1; then
    complete_fish() {
        fish -c "source '$VIRESTA/config/shell/fish/completions/viresta.fish'; complete -C '$1'" | cut -f1 | sort | paste -sd" "
    }
    is "fish: the commands" "$(complete_fish 'viresta ')" "install uninstall update"
    is "fish: update's options" "$(complete_fish 'viresta update --')" "--check --dev --help --logs --notifications-off --notifications-on --verbose"
else
    skip "fish: Fish is not installed"
fi

finish
