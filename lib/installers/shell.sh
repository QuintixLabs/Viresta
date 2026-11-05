#!/usr/bin/env bash

# shell.sh
# Installs what the user's shell needs for its prompt and autocomplete.

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------

install_shell_packages() {
    local shell listed pkg

    shell="$(login_shell)"

    while read -r listed pkg; do
        if [ "$listed" != "$shell" ] || is_installed "$pkg"; then
            continue
        fi

        if [ "$(pkg_source "$pkg")" != "repo" ]; then
            aur_install_one "$pkg" || true
        elif [ "${DRY_RUN:-0}" -eq 1 ]; then
            info "Would install $pkg (repository)"
        else
            info "$pkg: installing"
            run_pacman -S --needed --noconfirm "$pkg" || failure "$pkg: install failed - see $LOG_FILE"
        fi
    done < <(read_package_list "$SCRIPT_DIR/packages/shell.txt")

    return 0
}
