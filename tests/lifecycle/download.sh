#!/usr/bin/env bash

# download.sh
# Runs the real update.sh on a fake system after an install, with a fake GitHub to
# download from: new commits, releases, --dev, local edits and a failed download.

source "$(dirname "$0")/../shared/helpers.sh"

need jq script

copy_viresta all
fake_system

run_script ./install.sh "" "hunter2"
is "the install before it finishes" "$STATUS" "0"

# ------------------------------------------------------------
# Downloading
# ------------------------------------------------------------

# The folder becomes a clone of a fake GitHub, with a maintainer's copy to push from.
git -C "$VIRESTA" add -A
git -C "$VIRESTA" commit -q --allow-empty -m "after the install"
git clone -q --bare "$VIRESTA" "$ORIGIN"
git -C "$VIRESTA" remote add origin "$ORIGIN"
git -C "$VIRESTA" fetch -q origin
git -C "$VIRESTA" branch -q -u origin/master master

printf '# local edit\n' >"$VIRESTA/README-local"
run_script ./update.sh "hunter2"
is "local edits: stops" "$STATUS" "1"
has "local edits: says why" "local edits" "$OUT"
hasnt "local edits: no password asked" "Password for" "$OUT"
rm "$VIRESTA/README-local"

git clone -q "$ORIGIN" "$DEV"
sed -i 's/^TOTAL_STEPS=4$/TOTAL_STEPS=4\n# NEW VERSION MARKER/' "$DEV/update.sh"
sed -i 's/printf .%bUpdate complete%b.n. "$C_OK$C_BOLD" "$C_RESET"/&\n    printf "RAN THE NEW SCRIPT\\n"/' "$DEV/update.sh"
git -C "$DEV" commit -qam new
git -C "$DEV" push -q origin master
run_script ./update.sh "hunter2"
is "a new commit: finishes" "$STATUS" "0"
has "a new commit: the file is updated" "NEW VERSION MARKER" "$(cat "$VIRESTA/update.sh")"
has "a new commit: the new script is what ran" "RAN THE NEW SCRIPT" "$OUT"
is "a new commit: the password is asked once" "$(grep -c 'Password for' <<<"$OUT")" "1"
is "a new commit: the banner shows once" "$(grep -c 'The clean, stable' <<<"$OUT")" "1"
is "a new commit: the download step shows once" "$(grep -c 'Downloading the latest' <<<"$OUT")" "1"
is "a new commit: the steps in order" "$(grep -oE '^\[[0-9]/4\]' <<<"$OUT" | awk '!seen[$0]++' | tr -d '\n')" "[1/4][2/4][3/4][4/4]"
is "a new commit: one line for each step" "$(grep -cE '^\[[0-9]/4\].*[✓!]' <<<"$OUT")" "4"

run_script ./update.sh "n"
is "nothing new: finishes" "$STATUS" "0"
has "nothing new: says so" "up to date" "$OUT"
hasnt "nothing new, no: no password" "Password for" "$OUT"
run_script ./update.sh ""
is "nothing new, Enter: stops" "$STATUS" "0"
hasnt "nothing new, Enter: no password" "Password for" "$OUT"
run_script ./update.sh "y" "hunter2"
is "nothing new, yes: applies the configs again" "$(grep -c 'Update complete' <<<"$OUT")" "1"

# ------------------------------------------------------------
# Releases
# ------------------------------------------------------------

git -C "$DEV" pull -q origin master
echo 9.9.9 >"$DEV/VERSION"
git -C "$DEV" commit -qam "chore: release 9.9.9"
git -C "$DEV" tag v9.9.9
git -C "$DEV" push -q origin master v9.9.9
PENDING="$HOME/.local/state/viresta/update-pending"
before="$(git -C "$VIRESTA" rev-parse HEAD)"

run_script ./update.sh "n"
has "a release: says what's out" "Viresta 9.9.9 is out (you're on " "$OUT"
has "a release: asks first" "Update now? [Y/n]" "$OUT"
is "said no: stops" "$STATUS" "0"
is "said no: the folder is not moved" "$(git -C "$VIRESTA" rev-parse HEAD)" "$before"
hasnt "said no: no password asked" "Password for" "$OUT"
missing "said no: nothing is unfinished" "$PENDING"

# Enter is yes, and that one answer is the whole update.
run_script ./update.sh "" "hunter2"
is "a release: finishes" "$STATUS" "0"
hasnt "a release: no second question about the configs" "Apply Viresta's configs again" "$OUT"
missing "a release: nothing left unfinished" "$PENDING"
is "a release: on its tag" "$(git -C "$VIRESTA" describe --tags --exact-match 2>/dev/null)" "v9.9.9"
has "a release: says the versions" "to v9.9.9" "$OUT"
has "a release: links to what's new" "See what's new: https://github.com/QuintixLabs/Viresta/releases/tag/v9.9.9" "$OUT"
is "a release: the password is asked once" "$(grep -c 'Password for' <<<"$OUT")" "1"

git -C "$DEV" commit -q --allow-empty -m "after the release"
git -C "$DEV" push -q origin master
run_script ./update.sh "n"
is "a plain update ignores newer commits" "$(git -C "$VIRESTA" describe --tags --exact-match 2>/dev/null)" "v9.9.9"
has "a plain update: up to date" "up to date" "$OUT"

