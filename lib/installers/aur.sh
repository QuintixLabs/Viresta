#!/usr/bin/env bash

# aur.sh
# Installs paru and AUR packages.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

AUR_LOG_DIR="${AUR_LOG_DIR:-$HOME/.local/state/viresta}"

# ------------------------------------------------------------
# AUR packages
# ------------------------------------------------------------

_aur_install_one() {
    local pkg="$1"

    if is_installed "$pkg"; then
        ok "$pkg already installed"
        return 0
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would build $pkg from the AUR"
        return 0
    fi

    if ! command -v paru >/dev/null 2>&1; then
        failure "$pkg: paru is not available"
        return 1
    fi

    mkdir -p "$AUR_LOG_DIR"
    local log="$AUR_LOG_DIR/aur-$pkg.log"
    info "$pkg: building from the AUR (this may take a while)"

    if paru -S --needed --noconfirm "$pkg" </dev/null >"$log" 2>&1; then
        ok "$pkg installed"
        return 0
    fi

    failure "$pkg: install failed - see $log"
    return 1
}

install_aur() {
    local file="$SCRIPT_DIR/packages/aur.txt"

    if [ ! -f "$file" ]; then
        info "No AUR package list found"
        return 0
    fi

    local line pkg
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -n "$line" ] || continue

        pkg="$line"
        if [ "$pkg" = "vicinae-bin" ] && [ "${INSTALL_VICINAE:-1}" -eq 0 ]; then
            continue
        fi
        _aur_install_one "$pkg" || true
    done <"$file"

    return 0
}

# ------------------------------------------------------------
# Paru
# ------------------------------------------------------------

bootstrap_paru() {
    if command -v paru >/dev/null 2>&1; then
        ok "paru already installed"
        return 0
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would build paru from the AUR"
        return 0
    fi

    mkdir -p "$AUR_LOG_DIR"
    local log="$AUR_LOG_DIR/aur-paru.log"
    local tmp
    tmp="$(mktemp -d)"
    info "paru: building from the AUR (this may take a while)"

    if (
        cd "$tmp" || exit 1
        git clone https://aur.archlinux.org/paru.git
        cd paru || exit 1
        makepkg -si --noconfirm
    ) </dev/null >"$log" 2>&1; then
        rm -rf "$tmp"
        ok "paru installed"
        return 0
    fi

    rm -rf "$tmp"
    failure "paru: build failed - see $log"
    return 1
}
