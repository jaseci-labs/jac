---
name: jac-packaging
description: Distribute a Jac library - jac publish for Jac projects, npm tarballs for JavaScript, editable installs for local development. Use for library layout, metadata, and upload.
---

This skill covers getting a Jac library to its consumers. Pick the path by who consumes it:

| Consumer | Path |
|---|---|
| Other Jac projects | `jac publish` to the Jac package index (see `jac-packages`) |
| JavaScript / TypeScript projects | `jac build --as npm`, then `npm publish` |
| Other languages (C, C++, Rust, Go, Python `ctypes`) | a `native-lib` project, a C-ABI shared library (see `jac-native-shared`) |
| A Python project | `jac build --as source` exports editable Python with the required Jac runtime source, or call the `jac` binary |
| Yourself, while developing | `jac install -e` |

`jac build` runs the whole-program type-check gate first and refuses to emit an artifact on failure - the gate cannot be skipped; `--check_only` runs it and emits nothing.

## Publishing to npm

`jac build --as npm` compiles the package's modules (`.jac` files under the package dir) to ES-module JavaScript - a `kind = "js-package"` project has no server, so every module is placed client by construction, `pub` or not, on every compile path (`jac build`, `jac tool jac2js`, `jac check`) - then generates `package.json` + a `.d.ts` per module (TypeScript consumers get full type-checking), and packs `dist/<name>-<version>.tgz`.

### The package directory - REQUIRED

The npm build packages a directory whose name matches `project.name` (hyphens become underscores: `my-ui` -> `my_ui/`). The `jac create` default template puts `main.jac` at the project ROOT with no such directory - that layout collects nothing. Create the package dir yourself:

```
greetui/                <- project root (holds jac.toml)
  jac.toml
  README.md
  greetui/              <- package dir, name matches project.name
    index.jac           <- your code, normal Jac
```

**A single top-level `.jac` file is never collected** - `packages` matches directories only. To package other directories, list them under `[project.include] packages`; it takes globs and is only read by the npm build.

### jac.toml for npm

```toml
[project]
name = "greetui"
version = "0.1.0"
description = "A tiny Jac component library"
kind = "js-package"
authors = [{name = "Jane Dev", email = "jane@example.com"}]
readme = "README.md"
license = "MIT"
keywords = ["ui", "greeting"]

[project.urls]
repository = "https://github.com/jane/greetui"

[project.include]
packages = ["greetui"]

[dependencies.npm]
lodash = "^4.17.21"

[npm]
name = "@yourscope/greetui"     # scoped npm name (defaults to normalized project name)
entry = "greetui/index.jac"     # entry module (defaults to an index.* module)
```

- Modules that use JSX or the reactive API automatically get `@jaseci/runtime` wired into `dependencies` (a normal, React-independent npm package). Modules that explicitly `import from "react"` get `react`/`react-dom` as `peerDependencies`.
- **Server-boundary rejection**: a module that imports or calls server-placed code cannot run from a plain `npm install`, so the build fails with `'<file>' crosses a server boundary and cannot be published as a standalone npm package. npm packages must be pure client code`. Keep server-coupled code in your app, not the library.

### Build and upload

```
jac build --as npm                                   # -> dist/greetui-0.1.0.tgz
jac build --as npm -o /tmp/out                       # custom output dir
npm publish dist/greetui-0.1.0.tgz --access public   # jac builds the tarball only; npm uploads it
```

In CI authenticate with `NODE_AUTH_TOKEN`.

## Publishing to the Jac index

A Jac package is a project with a scoped `name`, a semantic version and an `exports` list. It carries server, client and native code together, with its own `[dependencies.pypi]` and `[dependencies.npm]` requirements, and consumers install it with `jac install org/name`.

```
jac publish --dry-run        # build + gates + API diff, upload nothing
jac publish                  # opens a PR on the index
```

`jac-packages` has the manifest, the gates and the semver rules.

## Editable installs (local development)

```
jac install -e .            # install the current project editable
jac install -e /path/to/lib # install a cloned library editable
```

An editable install writes a `.pth` and a `.dist-info` into the environment's `site-packages`, so the source tree is importable and edits are picked up without a rebuild. The target's own `jac.toml` supplies its Python dependencies.

```toml
[entrypoints.scripts]
greet = "greet.cli:main"
```

- **`[entrypoints.scripts]`** -> `console_scripts` in the `.dist-info`'s `entry_points.txt`; run the command with `jac x greet`. Format is `command = "package.module:function"`. The function is called with no arguments; read `sys.argv` for CLI args. (Jac no longer loads any entry-point group at startup - there is no plugin system - but any other `[entrypoints.<group>]` table is written through to the same file for consumers that use `importlib.metadata`.)
- **`[project]`** -> `.dist-info/METADATA`. The TOML key is **`requires-python`** (hyphen), not `requires_python` - the underscore form is silently ignored and never reaches `METADATA`.

## Pitfalls

- **No package directory = nothing to pack.** The `default` scaffold's root-level `main.jac` is for `jac run`, not for an npm package. Move code into a `<name>/` package dir (single top-level files are not collected).
- **Do NOT add `jaclang` to `[dependencies.pypi]`.** `jaclang` is not a PyPI package - it is the host runtime supplied by the `jac` binary, and the `.jac` importer ships in that binary.
- **`requires_python` (underscore) is dropped.** Use `requires-python`.
- **Entry-point path is the import-time module path**, e.g. `greet.cli:main` - it must match the package dir name, not the source folder you happened to develop in.
- **`jac build --as npm` fails with `[project] name is missing`** if `jac.toml` has no `name` - it is required for the tarball filename and `package.json`. `jac install -e` needs it for the `.dist-info` name too.
- **The type-check gate blocks the build** if the project fails `jac check` - fix the reported diagnostics; the gate has no bypass flag.

## See also

- `jac-scaffold` - `jac create`, templates, the `default` template's layout
- `jac-config` - the full `jac.toml` section map (`[dependencies.pypi]`, `[npm]`)
- `jac-packages` - Jac packages: `[dependencies]`, `jac.lock`, `jac publish`
- `jac-npm-packages` - CONSUMING npm packages in client code (this skill covers publishing)
- `jac-native-shared` - C-ABI shared libraries
- `jac-impl-files` - splitting `.jac` / `.impl.jac` within the package
