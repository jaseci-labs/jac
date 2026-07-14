# Vendored typeshed (stdlib stubs only)

The Python standard-library type stubs from typeshed. They are NOT committed:
`stdlib/` is gitignored and rebuilt at the pinned commit by the `fetch-typeshed`
subcommand of `launcher/payload.zig` (which `build.zig` runs so the `jac` binary
bundles the stubs). Only this file, `PIN`, `TARBALL_SHA256`, and `LICENSE` are
tracked.

Integrity: `payload.zig` downloads the GitHub tarball for the pinned commit and
verifies the **decompressed tar's** sha256 against `TARBALL_SHA256` (git's
`archive` output is content-stable for a commit), so a swapped tarball cannot
slip in -- the same guarantee git's content-addressing gave the old `git fetch`.

Third-party stubs are NOT shipped: install the matching `types-*` package
yourself (`jac install types-foo`); it is resolved via PEP 561 `<pkg>-stubs`
from the project venv.

- Source:  https://github.com/python/typeshed
- Commit:  bbbf7530a987e59c8458127351cacad2e57f04bf
- License: Apache-2.0 (see LICENSE)

To bump:
1. Put the new commit SHA in `PIN`.
2. Get the new hash: `zig build` builds the tool, then
   `./.zig-cache/.../payload typeshed-sha <commit>` (or build it directly with
   `zig build-exe launcher/payload.zig`) and write the printed value into
   `TARBALL_SHA256`.
3. Update the Commit line above and commit `PIN`, `TARBALL_SHA256`, `PROVENANCE.md`.
