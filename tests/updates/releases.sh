#!/usr/bin/env bash

# releases.sh
# Tests how versions are compared, how install.sh picks the newest release, going back
# when an update download fails, and the release notes the workflow writes.

source "$(dirname "$0")/../shared/helpers.sh"

copy_viresta
SCRIPT_DIR="$VIRESTA"
source "$VIRESTA/lib/system/version.sh"

# ------------------------------------------------------------
# Comparing versions
# ------------------------------------------------------------

newer() { if is_newer_version "$1" "$2"; then echo yes; else echo no; fi; }
is "0.2.0 is newer than 0.1.0" "$(newer 0.2.0 0.1.0)" "yes"
is "0.1.0 is not newer than 0.2.0" "$(newer 0.1.0 0.2.0)" "no"
is "the same is not newer" "$(newer 0.1.0 0.1.0)" "no"
is "0.10.0 is newer than 0.9.0, as numbers" "$(newer 0.10.0 0.9.0)" "yes"
is "1.0.0 is newer than 0.99.9" "$(newer 1.0.0 0.99.9)" "yes"
is "no VERSION file yet: anything is newer" "$(newer 0.1.0 "")" "yes"

# ------------------------------------------------------------
# Picking a release
# ------------------------------------------------------------

# A small project whose install.sh only says which version and script it ran.
P="$TEST_DIR/project"
P_ORIGIN="$TEST_DIR/project.git"
git init -q --bare "$P_ORIGIN"
git clone -q "$P_ORIGIN" "$P" 2>/dev/null
mkdir -p "$P/lib/system"
cp "$VIRESTA/lib/system/version.sh" "$P/lib/system/version.sh"
cat >"$P/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/system/version.sh"
DRY_RUN=0
for a in "$@"; do [ "$a" = "--dry-run" ] && DRY_RUN=1; done
if [ "$DRY_RUN" -eq 0 ]; then use_newest_release "$@"; fi
echo "RAN version=$(viresta_version) script=SCRIPT_MARK args=$*"
EOF
echo 0.1.0 >"$P/VERSION"
sed -i 's/SCRIPT_MARK/one/' "$P/install.sh"
commit() { git -C "$P" add -A; git -C "$P" commit -qm "$1"; git -C "$P" push -q origin master; }
commit one

clone() { rm -rf "${TEST_DIR:?}/${1:?}"; git clone -q "$P_ORIGIN" "$TEST_DIR/$1"; }
install() { bash "$TEST_DIR/$1/install.sh" "${@:2}" 2>&1 | tail -n 1; }

clone a
is "no releases: this commit" "$(install a)" "RAN version=0.1.0 script=one args="
is "no releases: still on master" "$(git -C "$TEST_DIR/a" symbolic-ref --short HEAD)" "master"

git -C "$P" tag v0.1.0
git -C "$P" push -q origin v0.1.0
sed -i 's/script=one/script=two/' "$P/install.sh"
commit two
clone b
is "a plain clone is on the newest commit" "$(grep -c 'script=two' "$TEST_DIR/b/install.sh")" "1"
is "commits after a release: the release's own script ran" "$(install b)" "RAN version=0.1.0 script=one args="
is "options come along" "$(install b --verbose | sed 's/.*args=//')" "--verbose"

echo 0.2.0 >"$P/VERSION"
sed -i 's/script=two/script=three/' "$P/install.sh"
commit three
clone c
is "a draft that is not published: still the old release" "$(install c)" "RAN version=0.1.0 script=one args="

git -C "$P" tag v0.2.0
git -C "$P" push -q origin v0.2.0
clone d
is "published: the new release" "$(install d)" "RAN version=0.2.0 script=three args="
is "published: on the tag" "$(git -C "$TEST_DIR/d" describe --tags --exact-match)" "v0.2.0"
is "run again: does not loop" "$(install d)" "RAN version=0.2.0 script=three args="

clone e
git -C "$TEST_DIR/e" checkout -q v0.1.0
is "an older folder moves up" "$(install e)" "RAN version=0.2.0 script=three args="

# Someone testing their own branch, in a fork that has the tags.
clone j
git -C "$TEST_DIR/j" switch -q -c my-change
sed -i 's/script=three/script=mine/' "$TEST_DIR/j/install.sh"
git -C "$TEST_DIR/j" commit -qam mine
is "another branch: installs that branch" "$(install j)" "RAN version=0.2.0 script=mine args="
is "another branch: stays on it" "$(git -C "$TEST_DIR/j" symbolic-ref --short HEAD)" "my-change"
clone k
git -C "$TEST_DIR/k" switch -q -c dev origin/master
echo 9.9.9 >"$TEST_DIR/k/VERSION"
git -C "$TEST_DIR/k" commit -qam ahead
is "a dev branch: not moved to a release" "$(install k | grep -c 'version=9.9.9')" "1"

