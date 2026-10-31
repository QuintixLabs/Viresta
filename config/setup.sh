#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
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
    local wallpaper_path="$HOME/Pictures/Wallpapers/Viresta/01. Viresta.jpg"

    [ -f "$wallpaper_path" ] || {
        printf 'Viresta wallpaper not found at %s\n' "$wallpaper_path" >&2
        return 1
    }

    mkdir -p "$HOME/.config/autostart-scripts"
    cat <<'EOF' > "$HOME/.config/autostart-scripts/set_wallpaper.sh"
#!/usr/bin/env bash
wallpaper_path="$HOME/Pictures/Wallpapers/Viresta/01. Viresta.jpg"
script_file="$HOME/.config/autostart-scripts/set_wallpaper.sh"
desktop_wrapper="$HOME/.config/autostart/set_wallpaper.sh.desktop"

if [ -f "$wallpaper_path" ] && command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0; i<allDesktops.length;i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
            d.writeConfig('Image', 'file://${wallpaper_path}');
        }
    "
    # Delete both the script and KDE's auto-generated desktop wrapper
    rm -f "$script_file"
    rm -f "$desktop_wrapper"
fi
EOF
    chmod +x "$HOME/.config/autostart-scripts/set_wallpaper.sh"

    printf 'Configured Plasma wallpaper one-time autostart script\n'
}

install_vicinae() {
    local source_root="$SCRIPT_DIR/vicinae"
    local source target filename installed_name

    [ -d "$source_root" ] || return 0

    if [ -f "$source_root/settings.json" ]; then
        install -Dm644 \
            "$source_root/settings.json" \
            "$CONFIG_DIR/vicinae/settings.json"
        printf 'Installed %s\n' "$CONFIG_DIR/vicinae/settings.json"
    fi

    if [ -d "$source_root/applications" ]; then
        while IFS= read -r -d '' source; do
            filename="$(basename "$source")"
            case "$filename" in
                viresta-*) installed_name="$filename" ;;
                *) installed_name="viresta-$filename" ;;
            esac
            target="$HOME/.local/share/applications/$installed_name"
            rm -f "$HOME/.local/share/applications/viresta-viresta-$filename"
            install -Dm644 "$source" "$target"
            printf 'Installed %s\n' "$target"
        done < <(find "$source_root/applications" -maxdepth 1 -type f -name '*.desktop' -print0)
    fi
}

install_wallpapers() {
    local source_root="$REPO_DIR/wallpapers"
    local source target

    [ -d "$source_root" ] || return 0

    if [ -f "$source_root/rename_wallpapers.py" ]; then
        install -Dm644 \
            "$source_root/rename_wallpapers.py" \
            "$HOME/Pictures/Wallpapers/rename_wallpapers.py"
        printf 'Installed %s\n' "$HOME/Pictures/Wallpapers/rename_wallpapers.py"
    fi

    if [ -d "$source_root/Viresta" ]; then
        install_tree \
            "$source_root/Viresta" \
            "$HOME/Pictures/Wallpapers/Viresta" \
            1 \
            0
    fi
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

        if [ "$category_name" = "vicinae" ]; then
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
        fi

        [ -d "$source_root" ] || continue
        install_tree "$source_root" "$target" "$minimum_depth" "$strip_category"
    done < <(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

    install_vicinae
    install_wallpapers
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
