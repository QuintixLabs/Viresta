#!/usr/bin/env bash

# viresta.sh
# Tests the viresta command: running the right script from anywhere, passing options
# along, its help and version, a moved folder, and installing and removing it.

source "$(dirname "$0")/../shared/helpers.sh"

# ------------------------------------------------------------
# Setup
# ------------------------------------------------------------

# A folder name with a space, since the path is saved and read back.
VIRESTA="$TEST_DIR/My Viresta"
copy_viresta
echo 1.1.0 >"$VIRESTA/VERSION"

# sudo writes into a fake system folder instead of the real /usr.
cat >"$BIN/sudo" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do case "\$a" in /usr/*) args+=("$TEST_DIR/root\$a") ;; *) args+=("\$a") ;; esac; done
"\${args[@]}"
EOF
chmod +x "$BIN/sudo"
(
    SETUP_DIR="$VIRESTA/setup"
    source "$SETUP_DIR/shared/variables.sh"
    source "$SETUP_DIR/shared/tracking.sh"
    source "$SETUP_DIR/viresta/command.sh"
    install_viresta_command >/dev/null
)
COMMAND="$TEST_DIR/root/usr/local/bin/viresta"
STATE="$HOME/.local/state/viresta"

# ------------------------------------------------------------
# Installing
# ------------------------------------------------------------

is "installed and runnable" "$([ -x "$COMMAND" ] && echo yes)" "yes"
is "folder saved, with its space" "$(cat "$STATE/folder")" "$VIRESTA"
is "on the uninstall list" "$(grep -c -x /usr/local/bin/viresta "$STATE/installed-files")" "1"
exists "Bash completion installed" "$TEST_DIR/root/usr/share/bash-completion/completions/viresta"
exists "Fish completion installed" "$TEST_DIR/root/usr/share/fish/vendor_completions.d/viresta.fish"

# ------------------------------------------------------------
# Running the scripts
# ------------------------------------------------------------

# Stand-ins that only say how they were run, from somewhere else than the folder.
for script in install update uninstall; do
    mv "$VIRESTA/$script.sh" "$VIRESTA/$script.sh.real"
    printf '#!/usr/bin/env bash\necho "RAN %s from=$(pwd) dir=$(cd "$(dirname "$0")" && pwd) as=$VIRESTA_RUN_AS args=$*"\n' \
        "$script" >"$VIRESTA/$script.sh"
done
cd "$TEST_DIR" || exit 1
is "update" "$(bash "$COMMAND" update)" "RAN update from=$TEST_DIR dir=$VIRESTA as=viresta update args="
is "update --dev" "$(bash "$COMMAND" update --dev --verbose)" "RAN update from=$TEST_DIR dir=$VIRESTA as=viresta update args=--dev --verbose"
is "install" "$(bash "$COMMAND" install)" "RAN install from=$TEST_DIR dir=$VIRESTA as=viresta install args="
is "uninstall --dry-run" "$(bash "$COMMAND" uninstall --dry-run)" "RAN uninstall from=$TEST_DIR dir=$VIRESTA as=viresta uninstall args=--dry-run"
is "options with spaces are kept" "$(bash "$COMMAND" update 'a b' | sed 's/.*args=//')" "a b"
for script in install update uninstall; do
    mv "$VIRESTA/$script.sh.real" "$VIRESTA/$script.sh"
done

# ------------------------------------------------------------
# Help and version
# ------------------------------------------------------------

is "version" "$(bash "$COMMAND" --version)" "Viresta 1.1.0"
is "version, short" "$(bash "$COMMAND" -v)" "Viresta 1.1.0"
is "help" "$(bash "$COMMAND" --help | grep -c 'viresta <command>')" "2"
is "no command shows the help" "$(bash "$COMMAND"; echo "exit=$?")" "$(bash "$COMMAND" --help; echo "exit=0")"
is "an unknown command" "$(bash "$COMMAND" updat 2>&1 >/dev/null | head -n 1)" "Unknown command: updat"
is "an unknown command fails" "$(bash "$COMMAND" updat >/dev/null 2>&1; echo $?)" "2"
is "no colors through a pipe" "$(bash "$COMMAND" --help | grep -c $'\e')" "0"
colored="$(script -qec "bash '$COMMAND' --help" /dev/null)"
is "colors in a terminal" "$(grep -c $'\e\[38;5;42minstall' <<<"$colored")" "1"
is "the script's own help goes through" "$(bash "$COMMAND" update --help | strip_colors | grep -c -- '--notifications-off')" "1"
for script in install update uninstall; do
    is "$script help names the command" "$(bash "$COMMAND" "$script" --help | strip_colors | grep '^Usage:')" "Usage: viresta $script [options]"
    is "$script help from the folder" "$(bash "$VIRESTA/$script.sh" --help | strip_colors | grep '^Usage:')" "Usage: ./$script.sh [options]"
done

# ------------------------------------------------------------
# A moved folder
# ------------------------------------------------------------

mv "$VIRESTA" "$TEST_DIR/Moved"
for script in update install uninstall; do
    is "moved folder: $script names its script" "$(bash "$COMMAND" "$script" 2>&1)" \
        "Can't find the Viresta folder. If you moved it, run ./$script.sh from its new place."
done
is "moved folder: fails" "$(bash "$COMMAND" update >/dev/null 2>&1; echo $?)" "1"
is "moved folder: help still works" "$(bash "$COMMAND" --help | grep -c 'Commands:')" "1"
mv "$TEST_DIR/Moved" "$VIRESTA"

# ------------------------------------------------------------
# Uninstalling
# ------------------------------------------------------------

safe() {
    (
        SETUP_DIR="$VIRESTA/setup"
        SCRIPT_DIR="$VIRESTA"
        source "$SETUP_DIR/shared/variables.sh"
        source "$VIRESTA/lib/uninstall/files.sh"
        if is_safe_to_remove "$1"; then echo yes; else echo no; fi
    )
}
is "uninstall may remove the command" "$(safe /usr/local/bin/viresta)" "yes"
is "but not its folder" "$(safe /usr/local/bin)" "no"
is "or another command" "$(safe /usr/local/bin/other)" "no"

finish
