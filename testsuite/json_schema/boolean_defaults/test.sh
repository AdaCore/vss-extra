#!/usr/bin/env bash
set -eu

generator=$(realpath "$1")
test_dir=$(cd "$(dirname "$0")" && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cd "$build_dir"
"$generator" --root-package Boolean_Defaults.Types --root-type Settings \
    "$test_dir/schema.json" > generated.txt
gnatchop -gnat2022 generated.txt .
cp "$test_dir/../minimal_perfect_hash.ads" \
    "$test_dir/../minimal_perfect_hash.adb" \
    "$test_dir/../default.gpr" "$test_dir/boolean_defaults.ads" \
    "$test_dir/test_boolean_defaults.adb" .
gprbuild -q -P default.gpr test_boolean_defaults.adb
./test_boolean_defaults
