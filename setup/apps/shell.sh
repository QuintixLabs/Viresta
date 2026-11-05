#!/usr/bin/env bash

# shell.sh
# Sets up the prompt and autocomplete for Bash and Fish. Other shells are left alone.

# ------------------------------------------------------------
# Lines for ~/.bashrc
# ------------------------------------------------------------

# ble.sh has to load first and attach last, so there is a part for each end of the file.
# Each line checks for what it needs, so ~/.bashrc still works without the packages. The
# plain text login is left out, since it has no Nerd Font and is where uninstall.sh runs.
bashrc_top_lines() {
    printf '%s\n' \
        "$BASHRC_START" \
        "[[ \$- == *i* && \$TERM != linux && -f $BLESH_SCRIPT ]] && source -- $BLESH_SCRIPT --attach=none" \
        "$BASHRC_END"
}

bashrc_bottom_lines() {
    printf '%s\n' \
        "$BASHRC_START" \
        "if [[ \$- == *i* && \$TERM != linux ]] && command -v starship >/dev/null; then eval \"\$(starship init bash)\"; fi" \
        "[[ ! \${BLE_VERSION-} ]] || ble-attach" \
        "$BASHRC_END"
}

# Run again on every update, so the lines can change. Anything else in the file stays.
write_bashrc_lines() {
    local temp_file

    remove_bashrc_lines

    temp_file="$(mktemp)"
    {
        bashrc_top_lines
        if [ -f "$BASHRC_FILE" ]; then
            awk 1 "$BASHRC_FILE"
        fi
        bashrc_bottom_lines
    } >"$temp_file"
    cat "$temp_file" >"$BASHRC_FILE"
    rm -f "$temp_file"
}

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

# An update adds the lines once. If they are gone after that, the user took them out on
# purpose, so they stay out.
install_bash_setup() {
    install_shared_file "$SHELL_SOURCE_DIR/starship.toml" "$CONFIG_DIR/starship.toml"
    install_shared_file "$SHELL_SOURCE_DIR/bash/blerc" "$HOME/.blerc"

    if [ "$SETUP_MODE" = "update" ] && [ -e "$BASHRC_ADDED_FILE" ] && ! bashrc_has_viresta_lines; then
        return 0
    fi

    write_bashrc_lines
    mkdir -p "$(dirname "$BASHRC_ADDED_FILE")"
    : >"$BASHRC_ADDED_FILE"
    printf 'Added the Viresta lines to %s\n' "$BASHRC_FILE"
}

# Fish loads everything in conf.d by itself, so the user's config.fish is not touched.
install_fish_setup() {
    install_shared_file "$SHELL_SOURCE_DIR/starship.toml" "$CONFIG_DIR/starship.toml"
    install_shared_file "$SHELL_SOURCE_DIR/fish/viresta.fish" "$CONFIG_DIR/fish/conf.d/viresta.fish"
}

install_shell_setup() {
    case "$(login_shell)" in
        bash) install_bash_setup ;;
        fish) install_fish_setup ;;
    esac
}
