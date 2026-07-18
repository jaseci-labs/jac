---
name: jac-packaging
description: Packaging a Jac project as a wheel and publishing it to PyPI, and npm packages via `jac build --as npm` - jac.toml metadata, the package-directory layout, console-script entry points, extras, precompiled bytecode, twine/npm upload. Load when turning a project into a pip-installable CLI tool, an importable library, or an npm component library. Pair with `jac-scaffold` (creating the project) and `jac-impl-files` (source layout).
---

`jac build --as wheel` builds a standard PEP 427 wheel plus an sdist (`dist/<name>-<version>-py3-none-any.whl`, `dist/<name>-<version>.tar.gz`) straight from `jac.toml` - no `setup.py`, no `pyproject.toml`. Upload with `twine`. `jac build --as npm` builds an npm tarball from the same `jac.toml`. This covers three shapes: a **CLI tool** (installs a terminal command), an **importable library** (consumed under the `jac` binary, then `import`), and an **npm component library**.

## The package directory - REQUIRED

The wheel build packages a directory whose name matches `project.name` (hyphens become underscores: `my-tool` -> `my_tool/`). The `jac create` default template puts `main.jac` at the project ROOT with no such directory - that layout does NOT produce an importable package. Create the package dir yourself:

```
greet/                  <- project root (holds jac.toml)
  jac.toml
  README.md
  greet/                <- package dir, name matches project.name
    cli.jac             <- your code, normal Jac
```

**A single top-level `.jac`/`.py` file is never collected** - `packages` matches directories only. A directory containing just `__init__.jac` is enough.

## jac.toml for distribution

```toml
[project]
name = "greet"
version = "0.1.0"
description = "A tiny Jac CLI app"
authors = [{name = "Jane Dev", email = "jane@example.com"}]
readme = "README.md"
requires-python = ">=3.11"
license = "MIT"
keywords = ["cli", "greeting"]
classifiers = [
  "Programming Language :: Python :: 3",
  "License :: OSI Approved :: MIT License",
]

[project.urls]
Homepage = "https://example.com/greet"

[entrypoints.scripts]
greet = "greet.cli:main"

[dependencies]
rich = ">=13.0.0"

[optional-dependencies.data]
pymongo = ">=4.0,<5.0"
```

- **`[project]`** -> wheel `METADATA`. The TOML key is **`requires-python`** (hyphen), not `requires_python` - the underscore form is silently ignored and never reaches `METADATA`.
- **`classifiers` must be a TOML array** (`[...]`). A plain string is a TOML type error and produces malformed wheel metadata.
- **`[dependencies]`** -> `Requires-Dist` in the wheel. **Do NOT list `jaclang` as a dependency** - it is not a PyPI package and cannot be installed that way. `jaclang` is provided by the host `jac` binary that runs your wheel; the `.jac` importer ships inside that binary. Consumers install your wheel into a project managed by the `jac` binary (`jac install <yourpkg>`), not a bare `pip install` in a plain Python env. `[dev-dependencies]` ship as a `dev` extra, not as runtime requirements.
- **`[optional-dependencies.<group>]`** -> wheel extras: consumers `pip install greet[data]`; during development `jac install --extras data`.
- **`[entrypoints.scripts]`** -> `console_scripts` in `entry_points.txt`. Format is `command = "package.module:function"`. The function is called with no arguments; read `sys.argv` for CLI args. Omit this whole section for a pure library. (Jac no longer loads any entry-point group at startup - there is no plugin system - but any other `[entrypoints.<group>]` table is written through to the wheel metadata for consumers that use `importlib.metadata`.)

## Build and publish

```
jac build --as wheel             # -> dist/greet-0.1.0-py3-none-any.whl + .tar.gz sdist
jac build --as wheel -o /tmp/wheels         # custom output dir
twine upload --repository testpypi dist/*   # TestPyPI first - verify the listing renders
twine upload dist/*              # then the real index
```

