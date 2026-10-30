#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"

usage() {
    cat <<'EOF'
Usage: setup.sh

Install the Viresta configuration files into ~/.config.
EOF
}

install_tree() {
    local source_root="$1"
    local target_root="$2"
    local minimum_depth="$3"
    local strip_category="$4"
    local source relative target

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        if [ "$strip_category" -eq 1 ]; then
            relative="${relative#*/}"
        fi
        target="$target_root/$relative"
        install -Dm644 "$source" "$target"
        printf 'Installed %s\n' "$target"
    done < <(find "$source_root" -mindepth "$minimum_depth" -type f -print0)
}

install_configs() {
    local category target minimum_depth strip_category

    while IFS= read -r -d '' category; do
        target="$CONFIG_DIR"
        minimum_depth=2
        strip_category=1

        if [ "$(basename "$category")" = "systemd" ]; then
            target="$CONFIG_DIR/systemd/user"
            minimum_depth=1
            strip_category=0
        fi

        install_tree "$category" "$target" "$minimum_depth" "$strip_category"
    done < <(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
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
