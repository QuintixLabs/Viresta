#!/usr/bin/env bash

# helpers.sh
# What every test uses: a throwaway home folder, a copy of Viresta to work on, fake tools
# and the ok and FAIL lines. Nothing here touches the real system.

set -uo pipefail

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"
VIRESTA="$TEST_DIR/Viresta"
BIN="$TEST_DIR/bin"
PASSED=0
FAILED=0

# Some tests take away write access to check a failure, so it comes back before cleaning up.
trap 'chmod -R u+w "$TEST_DIR" 2>/dev/null; rm -rf "$TEST_DIR"' EXIT

# A home folder of its own, so the real one is never read or changed. Git gets its own
# settings for the same reason.
export HOME="$TEST_DIR/home" TERM=xterm LANG=C.UTF-8 USER=frost
export GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig" GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MAKEFLAGS NO_COLOR \
    VIRESTA_RUN_AS VIRESTA_PULLED VIRESTA_NEW_RELEASE
mkdir -p "$HOME" "$BIN"
export PATH="$BIN:$PATH"

git config --global user.name test
git config --global user.email test@test
git config --global init.defaultBranch master
git config --global advice.detachedHead false

# ------------------------------------------------------------
# Results
# ------------------------------------------------------------

pass() {
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$1"
}

# fail <name> [details...]: each detail goes on its own line under the name.
fail() {
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$1"
    shift
    if [ $# -gt 0 ]; then
        printf '%s\n' "$@" | sed 's/^/     /'
    fi
}

skip() {
    printf 'skip %s\n' "$1"
}

# is <name> <got> <want>
is() {
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "want: $3" "got:  $2"; fi
}

# has <name> <text to find> <in>
has() {
    if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "missing: $2" "in: $(tail -n 8 <<<"$3")"; fi
}

hasnt() {
    if grep -qF -- "$2" <<<"$3"; then fail "$1" "should not have: $2"; else pass "$1"; fi
}

# exists <name> <path> and missing <name> <path>
exists() {
    if [ -e "$2" ] || [ -L "$2" ]; then pass "$1"; else fail "$1" "not there: $2"; fi
}

missing() {
    if [ -e "$2" ] || [ -L "$2" ]; then fail "$1" "still there: $2"; else pass "$1"; fi
}

# The last line run.sh reads, and the exit code it goes by.
finish() {
    printf '=== %s ok, %s failed\n' "$PASSED" "$FAILED"
    if [ "$FAILED" -gt 0 ]; then exit 1; fi
    exit 0
}

# Stops the test early, as skipped, when a tool it needs is not installed.
need() {
    local tool
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            skip "needs $tool, which is not installed"
            finish
        fi
    done
}

strip_colors() {
    sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'
}

# ------------------------------------------------------------
# Viresta
# ------------------------------------------------------------

# A copy to work on, so the tests can change it freely. The wallpapers and cursors are
# big and only the full install needs them, so "all" copies those too. Windows line
# endings come off, for a checkout edited on Windows and run in WSL.
copy_viresta() {
    local -a leave_out=(--exclude=./.git --exclude=./tests --exclude=./assets)

    if [ "${1:-}" != all ]; then
        leave_out+=(--exclude=./config/wallpapers --exclude=./config/cursors)
    fi
    mkdir -p "$VIRESTA"
    tar -C "$REPO" "${leave_out[@]}" -cf - . | tar -C "$VIRESTA" -xf -
    find "$VIRESTA" -type f ! -name '*.png' ! -name '*.jpg' ! -name '*.jpeg' ! -name '*.gz' \
        ! -name '*.xz' ! -name '*.svg' -exec sed -i 's/\r$//' {} +
}

# What an install leaves behind that the viresta command and the alerts look for.
mark_installed() {
    mkdir -p "$HOME/.local/state/viresta"
    : >>"$HOME/.local/state/viresta/installed-files"
    printf '%s\n' "$VIRESTA" >"$HOME/.local/state/viresta/folder"
}

viresta() {
    bash "$VIRESTA/config/commands/viresta" "$@"
}

# ------------------------------------------------------------
# Releases
# ------------------------------------------------------------

# A GitHub of its own. DEV is where releases are made, ORIGIN plays GitHub, and VIRESTA
# becomes a user's clone of it, on the release.
DEV="$TEST_DIR/dev"
ORIGIN="$TEST_DIR/origin.git"

make_clone() {
    mv "$VIRESTA" "$DEV"
    printf '%s\n' "$1" >"$DEV/VERSION"
    git -C "$DEV" init -q
    git -C "$DEV" add -A
    git -C "$DEV" commit -qm "chore: release $1"
    git -C "$DEV" tag "v$1"
    git init -q --bare "$ORIGIN"
    git -C "$DEV" remote add origin "$ORIGIN"
    git -C "$DEV" push -q origin master "v$1"
    git clone -q "$ORIGIN" "$VIRESTA"
    git -C "$VIRESTA" checkout -q "v$1"
}

# Publishes a new release on the fake GitHub.
release() {
    printf '%s\n' "$1" >"$DEV/VERSION"
    git -C "$DEV" commit -qam "chore: release $1"
    git -C "$DEV" tag "v$1"
    git -C "$DEV" push -q origin master "v$1"
}

folder_version() {
    tr -d '[:space:]' <"$VIRESTA/VERSION"
}

no_internet() {
    git -C "$VIRESTA" remote set-url origin "$TEST_DIR/nowhere.git"
}

internet_back() {
    git -C "$VIRESTA" remote set-url origin "$ORIGIN"
}

# ------------------------------------------------------------
# A fake system
# ------------------------------------------------------------

# For running the real install.sh, update.sh and uninstall.sh. System folders are moved
# inside the home folder, and sudo, pacman and the KDE tools are fakes. pacman keeps its
# packages in a file, so what got installed and removed can be checked.
SYS="$HOME/.sysroot"
export FAKE_DB="$TEST_DIR/packages" FAKE_CALLS="$TEST_DIR/calls"

fake_system() {
    cat >"$BIN/sudo" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" != "-n" ] || shift
case "$*" in *sudoers.d*) [ "$1" = test ] && exit 1; exit 0 ;; esac
case "${1:-}" in
    -S) cat >/dev/null; exit 0 ;;
    pacman) shift; exec pacman "$@" ;;
    install)
        args=(); shift
        while [ $# -gt 0 ]; do case "$1" in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac; done
        exec install "${args[@]}" ;;
    *) exec "$@" ;;
