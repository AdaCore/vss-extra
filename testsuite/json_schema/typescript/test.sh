#!/usr/bin/env bash
set -eu

generator=$(realpath "$1")
test_dir=$(cd "$(dirname "$0")" && pwd)
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cd "$test_dir"
"$generator" `cat cmd.txt` > "$build_dir/generated.txt"

cd "$build_dir"
gnatchop -gnat2022 generated.txt .
cp "$test_dir/../default.gpr" "$test_dir/typescript.ads" \
    "$test_dir/key_lookups.ads" "$test_dir/key_lookups.adb" \
    "$test_dir/test_typescript.adb" .
gprbuild -q -P default.gpr test_typescript.adb
./test_typescript
