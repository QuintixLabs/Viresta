#!/usr/bin/env bash
# Viresta - package installation, paru bootstrap, AUR and login configuration.
# Sourced by install.sh. Not meant to be executed directly.

PACMAN_CONF=""
AUR_LOG_DIR="${AUR_LOG_DIR:-$HOME/.local/state/viresta}"

cleanup_pacman_conf() {
    [ -n "${PACMAN_CONF:-}" ] || return 0
    rm -f "$PACMAN_CONF" 2>/dev/null || true
    PACMAN_CONF=""
}

# Creates a temporary pacman config with ParallelDownloads = 1 so packages
# download one at a time. The real /etc/pacman.conf is never modified.
prepare_pacman_conf() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would limit downloads to one at a time"
        return 0
    fi

    PACMAN_CONF="$(mktemp /tmp/viresta-pacman.XXXXXX)"
    cp /etc/pacman.conf "$PACMAN_CONF"

    if grep -qE '^[#[:space:]]*ParallelDownloads' "$PACMAN_CONF"; then
        sed -i -E 's|^[#[:space:]]*ParallelDownloads.*|ParallelDownloads = 1|' "$PACMAN_CONF"
    else
        printf '\nParallelDownloads = 1\n' >>"$PACMAN_CONF"
    fi

    register_cleanup cleanup_pacman_conf
    ok "Downloads limited to one at a time"
}

# run_pacman <pacman args...>
# Runs pacman inside a pseudo-terminal so progress streams live, and tees it.
run_pacman() {
    local -a args=(pacman)
    if [ -n "${PACMAN_CONF:-}" ]; then
        args+=(--config "$PACMAN_CONF")
    fi
    args+=("$@")

    if command -v script >/dev/null 2>&1; then
        script -q -e -c "sudo ${args[*]}" /dev/null | tee -a "$LOG_FILE"
    else
        sudo "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
    fi
}

update_system() {
    prepare_pacman_conf

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would refresh archlinux-keyring"
        info "Would run a full system upgrade"
        return 0
    fi

    info "Refreshing archlinux-keyring"
    run_pacman -Sy --needed --noconfirm archlinux-keyring || die "Failed to refresh the keyring."

    info "Upgrading the system"
    run_pacman -Su --noconfirm || die "System upgrade failed."

    ok "System up to date"
}

# _install_array <label> <pkg...>
_install_array() {
    local label="$1"
    shift
    local -a pkgs=("$@")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        info "$label: nothing to install"
        return 0
    fi

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "$label: would install ${pkgs[*]}"
        return 0
    fi

    info "$label: ${pkgs[*]}"
    run_pacman -S --needed --noconfirm "${pkgs[@]}" || die "Failed to install $label."
    ok "$label installed"
}

# install_group <label> <package-list-file>
install_group() {
    local label="$1" file="$2"
    local -a pkgs=()

    if [ -f "$file" ]; then
        mapfile -t pkgs < <(
            sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" |
                grep -v '^$'
        )
    fi

    _install_array "$label" "${pkgs[@]}"
}

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

# _aur_install_one <package>
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
        warn "$pkg: paru is not available"
        return 1
    fi

    mkdir -p "$AUR_LOG_DIR"
    local log="$AUR_LOG_DIR/aur-$pkg.log"
    info "$pkg: building from the AUR (this may take a while)"

    if paru -S --needed --noconfirm "$pkg" </dev/null >"$log" 2>&1; then
        ok "$pkg installed"
        return 0
    fi

    warn "$pkg: install failed - see $log"
    return 1
}

# pkg_source <package>
# Prints "repo" if pacman knows the package, otherwise "aur".
# The lookup is silent on purpose - nothing is shown or logged.
pkg_source() {
    if pacman -Si "$1" >/dev/null 2>&1; then
        printf 'repo\n'
    else
        printf 'aur\n'
    fi
}

# install_aur
# Reads packages/aur.txt and installs every package from the AUR.
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
        _aur_install_one "$pkg" || true
    done <"$file"

    return 0
}

