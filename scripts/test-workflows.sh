#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Exercise the real run script with a fake builder and launcher. These tests
# must never compile, launch, stop, or register a real application.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hocusfocus-workflows.XXXXXX")"
fixture="${fixture:A}"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/bin"
cp scripts/run-app.sh "$fixture/scripts/run-app.sh"
cp scripts/reset-accessibility.sh "$fixture/scripts/reset-accessibility.sh"
cp justfile "$fixture/justfile"
cat > "$fixture/scripts/build-app.sh" <<'SH'
#!/bin/zsh
set -eu
print built >> "$HOCUSFOCUS_TEST_BUILD_LOG"
if [[ "${HOCUSFOCUS_TEST_BUILD_FAIL:-0}" == 1 ]]; then exit 99; fi
mkdir -p dist/HocusFocus.app/Contents/MacOS
touch dist/HocusFocus.app/Contents/MacOS/HocusFocus
chmod +x dist/HocusFocus.app/Contents/MacOS/HocusFocus
SH
mkdir -p "$fixture/dist/HocusFocus.app/Contents/MacOS"
cat > "$fixture/dist/HocusFocus.app/Contents/MacOS/HocusFocus" <<'RAW'
#!/bin/zsh
print -u2 'ERROR: raw executable launched without LaunchServices'
exit 99
RAW
chmod +x "$fixture/dist/HocusFocus.app/Contents/MacOS/HocusFocus"
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 1
SH
cat > "$fixture/bin/open" <<'SH'
#!/bin/zsh
printf '%s\n' "$@" > "$HOCUSFOCUS_TEST_LAUNCH_LOG"
SH
chmod +x "$fixture/bin/pgrep" "$fixture/bin/open"
export HOCUSFOCUS_TEST_BUILD_LOG="$fixture/build.log"
export HOCUSFOCUS_TEST_LAUNCH_LOG="$fixture/launch.log"
export PATH="$fixture/bin:$PATH"

just --justfile "$fixture/justfile" run
[[ ! -e "$fixture/build.log" ]]
launch_args=("${(@f)$(< "$fixture/launch.log")}")
[[ ${#launch_args} == 3 ]]
[[ "$launch_args[1]" == -g && "$launch_args[2]" == -n ]]
[[ "$launch_args[3]" == "$fixture/dist/HocusFocus.app" ]]

# An existing instance must be left alone, with no rebuild or second launch.
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 0
SH
rm "$fixture/launch.log"
if zsh "$fixture/scripts/run-app.sh" > "$fixture/rejection.log" 2>&1; then
    print -u2 'Expected run to reject an already running instance.'
    exit 1
fi
[[ ! -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]

# Run must report a missing build without building or launching.
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 1
SH
rm "$fixture/dist/HocusFocus.app/Contents/MacOS/HocusFocus"
if zsh "$fixture/scripts/run-app.sh" > "$fixture/missing.log" 2>&1; then
    print -u2 'Expected run to reject a missing build.'
    exit 1
fi
[[ ! -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]
[[ "$(< "$fixture/missing.log")" == *'just start'* ]]

# Start must build from a fresh checkout and then launch.
just --justfile "$fixture/justfile" start
[[ -e "$fixture/build.log" && -e "$fixture/launch.log" ]]
[[ "$(< "$fixture/build.log")" == built ]]

# Failed builds must never launch an old app.
rm "$fixture/build.log" "$fixture/launch.log"
if HOCUSFOCUS_TEST_BUILD_FAIL=1 just --justfile "$fixture/justfile" start > "$fixture/failure.log" 2>&1; then
    print -u2 'Expected run to stop after a failed build.'
    exit 1
fi
[[ -e "$fixture/build.log" && ! -e "$fixture/launch.log" ]]
# Permission resets use a fake tccutil, never the user's real TCC database.
cat > "$fixture/bin/tccutil" <<'SH'
#!/bin/zsh
[[ "$*" == 'reset Accessibility io.bitsugar.hocusfocus' ]] || exit 98
case "${TEST_RESET_MODE:-success}" in
    success) print 'Successfully reset Accessibility approval status' ;;
    missing) print -u2 'tccutil: No such bundle identifier "io.bitsugar.hocusfocus": (OSStatus error -10814.)'; exit 64 ;;
    failure) print -u2 'Permission reset failed'; exit 64 ;;
esac
SH
chmod +x "$fixture/bin/tccutil"
just --justfile "$fixture/justfile" clean > "$fixture/reset-success.log"
TEST_RESET_MODE=missing just --justfile "$fixture/justfile" clean > "$fixture/reset-missing.log"
[[ "$(< "$fixture/reset-missing.log")" == *'no Accessibility reset is needed'* ]]
if TEST_RESET_MODE=failure just --justfile "$fixture/justfile" clean > "$fixture/reset-failure.log" 2>&1; then
    print -u2 'Expected clean to preserve an unrelated reset failure.'
    exit 1
fi
[[ "$(< "$fixture/reset-failure.log")" == *'Permission reset failed'* ]]
print '3 Accessibility reset fixture checks passed (success, unregistered app, unrelated failure).'

print '5 workflow tests passed (run without building, existing-instance protection, missing build, start builds and launches, and build failure).'
