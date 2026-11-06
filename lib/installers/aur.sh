#!/usr/bin/env bash

# aur.sh
# Installs paru and AUR packages.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

AUR_LOG_DIR="${AUR_LOG_DIR:-$HOME/.local/state/viresta}"

# ------------------------------------------------------------
# Build speed
# ------------------------------------------------------------

# make uses one core unless told otherwise. This only lasts for this install, and a
# MAKEFLAGS set in makepkg.conf still wins. Allowing 1 GB per job stops machines with
# little RAM running out while compiling.
set_build_jobs() {
    local jobs ram_gb

    if [ -n "${MAKEFLAGS:-}" ]; then
        return 0
    fi

    jobs="$(nproc)"
    ram_gb="$(awk '/^MemTotal:/ { print int($2 / 1024 / 1024) }' /proc/meminfo)"
    if [ "$ram_gb" -lt "$jobs" ]; then
        jobs="$ram_gb"
    fi
    if [ "$jobs" -lt 1 ]; then
        jobs=1
    fi

    export MAKEFLAGS="-j$jobs"
}

# ------------------------------------------------------------
# AUR packages
# ------------------------------------------------------------

aur_install_one() {
    local pkg="$1" flags="${2:-}"

    if is_installed "$pkg"; then
        ok "$pkg already installed"
        return 0
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would build $pkg from the AUR"
        return 0
    fi

    if [ -z "$flags" ] && ! command -v paru >/dev/null 2>&1; then
        failure "$pkg: paru is not available"
        return 1
    fi

    mkdir -p "$AUR_LOG_DIR"
    local log="$AUR_LOG_DIR/aur-$pkg.log"
    info "$pkg: building from the AUR (this may take a while)"

    if {
        if [ -n "$flags" ]; then
            aur_build_with_flags "$pkg" "$flags"
        else
            paru -S --needed --noconfirm "$pkg"
        fi
    } </dev/null >"$log" 2>&1; then
        ok "$pkg installed"
        return 0
    fi

    failure "$pkg: install failed - see $log"
    return 1
}

# paru cannot add flags to a build, so this downloads the package and builds it the way
# bootstrap_paru does. It stops if there is no ./configure to add them to, so a change
# to the package shows up as a failure and not as a build without the flags.
aur_build_with_flags() {
    local pkg="$1" flags="$2"
    local tmp status=0

    tmp="$(mktemp -d)"
    (
        cd "$tmp" || exit 1
        git clone "https://aur.archlinux.org/$pkg.git" || exit 1
        cd "$pkg" || exit 1
        if ! grep -q '\./configure' PKGBUILD; then
            printf 'No ./configure in the PKGBUILD to add %s to\n' "$flags"
            exit 1
        fi
        sed -i "s|\./configure|& $flags|" PKGBUILD
        makepkg -si --noconfirm
    ) || status=$?

    rm -rf "$tmp"
    return "$status"
}

install_aur() {
    local file="$SCRIPT_DIR/packages/apps/aur.txt"

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
        if [ "$pkg" = "vicinae-bin" ] && [ "${USE_VICINAE:-1}" -eq 0 ]; then
            continue
        fi
        aur_install_one "$pkg" || true
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
