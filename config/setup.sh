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
    done < <(find "$source_root" -mindepth "$minimum_depth" \( -type f -o -type l \) -print0)
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

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

install_vicinae_themes() {
    local source_root="$SCRIPT_DIR/vicinae/themes"
    local source relative target

    [ -d "$source_root" ] || return 0

    if ! command -v sudo >/dev/null 2>&1; then
        printf 'sudo is required to install Vicinae themes\n' >&2
        return 1
    fi

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        target="/usr/share/vicinae/themes/$relative"
        sudo install -Dm644 "$source" "$target"
        printf 'Installed %s\n' "$target"
    done < <(find "$source_root" -type f -print0)
}

install_icon_themes() {
    local archive="$SCRIPT_DIR/icons/yet-another-monochrome-icon-set.tar.gz"
    local source_root="$SCRIPT_DIR/icons/YAMIS"
    local source target temp_dir nested_tar inner_dir extracted_theme

    if [ -f "$archive" ]; then
        command -v tar >/dev/null 2>&1 || {
            printf 'tar is required to install the YAMIS icon theme\n' >&2
            return 1
        }

        temp_dir="$(mktemp -d)"
        if ! tar -xzf "$archive" -C "$temp_dir"; then
            rm -rf "$temp_dir"
            printf 'Could not extract YAMIS icon theme archive\n' >&2
            return 1
        fi

        nested_tar="$(find "$temp_dir" -type f -name '*.tar' -print -quit)"
        if [ -n "$nested_tar" ]; then
            inner_dir="$temp_dir/inner"
            mkdir -p "$inner_dir"
            if ! tar -xf "$nested_tar" -C "$inner_dir"; then
                rm -rf "$temp_dir"
                printf 'Could not extract the inner YAMIS icon theme archive\n' >&2
                return 1
            fi
        fi

        extracted_theme="$(find "$temp_dir" -type d -name YAMIS -print -quit)"
        if [ -n "$extracted_theme" ]; then
            source_root="$extracted_theme"
        fi
    fi

    [ -d "$source_root" ] || {
        [ -n "${temp_dir:-}" ] && rm -rf "$temp_dir"
        return 0
    }

    install_tree "$source_root" "$HOME/.local/share/icons/YAMIS" 1 0

    [ -n "${temp_dir:-}" ] && rm -rf "$temp_dir"

    # Fix Dolphin's KDE application icon name
    local yamis_apps="$HOME/.local/share/icons/YAMIS/apps/scalable"

    if [ -f "$yamis_apps/dolphin.svg" ]; then
        ln -sfn dolphin.svg "$yamis_apps/org.kde.dolphin.svg"
        printf 'Created Dolphin icon alias\n'
    fi
}

apply_panel_colorizer_preset() {
    local preset="$CONFIG_DIR/panel-colorizer/presets/Transparent"

    [ -f "$preset/settings.json" ] || {
        printf 'Panel Colorizer preset not found: %s\n' "$preset" >&2
        return 0
    }

    command -v dbus-send >/dev/null 2>&1 || {
        printf 'dbus-send is unavailable, skipping Panel Colorizer preset\n' >&2
        return 0
    }

    if dbus-send --session --type=signal \
        /preset \
        luisbocanegra.panel.colorizer.all.preset \
        string:"$preset/"; then
        printf 'Applied Panel Colorizer preset: Transparent\n'
    else
        printf 'Could not apply Panel Colorizer preset: Transparent\n' >&2
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

install_kde_configs() {
    local source_root="$SCRIPT_DIR/kde"
    local excluded_root="$source_root/appearance/color-schemes"
    local source relative target

    [ -d "$source_root" ] || return 0

    while IFS= read -r -d '' source; do
        relative="${source#"$source_root/"}"
        relative="${relative#*/}"
        target="$CONFIG_DIR/$relative"
        install -Dm644 "$source" "$target"
        printf 'Installed %s\n' "$target"
    done < <(
        find "$source_root" -mindepth 2 \
            \( -type f -o -type l \) \
            ! -path "$excluded_root/*" \
            -print0
    )
}

install_color_schemes() {
    local source_root="$SCRIPT_DIR/kde/appearance/color-schemes"

    [ -d "$source_root" ] || return 0
    install_tree "$source_root" "$HOME/.local/share/color-schemes" 1 0
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

        if [ "$category_name" = "kitty" ]; then
            if [ -f "$category/kitty.conf" ]; then
                install -Dm644 \
                    "$category/kitty.conf" \
                    "$CONFIG_DIR/kitty/kitty.conf"
                printf 'Installed %s\n' "$CONFIG_DIR/kitty/kitty.conf"
            fi
            continue
        fi

        if [ "$category_name" = "kde" ]; then
            install_kde_configs
            continue
        fi

        source_root="$category"
        target="$CONFIG_DIR/$category_name"
        minimum_depth=1
        strip_category=0

        if [ "$category_name" = "systemd" ]; then
            target="$CONFIG_DIR/systemd/user"
        elif [ "$category_name" = "cursors" ]; then
            target="$HOME/.local/share/icons"
        fi

        [ -d "$source_root" ] || continue
        install_tree "$source_root" "$target" "$minimum_depth" "$strip_category"
    done < <(find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

    install_vicinae
    install_vicinae_themes
    install_icon_themes
    install_wallpapers
    install_color_schemes
    apply_panel_colorizer_preset
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
