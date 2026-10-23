This regression covers schemas generated from TypeScript declarations
(for instance, by `ts-json-schema-generator` from `discord-api-types`):

* `$ref` with percent-encoded names and names that are not Ada identifiers
  (`BaseChannel<0>`), enumeration literals like `messages.read`, a property
  named `0`;
* numeric `enum`, single value `const`, `number` type mapped to
  `Integer_64` (`--numbers-as-integers`);
* aliases of simple types (`Snowflake`) and of other types
  (`TextChannel`), including arrays of aliases;
* nullable references `anyOf: [X, {type: null}]`, nullable strings and
  properties of `null` type;
* unions with a string discriminator other than `kind`, with a numeric
  discriminator and without any discriminator (`Any_Value`);
* an optional recursive property with `--holder`;
* a custom key lookup generic (`--hash-package`).

It compares the generated sources with `expected.txt`, then compiles freshly
generated sources and parses/writes a message to check the runtime behavior
(discriminators that are not the first key, null values, etc).

From the repository root, build and run with Alire:

```sh
alr -C tools/json_schema build
alr -C tools/json_schema exec -- make -C "$(pwd)/testsuite/json_schema" \
    typescript-run typescript-check \
    JSON_GEN="$(pwd)/.objs/release/tools/gen_json"
```
