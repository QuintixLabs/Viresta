#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"

usage() {
    cat <<'EOF'
Usage: setup.sh

Install the Viresta KDE configuration files into ~/.config.
EOF
}

install_configs() {
    local source target

    mkdir -p "$CONFIG_DIR"

    while IFS= read -r -d '' source; do
        target="$CONFIG_DIR/$(basename "$source")"
        install -m 0644 "$source" "$target"
        printf 'Installed %s\n' "$target"
    done < <(find "$SCRIPT_DIR" -mindepth 2 -type f -print0)
}

case "${1:-}" in
    '')
        install_configs
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
