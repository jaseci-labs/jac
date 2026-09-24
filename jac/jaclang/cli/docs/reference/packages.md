# Packages

A Jac package is a reusable library of Jac code, published under a scoped name such as `acme/graphkit` and consumed with `jac install`. One package can hold server (`sv`), client (`cl`) and native (`na`) code together, and it can carry its own Python (PyPI) and npm dependencies. The consumer's `jac install` resolves the whole graph, pins it in `jac.lock`, and makes every package importable as `org.name`.

This page covers consuming packages, writing one, publishing it, and how the pieces fit.

## Consuming packages

### Declaring dependencies

`[dependencies]` in `jac.toml` lists Jac packages. Python packages live in `[dependencies.pypi]` and npm packages in `[dependencies.npm]`:

```toml
[project]
name = "my_app"
version = "0.1.0"

[dependencies]
"jaseci/vecdb" = "^2.1"
"acme/util" = { path = "../util" }
"acme/fork" = { git = "https://github.com/acme/fork", rev = "v1.2.0" }

[dependencies.pypi]
numpy = ">=2"

[dependencies.npm]
d3 = "^7"

[dev-dependencies]
"acme/testkit" = "^0.3"

[dev-dependencies.pypi]
pytest = ">=8"
```

A Jac dependency is either a version requirement string (from a registry) or a table with one source:

| Key | Meaning |
|-----|---------|
| `version` | A version requirement (see below); the default is any version |
| `path` | A directory holding the package's `jac.toml`, relative to this project |
| `git` | A git repository URL; `rev` picks a branch, tag or commit |
| `registry` | A registry named under `[registries]` instead of the default one |

Names are always scoped: `org/name`, both halves lowercase identifiers (`[a-z][a-z0-9_]*`).

!!! note "Migrating from the old `[dependencies]`"
    Before packages, `[dependencies]` held PyPI requirements. `jac.toml` now rejects a bare `numpy = ">=2"` under `[dependencies]` with an error that names the move. Run `jac fix dependencies` to move every PyPI entry (including the old `[dependencies.git]` table) into `[dependencies.pypi]`.

### Version requirements

Requirements follow semantic versioning with Cargo and npm syntax:

| Form | Example | Allows |
|------|---------|--------|
| Caret (the default) | `"^1.4.2"` or `"1.4.2"` | `>=1.4.2, <2.0.0` |
| Caret below 1.0 | `"^0.3.1"` | `>=0.3.1, <0.4.0` |
| Tilde | `"~1.4.2"` | `>=1.4.2, <1.5.0` |
| Wildcard | `"1.4.*"` | `>=1.4.0, <1.5.0` |
| Comparators | `">=1.2, <1.8"` | the intersection |
| Exact | `"=1.4.2"` | only 1.4.2 |
| Union | `"^1 \|\| ^3"` | either range |

Pre-release versions (`2.0.0-rc.1`) are only chosen when a requirement names one.

### Installing

```bash
jac install                          # resolve, lock and install everything
jac install jaseci/vecdb             # add the newest version as ^X.Y.Z, then install
jac install "jaseci/vecdb@^2.1"      # add with an explicit range
jac install --path ../util           # add a local package (its jac.toml names it)
jac install --git https://github.com/acme/fork --rev v1.2.0
jac install --pypi numpy             # add a Python package to [dependencies.pypi]
jac install --npm d3                 # add an npm package to [dependencies.npm]
jac install --frozen                 # install exactly jac.lock; fail if it is stale (CI)
jac update                           # re-resolve every package within its range
jac update jaseci/vecdb              # re-resolve one package
jac remove jaseci/vecdb
jac install --plan                   # show every dependency and where it came from
```

A bare name without a slash is not a Jac package: `jac install numpy` fails with a hint to use `--pypi`.

### What `jac install` does

1. **Resolves** the Jac package graph with a PubGrub solver: one version of each package per graph, the newest that satisfies every requirement. A version whose `jac-version` excludes the running compiler is skipped. When no solution exists, the error explains the chain of requirements that conflict.
2. **Locks** the result in `jac.lock` with the source and content hash of every package. Commit `jac.lock`; `jac install` keeps the locked versions until `jac.toml` changes or you run `jac update`.
3. **Fetches** each package into the machine-wide store (`~/.cache/jac/pkgs/<org>/<name>/<version>-<hash>/`), verifying its sha256. Nothing is copied into the project.
4. **Mounts** the graph under `.jac/packages/<org>/<name>` (links into the store), so `import from jaseci.vecdb { ... }` resolves.
5. **Installs the foreign dependencies** of the whole graph: every package's PyPI requirements go to one `pip install` into `.jac/venv`, and its npm requirements join the project's client build.

