#!/usr/bin/env bash
set -eu

generator=$(realpath "$1")
test_dir=$(cd "$(dirname "$0")" && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cd "$build_dir"
cp "$test_dir/../default.gpr" "$test_dir/../minimal_perfect_hash.ads" \
    "$test_dir/../minimal_perfect_hash.adb" "$test_dir/test_constant_aliases.adb" .

for option in '' '--numbers-as-integers'; do
    "$generator" ${option:+"$option"} --root-type Sample \
        "$test_dir/schema.json" > generated.txt
    gnatchop -w -gnat2022 generated.txt .
    gprbuild -q -P default.gpr test_constant_aliases.adb
    ./test_constant_aliases
done
