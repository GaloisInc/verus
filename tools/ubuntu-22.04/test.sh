#!/usr/bin/env bash
set -euo pipefail

source /etc/os-release
test "$ID" = ubuntu
test "$VERSION_ID" = 22.04
printf '%s\n' "$PRETTY_NAME"
ldd --version | head -n 1
verus --version
z3 --version

temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT

verus --crate-type=lib src/lib.rs --compile --out-dir "$temporary_dir" \
    -V no-solver-version-check
test -f "$temporary_dir/liblib.rlib"

sed 's/result == value + 1/result == value + 2/' src/lib.rs > "$temporary_dir/invalid.rs"
if verus --crate-type=lib "$temporary_dir/invalid.rs" -V no-solver-version-check \
    > "$temporary_dir/invalid.log" 2>&1; then
    echo 'ERROR: Verus accepted an invalid postcondition' >&2
    exit 1
fi
cat "$temporary_dir/invalid.log"
grep -q 'postcondition not satisfied' "$temporary_dir/invalid.log"
echo 'PASS: valid crate verified and compiled; invalid postcondition rejected'
