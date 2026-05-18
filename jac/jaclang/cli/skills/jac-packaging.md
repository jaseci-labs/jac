---
name: jac-packaging
description: Packaging a Jac project as a wheel and publishing it to PyPI - jac.toml metadata, the package-directory layout, console-script entry points, jac bundle, and twine upload. Load when turning a project into a pip-installable CLI tool or an importable library. Pair with `jac-scaffold` (creating the project) and `jac-impl-files` (source layout).
---

`jac bundle` builds a standard PEP 427 wheel (`dist/<name>-<version>-py3-none-any.whl`) straight from `jac.toml` - no `setup.py`, no `pyproject.toml`. Upload it to PyPI with `twine`. This covers both shapes: a **CLI tool** (installs a terminal command) and an **importable library** (`pip install` then `import`).

## The package directory - REQUIRED

`jac bundle` packages a directory whose name matches `project.name` (hyphens become underscores: `my-tool` -> `my_tool/`). The `jac create` default template puts `main.jac` at the project ROOT with no such directory - that layout does NOT produce an importable package. Create the package dir yourself:

```
greet/                  <- project root (holds jac.toml)
  jac.toml
  README.md
  greet/                <- package dir, name matches project.name
    cli.jac             <- your code, normal Jac
```

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

[project.urls]
Homepage = "https://example.com/greet"

[entrypoints.scripts]
greet = "greet.cli:main"

[dependencies]
rich = ">=13.0.0"
```

- **`[project]`** -> wheel `METADATA`. The TOML key is **`requires-python`** (hyphen), not `requires_python` - the underscore form is silently ignored and never reaches `METADATA`.
- **`[dependencies]`** -> `Requires-Dist` in the wheel, so `pip install` pulls them in.
- **`[entrypoints.scripts]`** -> `console_scripts` in `entry_points.txt`. Format is `command = "package.module:function"`. The function is called with no arguments; read `sys.argv` for CLI args. Omit this whole section for a pure library.

## Build and publish

```
jac bundle                 # -> dist/greet-0.1.0-py3-none-any.whl
jac bundle -o /tmp/wheels  # custom output dir
twine upload dist/*.whl    # publish to PyPI (twine is a separate pip install)
```

There is no `jac publish` command - use `twine`. Consumers then `pip install greet`; the CLI command `greet` is on `PATH`, or `import greet` works for a library. `pip install jaclang` is pulled in automatically if you list it (or it rides along as a dependency) - the importer it ships is what runs your `.jac` code.

## What lands in the wheel

`jac bundle` collects `*.jac`, `*.py`, `*.pyi`, `*.lark`, `py.typed`, and `*.jir` from the package directory. It excludes `.jac/`, `__pycache__/`, `dist/`, `build/`, `venv/.venv/env/`, `.git/`, and `node_modules/`. To package extra directories or override patterns, use `[project.include]` with `packages` and `data` keys.

## Editable installs (local development)

```
jac install -e .            # install the current project editable
jac install -e /path/to/lib # install a cloned library editable
```

## Pitfalls

- **No package directory = empty/unimportable wheel.** The `default` scaffold's root-level `main.jac` is for `jac run`, not for distribution. Move code into a `<name>/` package dir.
- **`requires_python` (underscore) is dropped.** Use `requires-python`.
- **Entry-point path is the install-time module path**, e.g. `greet.cli:main` - it must match the package dir name, not the source folder you happened to develop in.
- **First run of an installed Jac command prints `Jac setup complete! (N modules compiled and cached)`** while jaclang compiles its own cache. This is one-time and harmless; it does not repeat on later runs.
- **`jac bundle` fails with `[project] name is missing`** if `jac.toml` has no `name` - it is required for the wheel filename and `.dist-info`.

## See also

- `jac-scaffold` - `jac create`, templates, the `default` template's layout
- `jac-impl-files` - splitting `.jac` / `.impl.jac` within the package
- `jac-core-cheatsheet` - import forms inside `.jac` files
