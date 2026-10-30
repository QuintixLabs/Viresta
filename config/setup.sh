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

configure_wallpaper() {
    local config_file="$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc"
    local wallpaper="$HOME/Pictures/Wallpapers/Viresta/01. Viresta.jpg"
    local image_url="file://${wallpaper}"

    [ -f "$config_file" ] || return 0

    image_url="${image_url// /%20}"
    sed -i "s|^Image=file:///VIRESTA_WALLPAPER$|Image=$image_url|" "$config_file"
}

install_configs() {
    local category category_name source_root target minimum_depth strip_category

    while IFS= read -r -d '' category; do
        category_name="$(basename "$category")"

        if [ "$category_name" = "vscodium" ]; then
            if [ -f "$category/settings.json" ]; then
                install -Dm644 \
                    "$category/settings.json" \
                    "$CONFIG_DIR/VSCodium/User/settings.json"
                printf 'Installed %s\n' "$CONFIG_DIR/VSCodium/User/settings.json"
            fi
            continue
        fi

        source_root="$category"
        target="$CONFIG_DIR/$category_name"
        minimum_depth=1
        strip_category=0

        if [ "$category_name" = "kde" ]; then
            target="$CONFIG_DIR"
            minimum_depth=2
            strip_category=1
        elif [ "$category_name" = "systemd" ]; then
            target="$CONFIG_DIR/systemd/user"
        elif [ "$category_name" = "wallpapers" ]; then
            target="$HOME/Pictures/Wallpapers/Viresta"
            if [ -f "$category/rename_wallpapers.py" ]; then
                install -Dm644 \
                    "$category/rename_wallpapers.py" \
                    "$HOME/Pictures/Wallpapers/rename_wallpapers.py"
                printf 'Installed %s\n' "$HOME/Pictures/Wallpapers/rename_wallpapers.py"
            fi
            source_root="$category/Viresta"
        fi

        [ -d "$source_root" ] || continue
        install_tree "$source_root" "$target" "$minimum_depth" "$strip_category"
    done < <(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

    configure_wallpaper
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
