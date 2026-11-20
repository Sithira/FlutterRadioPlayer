#!/bin/sh
# Public ABI check for the Android core (KGP abiValidation produces no dump under
# AGP 9 built-in Kotlin). Usage: abi.sh check|update, after compileDebugKotlin.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
classes="$here/../../../example/build/flutter_radio_player_android/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes"
reference="$here/api/flutter_radio_player_android.api"
core="me/sithiramunasinghe/flutter/flutter_radio_player/core"

dump() {
    cd "$classes"
    find "$core/api" -name '*.class' | LC_ALL=C sort
    echo "$core/RadioPlayerClient.class"
    echo "$core/PlaybackService.class"
} 

current=$(dump | sed 's/\.class$//; s|/|.|g' | xargs javap -public -cp "$classes" | grep -v '^Compiled from' | grep -vE '^  .*\$[A-Za-z_]+(\(|;)')

case "${1:-check}" in
    update) printf '%s\n' "$current" > "$reference" ;;
    check) printf '%s\n' "$current" | diff -u "$reference" - ;;
    *) echo "usage: $0 check|update" >&2; exit 2 ;;
esac
