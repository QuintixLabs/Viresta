#!/usr/bin/env bash

# sudo.sh
# Asks for the password and handles the temporary sudo rule.

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

sudoers_tmp="/etc/sudoers.d/viresta-temp"
_NOPASSWD_ACTIVE=0

# ------------------------------------------------------------
# Password
# ------------------------------------------------------------

read_password() {
    local pw=''
    spinner_stop
    printf '%b?%b Password for %s (asked once, used for sudo): ' \
        "$C_ACCENT" "$C_RESET" "${USER:-$(id -un)}" >&2
    if [ -r /dev/tty ]; then
        IFS= read -rs pw </dev/tty || true
    else
        IFS= read -rs pw || true
    fi
    printf '\n' >&2
    [ -n "$pw" ] || die "No password provided."
    ADMIN_PW="$pw"
    spinner_start
}

# ------------------------------------------------------------
# Temporary sudo rule
# ------------------------------------------------------------

cleanup_nopasswd() {
    [ "$_NOPASSWD_ACTIVE" -eq 1 ] || return 0
    sudo -n rm -f "$sudoers_tmp" 2>/dev/null || true
    _NOPASSWD_ACTIVE=0
}

enable_nopasswd() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        info "Would ask for your password once"
        info "Would add a temporary NOPASSWD rule and remove it on exit"
        return 0
    fi

    printf '%s\n' "${ADMIN_PW:-}" | sudo -S -p '' -v 2>/dev/null \
        || die "sudo authentication failed."
    unset ADMIN_PW

    if sudo -n test -e "$sudoers_tmp" 2>/dev/null; then
        warn "Found leftover $sudoers_tmp from an interrupted run; removing"
        sudo rm -f "$sudoers_tmp"
    fi

    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${USER:-$(id -un)}" >"$tmp"

    if ! visudo -cf "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        die "Generated sudoers rule failed validation."
    fi

    sudo install -m 0440 -o root -g root "$tmp" "$sudoers_tmp"
    rm -f "$tmp"

    _NOPASSWD_ACTIVE=1
    register_cleanup cleanup_nopasswd
    ok "Passwordless sudo enabled for this run"
}
