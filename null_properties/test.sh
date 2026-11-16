#!/usr/bin/env bash
set -eu

generator=$(realpath "$1")
test_dir=$(cd "$(dirname "$0")" && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cd "$build_dir"
"$generator" --root-type Sample "$test_dir/schema.json" > generated.txt
gnatchop -gnat2022 generated.txt .
cp "$test_dir/../default.gpr" "$test_dir/../minimal_perfect_hash.ads" \
    "$test_dir/../minimal_perfect_hash.adb" "$test_dir/test_null_properties.adb" .
gprbuild -q -P default.gpr test_null_properties.adb
./test_null_properties