esac
EOF
    cat >"$BIN/pacman" <<'EOF'
#!/usr/bin/env bash
echo "pacman $*" >>"$FAKE_CALLS"
args=(); while [ $# -gt 0 ]; do case "$1" in --config) shift 2 ;; *) args+=("$1"); shift ;; esac; done
set -- "${args[@]}"
op="$1"; shift
case "$op" in
    -Qq)
        if [ $# -eq 0 ]; then cat "$FAKE_DB"; exit 0; fi
        name="$1"; [ "$name" != outfit-font ] || name=otf-outfit
        grep -xF "$name" "$FAKE_DB" ;;
    -Si) exit 1 ;;
    -Syu|-Su|-Sy) touch "$FAKE_DB.upgraded"; exit 0 ;;
    -S)
        for a in "$@"; do
            case "$a" in -*) continue ;; esac
            if [ "$a" = "${NEEDS_UPGRADE:-none}" ] && [ ! -e "$FAKE_DB.upgraded" ]; then echo "error: 404 $a"; exit 1; fi
            grep -qxF "$a" "$FAKE_DB" || echo "$a" >>"$FAKE_DB"
        done ;;
    -Rs)
        for a in "$@"; do
            case "$a" in -*) continue ;; esac
            [ "$a" != outfit-font ] || { echo "error: target not found: $a"; exit 1; }
            [ "$a" != "${CANNOT_REMOVE:-none}" ] || { echo "error: breaks dependency"; exit 1; }
            sed -i "/^$a\$/d" "$FAKE_DB"
        done ;;
