#!/usr/bin/env bash
set -eu

generator=$(realpath "$1")
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cd "$build_dir"
for option in '' '--numbers-as-integers'; do
    for value in 1.5 1.0 -1.5 1e0 1e1000 9223372036854775808; do
        cat > schema.json <<EOF
{
  "type": "object",
  "properties": { "value": { "type": "number", "const": $value } },
  "required": ["value"]
}
EOF
        if "$generator" ${option:+"$option"} --root-type Sample schema.json \
            > generated.txt 2> error.txt; then
            echo "Unexpected success for const: $value $option" >&2
            exit 1
        fi
        test ! -s generated.txt
        grep -Fq "Unsupported numeric const: $value" error.txt
    done

    for value in 0 1 -1 9223372036854775807 -9223372036854775808; do
        cat > schema.json <<EOF
{
  "type": "object",
  "properties": { "value": { "type": "number", "const": $value } },
  "required": ["value"]
}
EOF
        "$generator" ${option:+"$option"} --root-type Sample schema.json \
            > generated.txt
        test -s generated.txt
    done
done

# Ordinary floating-point properties and defaults remain supported.
cat > schema.json <<'EOF'
{
  "type": "object",
  "properties": { "value": { "type": "number", "default": 1.5 } },
  "required": ["value"]
}
EOF
"$generator" --root-type Sample schema.json > generated.txt
test -s generated.txt
