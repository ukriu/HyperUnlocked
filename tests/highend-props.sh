#!/bin/sh
set -eu

# Exercise the same property-group writer used by installation and WebUI updates.
MODDIR=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/../module" && pwd)}
log() { :; }
eval "$(sed -n '/^write_props() {$/,/^}$/p' "$MODDIR/utils.sh")"
output=$(mktemp)
trap 'rm -f "$output"' EXIT HUP INT TERM
write_props "$output" highend

property() {
    awk -F= -v key="$1" '$1 == key { count++; value=$2 }
        END { if (count != 1) exit 1; print value }' "$output"
}

# The native V2 API invalidates all capabilities if any of its three tiers is invalid.
for name in cpulevel gpulevel devicelevel; do
    value=$(property "persist.sys.computilityV2.$name")
    case "$value" in
        1|2|3|4) ;;
        *) echo "Invalid Computility V2 $name: $value (expected 1-4)" >&2; exit 1 ;;
    esac
done

# Keep the legacy API's existing high-end defaults for older launchers.
for name in cpulevel gpulevel; do
    test "$(property "persist.sys.computility.$name")" = 6
done
test "$(property persist.sys.computility.version)" = 2025
test "$(property persist.sys.computilityV2.version)" = 2026
echo 'High-end property generation: PASS'