There is no `jac publish` command - use `twine` (separate pip install). In CI authenticate with a token: `twine upload dist/* -u __token__ -p "$PYPI_TOKEN"`. Consumers then install it into a project managed by the `jac` binary (`jac install greet`); the CLI command `greet` is on `PATH`, or `import greet` works for a library running under the `jac` binary.

`jac build` runs the whole-program type-check gate first and refuses to emit an artifact on failure - `--no_typecheck` skips the gate, `--check_only` runs it and emits nothing. Pre-compiled `.jir` bytecode in the package dir is collected into the wheel (the default collection patterns include `**/*.jir`), so consumers with matching bytecode skip first-import compilation; if bytecode is missing or stale the runtime transparently falls back to compiling the bundled `.jac` source, so a mismatch never breaks the package.

## Publishing to npm

`jac build --as npm` compiles client modules (`.cl.jac` and plain `.jac` under the package dir) to ES-module JavaScript, generates `package.json` + a `.d.ts` per module (TypeScript consumers get full type-checking), and packs `dist/<name>-<version>.tgz`. To produce both a wheel and an npm tarball, run both commands - there is no combined projection.

```toml
[npm]
name = "@yourscope/greetui"     # scoped npm name (defaults to normalized project name)
entry = "greetui/index.cl.jac"  # entry module (defaults to an index.* module)
```

- Modules that use JSX or the reactive API automatically get `@jaseci/runtime` wired into `dependencies` (a normal, React-independent npm package). Modules that explicitly `import from react` get `react`/`react-dom` as `peerDependencies`.
- **sv-boundary rejection**: a module with an `sv` import/call cannot run from a plain `npm install`, so the build fails with `'<file>' crosses a server boundary and cannot be published as a standalone npm package. npm packages must be pure client code`. Keep server-coupled code in your app, not the library.
- `jac` builds the tarball only - upload with `npm publish dist/<name>-<version>.tgz --access public` (CI: `NODE_AUTH_TOKEN`).

## What lands in the wheel

The wheel build collects `*.jac`, `*.py`, `*.pyi`, `*.lark`, `py.typed`, and `*.jir` from the package directory. It excludes `.jac/`, `__pycache__/`, `dist/`, `build/`, `venv/.venv/env/`, `.git/`, and `node_modules/`. To package extra directories or override patterns, use `[project.include]` with `packages` and `data` keys.

## Editable installs (local development)

```
jac install -e .            # install the current project editable
jac install -e /path/to/lib # install a cloned library editable
```

## Pitfalls

- **No package directory = empty/unimportable wheel.** The `default` scaffold's root-level `main.jac` is for `jac run`, not for distribution. Move code into a `<name>/` package dir (single top-level files are not collected).
- **Do NOT add `jaclang` to `[dependencies]`.** `jaclang` is not a PyPI package - it is the host runtime supplied by the `jac` binary that runs your wheel, and the `.jac` importer ships in that binary. Wheels are consumed under the `jac` binary (`jac install <yourpkg>`), not a bare `pip install` in a plain Python env.
- **`requires_python` (underscore) is dropped.** Use `requires-python`. Same hyphen-vs-underscore trap does NOT apply to `classifiers` - there the trap is string-vs-array.
- **Entry-point path is the install-time module path**, e.g. `greet.cli:main` - it must match the package dir name, not the source folder you happened to develop in.
- **First run of an installed Jac command prints `Jac setup complete! (N modules compiled and cached)`** while jaclang compiles its own cache. One-time and harmless (avoid by shipping `.jir` bytecode in the package).
- **`jac build --as wheel` fails with `[project] name is missing`** if `jac.toml` has no `name` - it is required for the wheel filename and `.dist-info`.
- **The type-check gate blocks the build** if the project fails `jac check` - fix the reported diagnostics or (as a last resort) pass `--no_typecheck`.

## See also

- `jac-scaffold` - `jac create`, templates, the `default` template's layout
- `jac-config` - the full `jac.toml` section map (`[dependencies]`, extras, `[npm]`)
- `jac-npm-packages` - CONSUMING npm packages in client code (this skill covers publishing)
- `jac-impl-files` - splitting `.jac` / `.impl.jac` within the package