`jac.lock` also records the Python distributions pip chose (`[pypi].resolved`). A later `jac install` with the same inputs replays those exact pins; `jac update` re-resolves them.

### Importing

A package named `org/name` is imported as `org.name`:

```jac
import from jaseci.vecdb { Index }
import from acme.util.text { slugify }
```

A package decides which of its modules consumers may import through `[project] exports`. Importing a module a package does not export is an error at the import.

## Writing a package

A package is a project whose `[project]` has a scoped name, a semantic version and an `exports` list:

```toml
[project]
name = "acme/graphkit"
version = "1.4.0"
description = "Graph algorithms for Jac"
license = "MIT"
jac-version = ">=0.38"
exports = ["graphkit", "graphkit.walkers"]

[project.urls]
repository = "https://github.com/acme/graphkit"

[dependencies]
"jaseci/vecdb" = "^2.1"

[dependencies.pypi]
networkx = ">=3"
```

- **`exports`** lists module paths relative to the package root. Everything else is internal.
- **Imports inside the package** use the qualified name (`import from acme.graphkit.walkers { Crawl }`) or a relative import (`import from .walkers { Crawl }`). A bare `import from walkers` that resolves into the package's own tree is an error, because the same file would load under two module names. `jac install` mounts the package under its own name, so qualified imports work while you develop it.
- **Placement** stays inferred. A consumer whose client code calls into your package gets those functions compiled to JavaScript; pin modules in the package's own `[placement.pins]` if they must always run in one codespace (pinned modules also ship precompiled).
- **No code runs at install time.** Installing or compiling a package never executes it; compile-time `embed_file` can only read files inside the package.

## Publishing

```bash
jac publish --dry-run     # build, check and show the API diff; upload nothing
jac publish               # build and open the index pull request
```

`jac publish` builds a library `.jab` (the package source plus precompiled interfaces), then runs the publish gates:

- the name is scoped, the version is new, and `exports` is not empty
- `jac check` is clean under the package's own configuration
- every dependency comes from a registry (no `path` or `git` dependencies)
- `[project.urls] repository` names the public source repository
- **semver**: the exported API is compared with the latest release of the same major version. Removing or changing anything a consumer can use (a module, a function, a parameter, a field, an ability) needs a major bump; additions need at least a minor bump. A changed `has` field on a `node` or `edge` is also reported as a persistence schema change, since stored graphs may no longer load.

It then uploads the `.jab` as a release asset on your fork of the index repository and opens a pull request that adds one line to `index/<org>/<name>.json`. The index's CI re-runs the gates, copies the artifact into the index's immutable blob store, and merges. Published versions never change; `jac publish --yank <version>` opens a pull request that marks a version yanked, which stops new resolutions from choosing it while existing locks keep working.

Publishing uses your GitHub identity (`GITHUB_TOKEN`, `GH_TOKEN`, or `gh auth token`). An org is claimed by a pull request that adds `orgs/<org>.toml` to the index, listing the GitHub users allowed to publish under it.

## Registries

The default registry is the public index at [jaseci-labs/jac-index](https://github.com/jaseci-labs/jac-index). A registry is any directory or URL with this layout:

```
config.json                  {"protocol": 1, "blob_base": "...", "repo": "..."}
index/<org>/<name>.json      one JSON object per line, one line per version
```

and blobs named `<sha256>.jab` under `blob_base`. Point a project at another registry by name:

```toml
[registries]
internal = "https://raw.githubusercontent.com/acme/jac-index/main/"

[dependencies]
"acme/secret" = { version = "^1", registry = "internal" }
```

`JAC_REGISTRY` overrides the default registry's URL (a mirror, or a `file://` directory in tests), and `JAC_OFFLINE=1` resolves from cached index files and the store only.

## Templates

A project template (a jacpack) is a package too: a project with a `[jacpack]` table builds with `jac build --as jab` into a template-role `.jab` and publishes with `jac publish`. `jac create my-app --use acme/starter` fetches the newest template from the registry (`acme/starter@^2` picks a range); `--use` also takes a local directory or `.jab`. Templates from a registry cannot run a post-create hook.

## Apps built from packages

`jac build` seals an app's dependency packages into the app image, so a deployed `.jab`, binary or jac-scale app never resolves or downloads anything at run time.

## Exporting to Python and npm consumers

`jac build --as wheel` and `jac build --as npm` stay the way a Jac library reaches Python and JavaScript projects that do not use Jac. See [Publishing to PyPI and npm](publishing.md).
