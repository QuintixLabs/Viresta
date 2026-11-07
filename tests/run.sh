#!/usr/bin/env bash

# run.sh
# Runs every test, or only the folders and files named, like tests/run.sh updates.
# The shared folder is what the tests use, so nothing in it is run.

set -uo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\e[0m' C_OK=$'\e[38;5;42m' C_ERR=$'\e[38;5;203m' C_DIM=$'\e[38;5;245m'
else
    C_RESET="" C_OK="" C_ERR="" C_DIM=""
fi

# ------------------------------------------------------------
# Which tests
# ------------------------------------------------------------

list_tests() {
    find "$1" -name '*.sh' ! -path "$TESTS_DIR/shared/*" ! -path "$TESTS_DIR/run.sh" | sort
}

tests=()
if [ $# -eq 0 ]; then
    mapfile -t tests < <(list_tests "$TESTS_DIR")
else
    for name in "$@"; do
        name="${name#tests/}"
        if [ -d "$TESTS_DIR/$name" ]; then
            mapfile -t -O "${#tests[@]}" tests < <(list_tests "$TESTS_DIR/$name")
        elif [ -f "$TESTS_DIR/$name" ]; then
            tests+=("$TESTS_DIR/$name")
        elif [ -f "$TESTS_DIR/$name.sh" ]; then
            tests+=("$TESTS_DIR/$name.sh")
        else
            printf 'No test called %s\n' "$name" >&2
            exit 2
        fi
    done
fi

# ------------------------------------------------------------
# Running
# ------------------------------------------------------------

total_ok=0
total_failed=0
broken=0

# Every test has its own throwaway folder, so they all run at the same time. The results
# are still shown in order, once each one is done. setsid keeps each test away from the
# terminal you run this in, since two tests using it at once can get each other stuck.
# Tests that need a terminal make their own with script.
TEST_TIMEOUT="${TEST_TIMEOUT:-240}"

# Each test starts with only these, so nothing set on this computer, like a USE_ variable
# that looks like one of Viresta's options, can change what it does. The tests set HOME,
# TERM and LANG themselves.
CLEAN_ENV=(HOME="$HOME" PATH="$PATH")
[ -z "${TMPDIR:-}" ] || CLEAN_ENV+=(TMPDIR="$TMPDIR")
[ -z "${LD_LIBRARY_PATH:-}" ] || CLEAN_ENV+=(LD_LIBRARY_PATH="$LD_LIBRARY_PATH")
RESULTS="$(mktemp -d)"
trap 'rm -rf "$RESULTS"' EXIT

# seconds_since <start>: how long ago that was, like 4.2s.
seconds_since() {
    awk -v start="$1" -v now="$EPOCHREALTIME" 'BEGIN { printf "%.1fs", now - start }'
}

started="$EPOCHREALTIME"
for i in "${!tests[@]}"; do
    {
        test_started="$EPOCHREALTIME"
        # A stuck test is stopped after a while, so the run still ends and says which one.
        status=0
        timeout -k 10 "$TEST_TIMEOUT" env -i "${CLEAN_ENV[@]}" setsid bash "${tests[$i]}" </dev/null >"$RESULTS/$i.out" 2>&1 || status=$?
        if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
            printf 'Stuck, so it was stopped after %ss\n' "$TEST_TIMEOUT" >>"$RESULTS/$i.out"
        fi
        echo "$status" >"$RESULTS/$i.status"
        seconds_since "$test_started" >"$RESULTS/$i.time"
    } &
done
wait
took="$(seconds_since "$started")"

for i in "${!tests[@]}"; do
    test="${tests[$i]}"
    name="${test#"$TESTS_DIR"/}"
    output="$(cat "$RESULTS/$i.out")"
    status="$(cat "$RESULTS/$i.status")"

    passed="$(grep -c '^ok ' <<<"$output")"
    failed="$(grep -c '^FAIL ' <<<"$output")"
    skipped="$(grep -c '^skip ' <<<"$output")"
    total_ok=$((total_ok + passed))
    total_failed=$((total_failed + failed))

    line="$(printf '%-26s %6s  %4s ok' "$name" "$(cat "$RESULTS/$i.time")" "$passed")"
    if [ "$failed" -gt 0 ]; then
        printf '%s%s, %s failed%s\n' "$C_ERR" "$line" "$failed" "$C_RESET"
        # Each FAIL with the detail lines under it.
        awk '/^FAIL /{show=1; print "  " $0; next} /^     /{if (show) print "  " $0; next} {show=0}' <<<"$output"
    elif ! grep -q '^=== ' <<<"$output"; then
        # Stopped before the end, so the last lines say why.
        broken=$((broken + 1))
        printf '%s%s, stopped early%s\n' "$C_ERR" "$line" "$C_RESET"
        tail -n 5 <<<"$output" | sed 's/^/  /'
    elif [ "$skipped" -gt 0 ]; then
        printf '%s, %s skipped%s\n' "$line" "$skipped" "$C_RESET"
        grep '^skip ' <<<"$output" | sed "s/^/  $C_DIM/; s/\$/$C_RESET/"
    else
        printf '%s%s%s\n' "$C_OK" "$line" "$C_RESET"
    fi

    if [ "$status" -ne 0 ] && [ "$failed" -eq 0 ] && grep -q '^=== ' <<<"$output"; then
        broken=$((broken + 1))
    fi
done

printf '\n=== %s ok, %s failed' "$total_ok" "$total_failed"
if [ "$broken" -gt 0 ]; then
    printf ', %s stopped early' "$broken"
fi
printf ' in %s\n' "$took"

[ "$total_failed" -eq 0 ] && [ "$broken" -eq 0 ]
