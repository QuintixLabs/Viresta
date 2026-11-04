#!/usr/bin/env bash

# install-pkgs.sh
# Installs only the packages newly added to the lists, for update.sh.

# ------------------------------------------------------------
# New packages
# ------------------------------------------------------------

new_packages() {
    [ -f "$KNOWN_PACKAGES_FILE" ] || return 0
    local list pkg

    for list in "$@"; do
        while IFS= read -r pkg; do
            if ! grep -qxF "$pkg" "$KNOWN_PACKAGES_FILE" && ! is_installed "$pkg"; then
                printf '%s\n' "$pkg"
            fi
        done < <(read_package_list "$SCRIPT_DIR/packages/$list.txt")
    done
}

# ------------------------------------------------------------
# Installing
# ------------------------------------------------------------

# A package can need a newer system than this one, and only then is a full update
# worth asking about. Refreshing the package list alone would break Arch.
install_new_repo_packages() {
    local -a pkgs=()
    local update_system=1

    mapfile -t pkgs < <(new_packages base kde apps)
    [ "${#pkgs[@]}" -gt 0 ] || return 0

    prepare_pacman_conf
    run_pacman -S --needed --noconfirm "${pkgs[@]}" && return 0

    spinner_stop
    printf '\n'
    if ask_yes_no "New packages (${pkgs[*]}) may need a full system update first. Run it now?" n; then
        update_system=0
    fi
    spinner_start

    if [ "$update_system" -ne 0 ] || ! run_pacman -Syu --noconfirm \
        || ! run_pacman -S --needed --noconfirm "${pkgs[@]}"; then
        failure "Could not install: ${pkgs[*]}"
    fi
}

install_new_aur_packages() {
    local -a pkgs=()
    local pkg

    mapfile -t pkgs < <(new_packages aur)
    [ "${#pkgs[@]}" -gt 0 ] || return 0

    if ! command -v paru >/dev/null 2>&1; then
        warn "paru is not installed, so these were skipped: ${pkgs[*]}"
        return 0
    fi

    set_build_jobs
    for pkg in "${pkgs[@]}"; do
        aur_install_one "$pkg" || true
    done
}

# ------------------------------------------------------------
# Package record
# ------------------------------------------------------------

# A new package that could not be installed stays unknown, so the next update tries it
# again. The first update after an install with no record only starts the record.
remember_packages() {
    local pkg

    if [ ! -f "$KNOWN_PACKAGES_FILE" ]; then
        save_known_packages
        return 0
    fi

    while IFS= read -r pkg; do
        if is_installed "$pkg"; then
            printf '%s\n' "$pkg" >>"$KNOWN_PACKAGES_FILE"
        fi
    done < <(listed_packages)
    sort -u -o "$KNOWN_PACKAGES_FILE" "$KNOWN_PACKAGES_FILE"
}