clone f
git -C "$TEST_DIR/f" commit -q --allow-empty -m "not the release"
echo edit >>"$TEST_DIR/f/VERSION"
is "local edits: says so" "$(bash "$TEST_DIR/f/install.sh" 2>&1 | grep -c 'local edits')" "1"
is "local edits: stays on master" "$(git -C "$TEST_DIR/f" symbolic-ref --short HEAD)" "master"

clone g
bash "$TEST_DIR/g/install.sh" --dry-run >/dev/null 2>&1
is "dry run: stays on master" "$(git -C "$TEST_DIR/g" symbolic-ref --short HEAD)" "master"

mkdir -p "$TEST_DIR/zip"
cp -r "$P/install.sh" "$P/VERSION" "$P/lib" "$TEST_DIR/zip/"
is "not a clone, like a zip: installs as it is" "$(bash "$TEST_DIR/zip/install.sh" 2>&1 | tail -n 1)" "RAN version=0.2.0 script=three args="

clone h
git -C "$TEST_DIR/h" remote set-url origin "$TEST_DIR/nowhere.git"
is "no internet: uses the release it knows" "$(install h)" "RAN version=0.2.0 script=three args="

git -C "$P" tag test-build
git -C "$P" tag vfoo
git -C "$P" push -q origin test-build vfoo
clone i
is "only version tags count" "$(SCRIPT_DIR="$TEST_DIR/i"; newest_release)" "v0.2.0"
git -C "$P" tag v0.10.0
git -C "$P" push -q origin v0.10.0
clone i
is "0.10.0 is newer than 0.2.0" "$(SCRIPT_DIR="$TEST_DIR/i"; newest_release)" "v0.10.0"

# ------------------------------------------------------------
# A failed update download
# ------------------------------------------------------------

# On the release, with master here and on GitHub gone different ways.
clone u
git -C "$TEST_DIR/u" commit -q --allow-empty -m local
git -C "$P" commit -q --allow-empty -m other
git -C "$P" push -q origin master
git -C "$TEST_DIR/u" fetch -q
git -C "$TEST_DIR/u" checkout -q v0.2.0
on_release="$(git -C "$TEST_DIR/u" rev-parse HEAD)"

follow() {
    (
        SCRIPT_DIR="$TEST_DIR/u"
        LOG_FILE="$TEST_DIR/log"
        die() { echo "DIE $1"; exit 1; }
        source "$VIRESTA/lib/system/version.sh"
        source "$VIRESTA/lib/update/download.sh"
        follow_latest_commit
        echo DONE
    )
}
is "failed download: says nothing changed" "$(follow)" "DIE Could not download the latest Viresta. Nothing was changed."
is "failed download: back on the release" "$(git -C "$TEST_DIR/u" rev-parse HEAD)" "$on_release"
is "failed download: not left on a branch" "$(git -C "$TEST_DIR/u" symbolic-ref -q --short HEAD || echo none)" "none"

git -C "$TEST_DIR/u" checkout -q master
on_master="$(git -C "$TEST_DIR/u" rev-parse HEAD)"
follow >/dev/null
is "on a branch, failed: stays on it" "$(git -C "$TEST_DIR/u" symbolic-ref -q --short HEAD)/$(git -C "$TEST_DIR/u" rev-parse HEAD)" "master/$on_master"

git -C "$TEST_DIR/u" reset -q --hard origin/master~1
git -C "$TEST_DIR/u" checkout -q v0.2.0
is "a working download: finishes" "$(follow)" "DONE"
is "a working download: on the latest commit" "$(git -C "$TEST_DIR/u" rev-parse HEAD)" "$(git -C "$P" rev-parse HEAD)"

# ------------------------------------------------------------
# The release workflow
# ------------------------------------------------------------

# The workflow's script, taken out of the YAML, with a fake gh.
awk '/^ *run: \|$/ { on = 1; next }
     on {
         if (indent == "" && NF) { match($0, /^ */); indent = RLENGTH }
         if (NF) { match($0, /^ */); if (RLENGTH < indent) exit }
         print substr($0, indent + 1)
     }' "$VIRESTA/.github/workflows/release.yml" >"$TEST_DIR/flow.sh"
is "the workflow's script is valid Bash" "$(bash -n "$TEST_DIR/flow.sh" 2>&1; echo $?)" "0"

cat >"$BIN/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "release view") [ -e "$FAKE_EXISTS" ] ;;
    "api --paginate") printf 'alice\nbob\nalice\ndependabot[bot]\n' ;;
    "release create") printf '%s\n' "$*" >"$CREATED" ;;
