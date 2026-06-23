# Vendored typeshed (stdlib stubs only)

The Python standard-library type stubs from typeshed. They are NOT committed:
`stdlib/` and `../../project/stub_index.json` are gitignored and rebuilt at the
pinned commit by `launcher/fetch-typeshed.sh` (which `build.zig` runs so the
`jac` binary bundles the stubs). Only this file, `PIN`, and `LICENSE` are tracked.

Third-party stubs are NOT shipped -- `jac add` installs the matching `types-*`
package into the project's `.jac/venv` (resolved via PEP 561 `<pkg>-stubs`).

- Source:  https://github.com/python/typeshed
- Commit:  bbbf7530a987e59c8458127351cacad2e57f04bf
- License: Apache-2.0 (see LICENSE)

To bump, run `launcher/update-typeshed.sh <commit>` and commit PIN + PROVENANCE.md.
