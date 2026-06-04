# Publishing Packages

Jac projects publish to [PyPI](https://pypi.org) as standard Python wheels -- no `pyproject.toml`, no `setuptools`, no `build` backend. The `jac bundle` command reads your `jac.toml` and produces a PEP 427-compliant `.whl` that `pip install` consumes directly. Anyone can then `pip install` your package, whether or not they use Jac.

This page covers the end-to-end flow: declaring metadata, building a wheel, testing it, and uploading it.

## Overview

The publishing pipeline has three steps:

1. **Declare** package metadata in the `[project]` section of `jac.toml`.
2. **Build** a wheel with `jac bundle` -- it lands in `dist/`.
3. **Upload** the wheel to PyPI with `twine` (upload is intentionally out of scope for `jac`).

Jac builds the wheel itself: it generates the `METADATA`, `WHEEL`, `RECORD`, `top_level.txt`, and `entry_points.txt` files and packs them into a reproducible ZIP archive. The result is indistinguishable from a wheel produced by `hatch` or `setuptools`.

## 1. Declare package metadata

All publishing metadata lives in the `[project]` section of `jac.toml`. Only `name` and `version` are strictly required; everything else improves the PyPI listing.

```toml
[project]
name = "mylib"
version = "1.0.0"
description = "A handy Jac library"
license = "MIT"
readme = "README.md"
requires-python = ">=3.12"
keywords = ["jac", "jaseci", "ai"]
classifiers = [
  "Programming Language :: Python :: 3",
  "License :: OSI Approved :: MIT License",
  "Framework :: Jac",
]
authors = [{ name = "Your Name", email = "you@example.com" }]
maintainers = [{ name = "Your Name", email = "you@example.com" }]

[project.urls]
homepage = "https://example.com"
repository = "https://github.com/you/mylib"
issues = "https://github.com/you/mylib/issues"

[dependencies]
jaclang = ">=0.15.1"
requests = ">=2.28.0"
```

Classifiers appear as `Classifier:` headers in the wheel's `METADATA` and control how your package is displayed and filtered on PyPI (license badge, Python version tags, topic categories). Browse the full list at [pypi.org/classifiers](https://pypi.org/classifiers/).

!!! warning "`classifiers` must be a TOML array"
    Writing `classifiers` as a plain string instead of an array is a TOML type
    error and will produce malformed wheel metadata. Always use `[...]` syntax
    as shown above.

Runtime dependencies declared under `[dependencies]` are written into the wheel's `METADATA` as `Requires-Dist` entries, so `pip install mylib` pulls them in automatically. `[dev-dependencies]` are **not** shipped. `[optional-dependencies.<group>]` become wheel extras (`pip install mylib[<group>]`).

See the [Configuration Reference](config/index.md#project) for the full field list.

!!! note "Migrated from `[package]`?"
    Releases before jaclang 0.15 used a separate `[package]` section for publishing metadata. It has been merged into `[project]`. If you have an old `jac.toml`, rename `[package]` → `[project]` and `[package.include]` → `[project.include]`; plain `[package]` tables are no longer read.

### Controlling what ships

By default `jac bundle` collects a single directory named after the project (`mylib/`, with hyphens converted to underscores). Override this with `[project.include]`:

```toml
[project.include]
packages = ["mylib", "mylib_extras"]

[project.include.data]
# Extra non-source files to bundle, per package
mylib = ["templates/**/*", "data/*.json"]
```

`.jac`, `.py`, `.pyi`, `.lark`, `py.typed`, and `.jir` files are included by default. Build artifacts (`.jac/`, `__pycache__/`, `dist/`, virtualenvs, `.git/`, `*.egg-info/`) are always excluded. See [`[project.include]`](config/index.md#projectinclude) for the full pattern reference.

!!! warning "Single-file modules"
    `[project.include]` `packages` matches **directories**. A package that is a single top-level `.py`/`.jac` file is not currently collected -- put your code in a directory (a `__init__.jac` is enough) before bundling.

### Console scripts and plugins

Declare CLI commands and Jac plugin entry points with `[entrypoints]`:

```toml
[entrypoints.scripts]
# `pip install mylib` adds a `mylib` command on PATH
mylib = "mylib.cli:main"

[entrypoints.jac]
# Auto-discovered by Jac's plugin system at startup
mylib = "mylib.plugin:JacRuntime"
```

`[entrypoints.scripts]` is written as `[console_scripts]` in the wheel; `[entrypoints.jac]` is the `jac` entry-point group queried by the plugin loader.

## 2. Build the wheel

```bash
jac bundle
```

This writes `dist/<name>-<version>-py3-none-any.whl`. Build to a different directory with `-o`:

```bash
jac bundle -o /tmp/wheels
```

`jac bundle` ships `.jir` bytecode files only if they already exist in your source tree -- it does not regenerate them. Use `--precompile` (`-p`) to compile `.jac` → `.jir` automatically for every `python3.X` interpreter found on `PATH` before packaging:

```bash
jac bundle --precompile
```

The flag creates an isolated venv per Python version, compiles all `.jac` sources inside it, and folds the resulting `.jir` files into the wheel. Shipped bytecode is keyed by Python version and validated against a source hash; if it is missing, incompatible, or stale, the runtime transparently falls back to compiling the bundled `.jac` source -- a mismatch never breaks the package.

Wheels are reproducible: every ZIP entry uses a fixed timestamp, so the same source produces a byte-identical wheel.

## 3. Test before uploading

Always install the wheel into a clean environment before publishing:

```bash
python -m venv test_env
source test_env/bin/activate
pip install dist/mylib-1.0.0-py3-none-any.whl
python -c "import mylib"   # or exercise your console script
deactivate
```

## 4. Upload to PyPI

`jac` does not upload -- use [`twine`](https://twine.readthedocs.io/):

```bash
pip install twine

# Upload to TestPyPI first to verify the listing renders correctly
twine upload --repository testpypi dist/*

# Then publish to the real index
twine upload dist/*
```

In CI, authenticate with an API token: `twine upload dist/* -u __token__ -p "$PYPI_TOKEN"`.

## Publishing to npm (npmjs.org)

Client-side Jac libraries can also be published to [npm](https://www.npmjs.com) so JavaScript and TypeScript projects can `npm install` them -- whether or not they use Jac. `jac bundle --target npm` reads the same `jac.toml` and produces an npm-compatible `.tgz`: it compiles your client modules to JavaScript (ES modules), generates `package.json`, and emits `.d.ts` TypeScript declarations.

```bash
jac bundle --target npm        # -> dist/<name>-<version>.tgz
jac bundle --target all        # build both the wheel and the npm tarball
```

What goes in the package:

- **Compiled JavaScript.** Every `.cl.jac` (and plain `.jac`) client module under `[project.include]` compiles to a sibling `.js`, preserving the import structure. `def:pub` / `glob:pub` symbols become ESM exports.
- **`package.json`.** Built from `[project]` (`name`, `version`, `description`, `license`, `keywords`, `repository`) plus `[dependencies.npm]`. Override npm-specific fields under `[npm]`:

    ```toml
    [npm]
    name = "@yourscope/mylib"   # scoped npm name (defaults to the normalized project name)
    entry = "mylib/index.cl.jac" # entry module (defaults to an index.* module)
    ```

- **TypeScript declarations.** A `.d.ts` is generated for each module and `package.json` `types`/`exports` point at the entry's declarations, so TypeScript consumers get full type-checking. Function signatures, `obj`/`node` classes, and globals are all typed; JSDoc is also embedded in the `.js`.

!!! note "Pure client code only"
    npm packages must be standalone client code. A module that crosses a server boundary (a `sv` import/call) can't run as a plain npm install, so `jac bundle --target npm` rejects it with a clear error. Keep server-coupled code in your app, not in the published library.

### The runtime dependency

Libraries that use JSX or the reactive API (`createSignal`, `createEffect`, …) reference the Jac client runtime. The build wires an `import { … } from "@jaseci/runtime"` into those modules and adds `@jaseci/runtime` to `dependencies` automatically. The runtime is a normal, React-independent npm package; modules that explicitly `import from react` instead get `react`/`react-dom` added to `peerDependencies`.

Maintainers publish the runtime itself with:

```bash
jac bundle --target npm-runtime   # builds @jaseci/runtime at the jaclang version
```

### Upload to npm

`jac` does not upload -- use the `npm` CLI:

```bash
npm pack dist/<name>-<version>.tgz   # optional: inspect the contents
npm publish dist/<name>-<version>.tgz --access public
```

In CI, authenticate with an automation token via `NODE_AUTH_TOKEN` (see the `publish-npm` job in `.github/workflows/publish-release.yml`, which publishes any package with an `[npm]` section).

## Editable installs

While developing a library locally, install it in editable mode so changes are picked up without rebuilding:

```bash
jac install -e .
```

This installs the project's runtime dependencies and writes a complete `.dist-info/` directory into `site-packages`, so `pip show mylib` and `pip list` report it correctly -- all without a `pyproject.toml`. You can also editable-install a cloned dependency from anywhere:

```bash
jac install -e /path/to/cloned/lib
```

## See Also

- [`jac bundle`](cli/index.md#jac-bundle) -- command reference (`--target wheel|npm|all|npm-runtime`)
- [`jac install`](cli/index.md#jac-install) -- installing dependencies and editable installs
- [Configuration Reference](config/index.md#project) -- every `jac.toml` field
- [Plugin Authoring](plugin-authoring.md) -- building distributable Jac plugins
