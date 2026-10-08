This regression covers optional boolean properties with `default: true`,
`default: false`, and no default. It compares the generated sources with
`expected.txt`, then compiles freshly generated sources and parses five JSON
objects to verify omitted fields and explicit overrides.

From the repository root, build and run with Alire:

```sh
alr -C tools/json_schema build
alr -C tools/json_schema exec -- make -C "$(pwd)/testsuite/json_schema" \
    boolean_defaults-run boolean-defaults-check \
    JSON_GEN="$(pwd)/.objs/release/tools/gen_json"
```

The executable path can vary with the build profile; set `JSON_GEN` to the
`gen_json` executable produced by the build.
