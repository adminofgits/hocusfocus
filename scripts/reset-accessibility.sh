#!/bin/zsh
set -euo pipefail

# Only suppress LaunchServices' specific unregistered-bundle error.
if output="$(tccutil reset Accessibility io.bitsugar.hocusfocus 2>&1)"; then
    print -r -- "$output"
else
    reset_status=$?
    if [[ "$reset_status" == 64 && "$output" == *'No such bundle identifier "io.bitsugar.hocusfocus"'* && "$output" == *'OSStatus error -10814'* ]]; then
        print 'HocusFocus is not registered with macOS; no Accessibility reset is needed. Use just start to build and launch it.'
    else
        print -ru2 -- "$output"
        exit "$reset_status"
    fi
fi