esac
EOF
chmod +x "$BIN/gh"

flow() {
    rm -rf "$TEST_DIR/run"
    git clone -q "$P_ORIGIN" "$TEST_DIR/run"
    git -C "$TEST_DIR/run" fetch -q --tags
    git -C "$TEST_DIR/run" tag -d v0.10.0 >/dev/null
    printf '%s\n' "$1" >"$TEST_DIR/run/VERSION"
    git -C "$TEST_DIR/run" commit -qam "chore: release $1"
    git -C "$TEST_DIR/run" commit -q --allow-empty -m "fix: icons [4]"
    rm -f "$TEST_DIR/created"
    ( cd "$TEST_DIR/run" && CREATED="$TEST_DIR/created" FAKE_EXISTS="$TEST_DIR/exists" \
        GITHUB_SHA="$(git rev-parse HEAD)" GITHUB_REPOSITORY=QuintixLabs/Viresta \
        GITHUB_SERVER_URL=https://github.com bash -e "$TEST_DIR/flow.sh" ) >/dev/null 2>&1
}

flow 0.3.0
is "workflow: finishes" "$?" "0"
notes="$(cat "$TEST_DIR/run/notes.md")"
is "workflow: the commit without its type" "$(grep -c '^- Icons \[4\]$' <<<"$notes")" "1"
is "workflow: under its heading" "$(grep -c '^## 🐛 Fixes$' <<<"$notes")" "1"
hasnt "workflow: the release commit is left out" "release 0.3.0" "$notes"
is "workflow: contributors, once each, no bots" "$(sed -n '/## Contributors/,/Full/p' <<<"$notes" | grep '^- ' | paste -sd,)" "- @alice,- @bob"
is "workflow: changelog link" "$(grep -c 'compare/v0.2.0...v0.3.0$' <<<"$notes")" "1"
is "workflow: only commits since the last release" "$(grep -c 'one$' <<<"$notes")" "0"
is "workflow: a draft on that commit" "$(grep -c -- '--draft --target' "$TEST_DIR/created")" "1"
is "workflow: the right tag" "$(awk '{print $3}' "$TEST_DIR/created")" "v0.3.0"

flow 'not a version'
is "workflow: a bad number stops" "$?" "1"
missing "workflow: a bad number makes no draft" "$TEST_DIR/created"

: >"$TEST_DIR/exists"
flow 0.3.0
is "workflow: a draft already there: still finishes" "$?" "0"
missing "workflow: a draft already there is left alone" "$TEST_DIR/created"
rm -f "$TEST_DIR/exists"

# The headings, with made-up commits of every kind.
N="$TEST_DIR/notes"
git init -q "$N"
for message in base "feat(menu): add a thing" "fix!: break and fix" "fix: lower case start" \
    "chore: release 1.1.0" "chore: tidy up" "docs: a guide" "Something without a type" \
    "feature: not a real type" "test: check more" "refactor(menu): move it" "ci: a ci change" \
    "Fix: upper case type" "FEAT(Menu): shouting" "fixed the menu"; do
    git -C "$N" commit -q --allow-empty -m "$message"
    if [ "$message" = base ]; then git -C "$N" tag v1.0.0; fi
done
sed -n '/commits="\$(git log/,/## 📝 Other/p' "$TEST_DIR/flow.sh" >"$TEST_DIR/sections.sh"
sections="$(cd "$N" && previous=v1.0.0 bash "$TEST_DIR/sections.sh")"
heading() { sed -n "/^## .*$1\$/,/^\$/p" <<<"$sections" | grep '^- ' | paste -sd'|'; }
is "notes: features" "$(heading 'New features')" "- Shouting|- Add a thing"
is "notes: fixes, any case" "$(heading Fixes)" "- Upper case type|- Lower case start|- Break and fix"
is "notes: docs" "$(heading Docs)" "- A guide"
is "notes: refactors" "$(heading Refactors)" "- Move it"
is "notes: tests" "$(heading Tests)" "- Check more"
is "notes: chores, without the release" "$(heading Chores)" "- Tidy up"
is "notes: anything else, as written" "$(heading Other)" "- fixed the menu|- ci: a ci change|- feature: not a real type|- Something without a type"

git init -q "$TEST_DIR/fixes-only"
git -C "$TEST_DIR/fixes-only" commit -q --allow-empty -m base
git -C "$TEST_DIR/fixes-only" tag v1.0.0
git -C "$TEST_DIR/fixes-only" commit -q --allow-empty -m "fix: one"
only="$(cd "$TEST_DIR/fixes-only" && previous=v1.0.0 bash "$TEST_DIR/sections.sh")"
is "notes: no empty headings" "$(grep -c '^## ' <<<"$only")" "1"

finish
