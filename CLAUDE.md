# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all unit tests
prove -Ilib -It/lib -r t/unit_tests/

# Run a single test file
perl -Ilib -It/lib t/unit_tests/SimpleMock.t
perl -Ilib -It/lib t/unit_tests/SimpleMock/Model/DBI.t

# Run top-level load/pod tests (make test only covers these, not unit_tests/)
make test

# Install dependencies
cpanm --installdeps .
```

## Architecture

### The mock stack

All mock data lives in `@SimpleMock::MOCK_STACK`, an array of hashrefs. Layer 0 is the base (process-global) layer written to by `register_mocks`. Each call to `register_mocks_scoped` pushes a new layer and returns a `ScopeGuard`; `ScopeGuard::DESTROY` removes that layer by reference identity (`Scalar::Util::refaddr`), making nested scopes safe regardless of exit order.

```
@MOCK_STACK = (
    { SUBS => {...}, DBI => {...} },   # layer 0 — register_mocks() writes here
    { SUBS => {...} },                  # layer 1 — pushed by register_mocks_scoped()
)
```

All mock lookups (`_get_return_value_for_args`, `_get_mock_for`, `_get_dbi_meta`, `_get_path_mock`) traverse the stack top-to-bottom and return the first match, giving scoped layers natural precedence over the base layer.

`_register_into_current_scope` (not exported) is an internal variant that writes to `$MOCK_STACK[-1]` instead of `$MOCK_STACK[0]`. Use this for side-effecting operations inside mock implementations that should respect the current scope (e.g. `Path::Tiny::copy`).

### Registration flow

`register_mocks(MODEL => $data)` → `_register_into_layer($layer, \%data)` → loads `SimpleMock::Model::MODEL`, calls `validate_mocks($data)` which validates input and returns a normalised hashref → that hashref is merged into the target layer in-place with `%$layer = %{ Hash::Merge::merge($processed, $layer) }`. The left-argument (`$processed`) wins on key conflicts, so a second `register_mocks` call for the same key overwrites the first within the same layer.

### Model plugins

Each mock type is a pair of files:

- **`lib/SimpleMock/Model/MODEL.pm`** — `validate_mocks($data)` transforms raw user input into the internal storage format and returns it. Also contains the lookup function(s) called at test runtime (e.g. `_get_mock_for`, `_get_dbi_meta`).
- **`lib/SimpleMock/Mocks/Some/Module.pm`** — patches the real module at load time (overrides methods via glob assignment). Lookup functions in this file call `_get_path_mock` or the corresponding `Model::*` function to resolve the stack.

To add a new model, create `lib/SimpleMock/Model/MYMODEL.pm` with a `validate_mocks` sub. The model key must be `ALL_CAPS` (enforced by `_register_into_layer`).

### Auto-loading mock files

`SimpleMock.pm` installs a `CORE::GLOBAL::require` override in a `BEGIN` block. Every module load is intercepted: after the real `require` completes, `_load_mocks_for` checks whether `SimpleMock/Mocks/$original_file.pm` exists and loads it if so. Any sub in the `SimpleMock::Mocks::*` namespace that matches a sub in the original namespace is automatically registered as a default SUBS mock. `_load_mocks_for` skips files whose path starts with `SimpleMock` to avoid recursion.

The override does **not** return a value, so callers must not rely on its return. Use `eval { require $file }; die $@ if $@` rather than `eval { require $file } or die`.

When `require` receives a variable containing `::` (not a bareword), Perl does not auto-convert `::` to `/`. Always convert explicitly: `(my $file = $ns) =~ s{::}{/}g; $file .= '.pm'`.

### SUBS delegation

The first time a sub is registered, `validate_mocks` installs a delegation wrapper: `*Foo::bar = sub { _get_return_value_for_args('Foo', 'bar', \@_) }`. This is tracked in `%SimpleMock::Model::SUBS::DELEGATED` and only installed once per sub. The original implementation is permanently replaced for the lifetime of the test process — calling a mocked sub after `clear_mocks` without re-registering will die.

Mock return values are keyed by SHA-256 of `Data::Dumper`-serialised args. An entry with no `args` key maps to the `_default` SHA and acts as a catch-all.

### DBI mocking

`SimpleMock::Mocks::DBI` overrides `DBI::connect` to force all connections through `DBD::SimpleMock` (the custom driver in `lib/DBD/SimpleMock.pm`). The driver's `execute`, `prepare`, and `connect` methods delegate to `SimpleMock::Model::DBI::_get_mock_for` and `_get_dbi_meta` for stack-aware lookups. SQL is normalised (lowercased, collapsed whitespace) before lookup.

### PATH_TINY mocking

`SimpleMock::Mocks::Path::Tiny` patches Path::Tiny methods via glob assignment. All lookups go through `_get_path_mock($path)`, which traverses `@MOCK_STACK`. `_get_path_mock` accepts both plain strings and Path::Tiny objects — the latter stringify correctly due to Path::Tiny's `""` overload. A path with a `data` attribute is treated as a file; without `data` it is a directory.
