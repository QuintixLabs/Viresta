#!/usr/bin/env bash

# fastfetch.sh
# Installs the fastfetch config and sets the logo for the starting theme.

# The config always reads logo.png, and viresta-theme-sync replaces that file when the
# theme changes. The config gets the full path, so it works for any user.
install_fastfetch() {
    local source_dir="$CONFIG_SOURCE_DIR/fastfetch"
    local temp_file

    install_tree "$source_dir/pngs" "$FASTFETCH_DIR/pngs"

    temp_file="$(mktemp)"
    sed "s|\"source\": .*|\"source\": \"$FASTFETCH_DIR/logo.png\",|" "$source_dir/config.jsonc" >"$temp_file"
    install_shared_file "$temp_file" "$FASTFETCH_DIR/config.jsonc"
    rm -f "$temp_file"
}

install_fastfetch_logo() {
    install -m644 "$FASTFETCH_DIR/pngs/viresta-dark.png" "$FASTFETCH_DIR/logo.png"
    printf 'Configured the fastfetch logo\n'
}