# install_vm_extras
# Installs packages listed for the detected VM in packages/vm.txt.
# Source is detected silently: official repo -> pacman, otherwise -> paru.
install_vm_extras() {
    local -a pkgs=()
    mapfile -t pkgs < <(vm_pkgs_for "$VIRT")

    if [ "${#pkgs[@]}" -eq 0 ]; then
        info "No VM packages for $VIRT"
        return 0
    fi

    local pkg source
    for pkg in "${pkgs[@]}"; do
        source="$(pkg_source "$pkg")"

        if [ "$source" = "repo" ]; then
            if [ "${DRY_RUN:-0}" -eq 1 ]; then
                info "Would install $pkg (repository)"
                continue
            fi
            info "$pkg: installing"
            run_pacman -S --needed --noconfirm "$pkg" || die "Failed to install $pkg."
        else
            _aur_install_one "$pkg" || true
        fi
    done

    return 0
}

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
    warn "paru: build failed - see $log"
    return 1
}

configure_networkmanager() {
    [ -e /usr/lib/systemd/system/NetworkManager.service ] || return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable NetworkManager"
        return 0
    fi
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 \
        && ok "NetworkManager enabled" \
        || warn "Could not enable NetworkManager"
}

configure_vm_services() {
    local svc
    svc="$(vm_service_for "$VIRT")"
    [ -n "$svc" ] || return 0

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable $svc"
        return 0
    fi

    sudo systemctl enable "$svc" >/dev/null 2>&1 \
        && ok "Enabled $svc" \
        || warn "Could not enable $svc"
}

configure_sddm() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would enable sddm.service"
        return 0
    fi
    sudo systemctl enable sddm.service >/dev/null 2>&1 \
        || die "Failed to enable sddm.service."
    ok "sddm enabled (starts on next boot)"
}

configure_default_session() {
    local sess=''
    local first
    first="$(ls /usr/share/wayland-sessions/*.desktop 2>/dev/null | head -n1 || true)"
    if [ -n "$first" ]; then
        sess="$(basename "$first" .desktop)"
    fi
    [ -n "$sess" ] || sess="plasma"

    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would set the SDDM default session to $sess (Wayland)"
        return 0
    fi

    sudo mkdir -p /etc/sddm.conf.d
    printf '[Users]\nDefaultSession=%s\n' "$sess" |
        sudo tee /etc/sddm.conf.d/10-viresta.conf >/dev/null
    ok "Default session: $sess (Wayland)"
}

# Merges a .colors scheme into ~/.config/kdeglobals using kwriteconfig6.
# This works without a running Plasma session (unlike the GUI helpers).
_apply_colors_file() {
    local file="$1"
    [ -f "$file" ] || return 1

    local section="" line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in
            ''|\#*|\;*) continue ;;
            \[*\])
                section="${line#\[}"
                section="${section%\]}"
                continue
                ;;
        esac

        case "$line" in
            *=*) ;;
            *) continue ;;
        esac

        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        if [ -z "$section" ] || [ -z "$key" ]; then
            continue
        fi

        kwriteconfig6 --file kdeglobals --group "$section" --key "$key" "$value" \
            >/dev/null 2>&1 || return 1
    done <"$file"

    return 0
}

# Applies Breeze Dark for the current user. Takes effect at first login.
apply_dark_theme() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would apply the Breeze Dark theme"
        return 0
    fi

    local applied=0
    local scheme="/usr/share/color-schemes/BreezeDark.colors"

    # Pre-login safe: write the color values straight into kdeglobals.
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        if [ -f "$scheme" ] && _apply_colors_file "$scheme"; then
            kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage \
                org.kde.breezedark.desktop >/dev/null 2>&1 || true
            kwriteconfig6 --file kdeglobals --group General --key ColorScheme \
                BreezeDark >/dev/null 2>&1 || true
            kwriteconfig6 --file kdeglobals --group Icons --key Theme \
                breeze >/dev/null 2>&1 || true
            applied=1
        fi
    fi

    # These need a live display and abort (core dump) before login, so only
    # touch them if a session is already running.
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
        if command -v lookandfeeltool >/dev/null 2>&1; then
            lookandfeeltool -a org.kde.breezedark.desktop >/dev/null 2>&1 || true
            applied=1
        fi
        if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
            plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
            applied=1
        fi
    fi

    if [ "$applied" -eq 1 ]; then
        ok "Breeze Dark configured (applies at first login)"
    else
        warn "Could not set the dark theme; choose it in System Settings"
    fi
}