esac
EOF
    cat >"$BIN/paru" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in -*) ;; outfit-font) echo otf-outfit >>"$FAKE_DB" ;; *) echo "$a" >>"$FAKE_DB" ;; esac; done
EOF
    printf '#!/bin/sh\n[ -n "${PLASMA_RUNNING:-}" ]\n' >"$BIN/pgrep"
    printf '#!/bin/sh\necho "frost:x:1000:1000::/home/frost:/bin/bash"\n' >"$BIN/getent"
    printf '#!/bin/sh\nexit 0\n' | tee "$BIN/visudo" "$BIN/systemctl" "$BIN/vicinae" "$BIN/kbuildsycoca6" "$BIN/codium" >/dev/null
    printf '#!/bin/sh\nexit 1\n' >"$BIN/curl"
    chmod +x "$BIN"/*

    printf 'paru\ndefault-cursors\n' >"$FAKE_DB"
    : >"$FAKE_CALLS"

    sed -i -E "s#(^|[\" ])/(usr/share|usr/lib|usr/local|etc|var/lib)/#\1$SYS/\2/#g" "$VIRESTA/setup/shared/variables.sh"
    sed -i 's|\[ -f /etc/arch-release \]|true|; s|^    require_internet$|    true|; s|^    detect_virt$|    VIRT=none|' \
        "$VIRESTA/lib/system/checks.sh"
    : >"$TEST_DIR/pacman.conf"
    sed -i "s|cp /etc/pacman.conf|cp $TEST_DIR/pacman.conf|" "$VIRESTA/lib/installers/pacman.sh"
    fake_system_folders

    # install.sh checks for newer releases, and update.sh needs a clone to download into.
    git -C "$VIRESTA" init -q
    git -C "$VIRESTA" add -A
    git -C "$VIRESTA" commit -qm base
}

fake_system_folders() {
    mkdir -p "$SYS/usr/share/sddm/themes/breeze" "$SYS/usr/share/icons/default" \
        "$SYS/usr/lib/systemd/user" "$SYS/etc/sddm.conf.d" "$SYS/usr/share/applications"
    printf 'keep me\n' >"$SYS/etc/sddm.conf.d/other.conf"
    printf '[Desktop Entry]\nName=OBS Studio\nExec=obs\n' >"$SYS/usr/share/applications/com.obsproject.Studio.desktop"
}

# run_script <script and options> [answers...]: runs it in a real terminal, and types
# each answer after a pause. STATUS and OUT hold how it ended and what was on screen.
run_script() {
    local command="$1"
    shift

    { sleep 0.6; for answer in "$@"; do printf '%s\n' "$answer"; sleep 0.5; done; sleep 0.3; } \
        | script -qec "cd '$VIRESTA' && bash $command" "$TEST_DIR/screen" >/dev/null 2>&1
    STATUS=$?
    OUT="$(sed -e 's/\r$//' -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/.*\r//' "$TEST_DIR/screen")"
}

# Every file in the home folder with a hash of its contents, to see what changed. The
# icon themes alone are thousands of files, so one sha256sum hashes them all at once.
snapshot() {
    (
        cd "$HOME" || exit 1
        {
            find . -mindepth 1 -type d -printf 'dir %p\n'
            find . -mindepth 1 -type l -printf 'link %p -> %l\n'
            find . -mindepth 1 -type f -print0 | xargs -0 -r sha256sum | sed 's/  / /'
        } | sort -k2
    )
}

# The lines that differ between two snapshots, without the hashes.
changes() {
    diff "$1" "$2" | grep -E '^[<>]' | sed -E 's/^([<>]) [0-9a-f]{64} /\1 /'
}
