---
name: jac-packages
description: Add, lock, write and publish Jac packages (org/name libraries and templates). Use for [dependencies], jac.lock, exports, jac publish and registry questions.
---

A Jac package is a library of Jac code under a scoped name (`acme/graphkit`), imported as `acme.graphkit`. It can hold server, client and native code together and carries its own PyPI/npm requirements. `jac install` resolves the graph (one version per package), pins it in `jac.lock`, fetches packages into the machine-wide store and mounts them under `.jac/packages/<org>/<name>`.

## Consuming

```toml
[dependencies]                      # Jac packages ONLY (org/name)
"jaseci/vecdb" = "^2.1"             # caret by default: >=2.1.0, <3.0.0 (below 1.0, ^0.3 means <0.4)
"acme/util" = { path = "../util" }
"acme/fork" = { git = "https://github.com/acme/fork", rev = "v1.2.0" }

[dependencies.pypi]                 # Python packages live here, never under [dependencies]
numpy = ">=2"
```

```
jac install jaseci/vecdb      # add + resolve + lock + install (records ^X.Y.Z)
jac install                   # sync everything; keeps locked versions
jac install --frozen          # CI: exactly jac.lock, fail if stale
jac update [org/name]         # re-resolve within ranges
jac remove org/name
```

`import from jaseci.vecdb { Index }` - the import path is the name with `/` -> `.`. Importing a module the package does not list in its `exports` is E2096. Commit `jac.lock`; never hand-edit it.

## Writing a package

```toml
[project]
name = "acme/graphkit"                       # scoped name makes it a package
version = "1.4.0"                            # semver
jac-version = ">=0.38"
exports = ["graphkit", "graphkit.walkers"]   # module paths relative to the package root

[project.urls]
repository = "https://github.com/acme/graphkit"   # required to publish
```

- Inside the package, import its own modules by the qualified name (`import from acme.graphkit.walkers { Crawl }`) or relatively (`import from .walkers { Crawl }`). A bare `import from walkers` that lands in the package's own tree is E2095 (the file would load twice under two names). `jac install` mounts the package under its own name so qualified imports work during development.
- A published package may only depend on registry packages (no `path`/`git`).
- Compile-time `embed_file` can only read inside the package root.

## Publishing

```
jac publish --dry-run        # build + gates + API diff, upload nothing
jac publish                  # opens a PR on the index (github.com/jaseci-labs/jac-index)
jac publish --yank 1.2.0     # PR marking a version yanked
```

Gates: new semver version, `jac check` clean, registry-only deps, public source URL, and **semver enforced from the exported API**: removing/changing a function, parameter, field or ability needs a major bump (a changed `has` on a node/edge is also flagged as a persistence-schema change); additions need a minor bump. There is no override. Uses `GITHUB_TOKEN`/`GH_TOKEN`/`gh auth token`.

## Templates

A project with a `[jacpack]` table (`name = "acme/starter"`, `version = "1.0.0"`, `description`) is a template: `jac build --as jab` builds it, `jac publish` publishes it, `jac create app --use acme/starter[@range]` uses it. Registry templates cannot run a post-create hook.

## Pitfalls

- `jac install numpy` (no slash, no `--pypi`) is an error - it would be ambiguous. Use `jac install --pypi numpy`.
- An old manifest with PyPI names under `[dependencies]` fails to load: run `jac fix dependencies`.
- `jac build --as wheel` / `--as npm` export a library to Python / JS consumers; they are not how Jac projects share Jac code.
