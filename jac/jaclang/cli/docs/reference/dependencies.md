# Dependencies

Jac projects depend on other Jac projects two ways: through PyPI (Python
packages, covered by [Configuration](config/index.md#dependencies)) and
through **pure-Jac dependencies** -- Jac source fetched from git or linked
from a local path, resolved, pinned, and imported without pip. This page
covers the pure-Jac surface: `[dependencies.jac]`, the content-addressed
store, `jac.lock`, and the `jac install` / `jac update` / `jac why` /
`jac remove` commands that drive them.

## Declaring pure-Jac dependencies

Pure-Jac dependencies live in the `[dependencies.jac]` section of
`jac.toml` (dev-only entries in `[dev-dependencies.jac]`). Each entry is
an inline table with either a `git` or a `path` source:

```toml
[dependencies.jac]
utils = { git = "github.com/you/utils", branch = "main" }
widget = { git = "https://github.com/you/widget.git", tag = "v1.2.0" }
parser = { git = "github.com/you/parser", commit = "e4a1c9b09c14e0d47b0e47e50e2c4d3fd0b91a55" }
local = { path = "../local" }

[dev-dependencies.jac]
fixtures = { path = "../fixtures" }
```

Accepted ref fields, in decreasing precedence for locking:

- `commit` -- a 40-hex git SHA; replayed exactly.
- `branch`, `tag`, or `ref` -- a floating ref; resolved at install time
  and pinned by SHA in `jac.lock`.
- neither -- tracks the remote's default branch.

An optional `version` field constrains the dependency's `[project]
version` in its `jac.toml`:

- `^1.2.3` -- caret: `>=1.2.3`, `<2.0.0`; `^0.2.3` stays within `0.2.x`;
  `^0.0.3` allows only `0.0.3`.
- `1.2.3` or `=1.2.3` -- exact.

Any other constraint form (`>=`, `~`, `*`, ranges) is an error, so an
unrecognized spec can never silently match.

Names must be a single safe path component (no `/`, `\`, `:`, control
characters, `.`/`..`, or Windows reserved names like `CON` or `COM1`).

## Installing

```text
jac install                          # install everything declared
jac install jac:<url>[@ref]          # add a git dependency
jac install jac:./path/to/pkg        # add a path dependency
```

`jac install jac:...` parses the spec, records it in
`[dependencies.jac]`, resolves the full closure, materializes packages,
and rewrites `jac.lock` -- committing manifest, deps map, lock, and
`.jac/packages` together. A failed install leaves `jac.toml` untouched.

Useful flags:

- `--frozen` -- replay `jac.lock` exactly; fail if a row is missing or
  disagrees with the manifest (source, ref, or pinned commit). For CI
  and reproducible builds.
- `--dev` -- install dev-only pure-Jac dependencies (they are skipped by
  plain installs).
- `--dry-run` -- print what would be installed without materializing.
- `--no-save` -- install without recording the spec in `jac.toml` (and
  without writing a lock).

Git URLs accept the common shapes: `github.com/user/repo`,
`https://...`, `ssh://...`, `git@...`, `file://...`, and plain
filesystem paths. A trailing `.git` is stripped for remote URLs (so both
spellings dedupe to one dependency) and preserved for `file://` and
filesystem paths, where it is usually the real name of a bare
repository.

## Resolution and the store

Resolution is flat: every package in the closure resolves to one
version. Two requirers naming the same package with different refs,
commits, or sources is a hard conflict -- unless an `[override]` entry
replaces the dependency for the whole closure:

```toml
[override]
utils = { path = "../utils-patch" }
```

Git content is fetched into a shared, content-addressed store under the
Jac global directory (`$JAC_GLOBAL_DIR`, defaulting to `~/.jac`), keyed
by a tree hash of the package files. Identical content -- even from
different origins -- is stored once;
a hit is verified against the recorded hash before it is served, and a
corrupted or tampered entry is repaired by refetch. From the store,
packages are materialized into the project's `.jac/packages/<name>`
and their roots are added to the import path, so `import utils;` just
works. Path dependencies import in place (no copy).

Tags are checked against the remote before a store hit is trusted: a
moved tag fails the install with instructions to re-lock, and a branch
that moved past the recorded commit replays the recorded commit with a
warning.

## jac.lock

`jac install` (any form that resolves) writes `jac.lock` next to
`jac.toml`. Commit it. It records the resolved state so installs are
reproducible and `jac why` can answer questions offline:

```toml
version = 1

[jac.utils]
git = "github.com/you/utils"
ref = "main"
sha = "9b2a..."
tree = "sha256-3f1c..."
version = "1.4.0"
requested_by = ["root"]

[jac.parser]
git = "github.com/you/parser"
sha = "e4a1..."
tree = "sha256-88ab..."
requested_by = ["utils"]

[python]
requests = "==2.32.3"

[python_graph]
requests = ["root"]

[npm]
left-pad = "1.2.3"
```

For each pure-Jac dependency: the source (`git` or `path`), the locked
`ref`/`sha`, the content `tree` hash, the package `version`, and every
requirer (`requested_by`). Path dependencies record their absolute path
and tree hash; a frozen replay verifies the live content still hashes to
the recorded tree. The `python`, `python_graph`, and `npm` sections pin
the non-Jac ecosystems harvested from the venv and `node_modules`.

## Updating

```text
jac update            # advance main dependencies to the latest ref tip
jac update -d         # advance dev dependencies only
jac update utils      # advance one dependency and its transitive closure
```

`jac update` re-resolves floating refs to their current tips and reports
each change as `old -> new` SHAs. Everything outside the update scope
keeps its locked commit (minimal churn): a bare update advances the main
closure, `-d` advances the dev closure, and a targeted update advances
the named dependency plus everything reachable from it -- including
transitives that only became reachable through the update.

## Why is this installed?

```text
jac why urllib3
```

prints every reverse-dependency chain for a package from `jac.lock`,
labeled by ecosystem:

```text
Why urllib3 (python) is installed
  urllib3 (python) <- requests (python) <- root (python)
  1 chain(s)
```

`jac why` reads the lockfile only -- run `jac install` first if state is
missing.

## Removing

```text
jac remove utils
```

removes the entry from `jac.toml`, re-resolves the remaining closure
(rolling back the manifest if resolution fails), drops the materialized
package, and rewrites `jac.lock` and the deps map.

## Related

- [Configuration Reference](config/index.md) -- every `jac.toml` section.
- [Publishing Packages](publishing.md) -- shipping your package to PyPI.
- [CLI Commands](cli/index.md) -- the full command surface.
