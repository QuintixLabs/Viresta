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

install_new_repo_packages() {
    local -a pkgs=()

    mapfile -t pkgs < <(new_packages system/base system/kde apps/pacman)
    install_or_ask "${pkgs[@]}"
}

# A package can need a newer system than this one, and only then is a full update
# worth asking about. Refreshing the package list alone would break Arch. A repository
# that was just turned on, like multilib, also has no package list until then.
install_or_ask() {
    local -a pkgs=("$@")
    local update_system=1

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

# The 32-bit drivers someone does not have yet. Only when drivers are ticked in the
# install menu, and one they removed on purpose stays removed. Everything else in
# drivers.txt needs install.sh, which sets up what goes with it, like the NVIDIA boot
# image. The Gaming row is never added by an update.
install_new_32bit_drivers() {
    local -a repo=() aur=()
    local pkg

    [ "${USE_DRIVERS:-1}" -eq 1 ] || return 0
    detect_hardware

    while IFS= read -r pkg; do
        if grep -qxF "$pkg" "$KNOWN_PACKAGES_FILE" 2>/dev/null; then
            continue
        elif [ "$(pkg_source "$pkg")" = "repo" ]; then
            repo+=("$pkg")
        else
            aur+=("$pkg")
        fi
    done < <(missing_32bit_drivers)
    [ "$((${#repo[@]} + ${#aur[@]}))" -gt 0 ] || return 0

    enable_multilib
    install_or_ask "${repo[@]}"
    for pkg in "${aur[@]}"; do
        aur_install_one "$pkg" || true
    done
}

install_new_aur_packages() {
    local -a pkgs=()
    local pkg

    mapfile -t pkgs < <(new_packages apps/aur)
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
# Apps Viresta no longer includes
# ------------------------------------------------------------

# What the user said about them. Saved only once the update is done, so an update that
# stops, like at the password, asks again next time.
DROPPED_REMOVE=()
DROPPED_KEEP=()
DROPPED_REMOVED=()

# app_name <package>: the short name from its menu entry, like "Music Player". Fonts,
# libraries and tools have none, so they are never asked about.
app_name() {
    local file name

    while IFS= read -r file; do
        case "$file" in */share/applications/*.desktop) ;; *) continue ;; esac
        name="$(sed -n 's/^GenericName=//p' "$file" 2>/dev/null | head -n 1)"
        [ -n "$name" ] || name="$(sed -n 's/^Name=//p' "$file" 2>/dev/null | head -n 1)"
        if [ -n "$name" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(pacman -Qlq "$1" 2>/dev/null)
    return 1
}

# Each app Viresta once listed and does not anymore, as "<package><tab><name>". Left out:
# what is not installed, what was there before Viresta, and what was kept before.
dropped_apps() {
    local listed pkg real name

    [ -f "$KNOWN_PACKAGES_FILE" ] || return 0
    listed="$(listed_packages | sort -u)"

    while IFS= read -r pkg; do
        grep -qxF "$pkg" <<<"$listed" && continue
        real="$(pacman -Qq "$pkg" 2>/dev/null)" || continue
        grep -qxF "$real" "$PACKAGES_BEFORE_FILE" 2>/dev/null && continue
        grep -qxF "$real" "$KEPT_APPS_FILE" 2>/dev/null && continue
        name="$(app_name "$real")" || continue
        printf '%s\t%s\n' "$real" "$name"
    done <"$KNOWN_PACKAGES_FILE"
}

# One question for all of them, before the password. No is the default, and without a
# terminal nothing is asked or remembered, so the next update in one asks.
ask_about_dropped_apps() {
    local -a rows=() pkgs=()
    local row pkg name

    [ -t 0 ] && [ -t 1 ] || return 0
    mapfile -t rows < <(dropped_apps)
    [ "${#rows[@]}" -gt 0 ] || return 0

    [ -z "${VIRESTA_PULLED:-}" ] || printf '\n'
    emit "$C_WARN" "! Viresta no longer includes these apps:"
    for row in "${rows[@]}"; do
        pkg="${row%%$'\t'*}"
        name="${row#*$'\t'}"
        pkgs+=("$pkg")
        # The package is already on the line, so "fooyin Music Player" becomes "Music
        # Player", and a name that only repeats it is left out.
        if [[ "${name,,}" == "${pkg,,} "* ]]; then
            name="${name:${#pkg}+1}"
        fi
        if [ "${name,,}" = "${pkg,,}" ]; then
            printf '    %s\n' "$pkg"
        else
            printf '    %-14s %b%s%b\n' "$pkg" "$C_DIM" "$name" "$C_RESET"
        fi
    done
    emit "$C_DIM" "  You can keep them. They still work and get updates as usual."
    printf '\n'

    if ask_yes_no "Remove them?" n; then
        DROPPED_REMOVE=("${pkgs[@]}")
    else
        DROPPED_KEEP=("${pkgs[@]}")
        emit "$C_DIM" "  Kept. To remove them later: sudo pacman -Rs ${pkgs[*]}"
    fi
    printf '\n'
}

# One at a time, so one that something else needs does not stop the rest. That one is
# kept, and not asked about again.
remove_dropped_apps() {
    local pkg

    for pkg in "${DROPPED_REMOVE[@]}"; do
        if run_pacman -Rs --noconfirm "$pkg"; then
            DROPPED_REMOVED+=("$pkg")
        else
            failure "$pkg was kept - other packages need it"
            DROPPED_KEEP+=("$pkg")
        fi
    done
}

remember_kept_apps() {
    [ "${#DROPPED_KEEP[@]}" -gt 0 ] || return 0
    mkdir -p "$(dirname "$KEPT_APPS_FILE")"
    printf '%s\n' "${DROPPED_KEEP[@]}" >>"$KEPT_APPS_FILE"
    sort -u -o "$KEPT_APPS_FILE" "$KEPT_APPS_FILE"
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