run_script "./update.sh --dev" "hunter2"
is "--dev: finishes" "$STATUS" "0"
is "--dev: on the latest commit" "$(git -C "$VIRESTA" rev-parse HEAD)" "$(git -C "$DEV" rev-parse HEAD)"
is "--dev: on master" "$(git -C "$VIRESTA" symbolic-ref --short HEAD 2>/dev/null)" "master"
hasnt "--dev: no what's new link" "See what's new" "$OUT"
run_script ./update.sh "n"
is "a plain update after --dev does not go back" "$(git -C "$VIRESTA" rev-parse HEAD)" "$(git -C "$DEV" rev-parse HEAD)"

echo 9.9.10 >"$DEV/VERSION"
git -C "$DEV" commit -qam "chore: release 9.9.10"
git -C "$DEV" tag v9.9.10
git -C "$DEV" push -q origin master v9.9.10

# Stopped at the password: the download is done, but nothing is installed yet.
run_script ./update.sh "" ""
is "stopped at the password: stops" "$STATUS" "1"
is "stopped at the password: the folder is on the release" "$(git -C "$VIRESTA" describe --tags --exact-match 2>/dev/null)" "v9.9.10"
is "stopped at the password: noted as unfinished" "$(cat "$PENDING" 2>/dev/null)" "v9.9.10"

# A newer release while that one is unfinished. The folder is on 9.9.10 but the system
# is not, so it does not say "you're on 9.9.10". The release is only a tag, gone after.
git -C "$DEV" checkout -q --detach
echo 9.9.11 >"$DEV/VERSION"
git -C "$DEV" commit -qam "chore: release 9.9.11"
git -C "$DEV" tag v9.9.11
git -C "$DEV" push -q origin v9.9.11
run_script ./update.sh "n"
has "unfinished, then a newer release: says the last one didn't finish" \
    "Viresta 9.9.11 is out (the last update, to v9.9.10, didn't finish)" "$OUT"
hasnt "unfinished, then a newer release: not on 9.9.10" "you're on" "$OUT"
is "unfinished, said no: still unfinished" "$(cat "$PENDING" 2>/dev/null)" "v9.9.10"
git -C "$DEV" push -q origin :refs/tags/v9.9.11
git -C "$DEV" tag -d v9.9.11 >/dev/null
git -C "$VIRESTA" tag -d v9.9.11 >/dev/null
git -C "$DEV" checkout -q master
git -C "$DEV" reset -q --hard origin/master

run_script ./update.sh "" "hunter2"
has "the next update notices" "The last update to v9.9.10 didn't finish" "$OUT"
has "and asks to finish it" "Finish it now? [Y/n]" "$OUT"
hasnt "and does not call it up to date" "up to date" "$OUT"
is "finishing: finishes" "$STATUS" "0"
has "finishing: the whole update runs" "Update complete" "$OUT"
missing "finishing: nothing left unfinished" "$PENDING"
is "a newer release after --dev: back on releases" "$(git -C "$VIRESTA" describe --tags --exact-match 2>/dev/null)" "v9.9.10"

run_script ./update.sh "n"
has "after that: up to date again" "up to date" "$OUT"
run_script "./update.sh --dev" "n"
is "--dev with nothing new: asks and stops" "$STATUS" "0"

# Back to no releases, with master here and on GitHub gone different ways.
git -C "$VIRESTA" checkout -q master
git -C "$VIRESTA" pull -q --ff-only
git -C "$VIRESTA" tag -d v9.9.9 v9.9.10 >/dev/null
git -C "$DEV" tag -d v9.9.9 v9.9.10 >/dev/null
git -C "$DEV" push -q origin :refs/tags/v9.9.9 :refs/tags/v9.9.10
git -C "$DEV" commit -q --allow-empty -m other
git -C "$DEV" push -q origin master
git -C "$VIRESTA" commit -q --allow-empty -m diverged
run_script ./update.sh "hunter2"
is "it cannot move forward: stops" "$STATUS" "1"
has "it cannot move forward: says nothing changed" "Nothing was changed" "$OUT"
hasnt "it cannot move forward: not blamed on the internet" "internet" "$OUT"
git -C "$VIRESTA" reset -q --hard origin/master

# No internet: .invalid is a name that never exists, so git cannot find it.
git -C "$VIRESTA" remote set-url origin "https://github.invalid/QuintixLabs/Viresta.git"
before="$(git -C "$VIRESTA" rev-parse HEAD)"
run_script ./update.sh "hunter2"
is "no internet: stops" "$STATUS" "1"
has "no internet: says so" "Could not reach GitHub. Check your internet connection" "$OUT"
has "no internet: nothing changed" "Nothing was changed" "$OUT"
is "no internet: the folder is not moved" "$(git -C "$VIRESTA" rev-parse HEAD)" "$before"
hasnt "no internet: no password asked" "Password for" "$OUT"
git -C "$VIRESTA" remote set-url origin "$ORIGIN"

run_script "./update.sh --no-pull"
is "the old --no-pull is refused" "$STATUS" "2"

mkdir "$TEST_DIR/no-clone"
cp -r "$VIRESTA/lib" "$VIRESTA/update.sh" "$VIRESTA/packages" "$VIRESTA/setup" "$TEST_DIR/no-clone/"
sleep 0.6 | script -qec "cd '$TEST_DIR/no-clone' && bash ./update.sh" "$TEST_DIR/screen" >/dev/null 2>&1
is "not a git clone: stops" "$?" "1"
has "not a git clone: says why" "not a git clone" "$(strip_colors <"$TEST_DIR/screen")"

finish
