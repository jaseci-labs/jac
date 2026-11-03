# Publishing to npm

This page covers exporting a Jac library to JavaScript and TypeScript consumers that do not use Jac. To share Jac code with other Jac projects, publish a Jac package with `jac publish`; see [Packages](packages.md). To reach other languages, build a [C-ABI shared library](../build/libraries.md#native-lib). To use Jac code from a Python project, see [Using Jac from a Python project](../build/libraries.md#python-projects).

Client-side Jac libraries can be published to [npm](https://www.npmjs.com) so JavaScript and TypeScript projects can `npm install` them -- whether or not they use Jac. `jac build --as npm` reads your `jac.toml` and produces an npm-compatible `.tgz`: it compiles your client modules to JavaScript (ES modules), generates `package.json`, and emits `.d.ts` TypeScript declarations.

```bash
jac build --as npm             # -> dist/<name>-<version>.tgz
```

## What goes in the package

- **Compiled JavaScript.** Every `.jac` (and plain `.jac`) client module under `[project.include]` compiles to a sibling `.js`, preserving the import structure. `def:pub` / `glob:pub` symbols become ESM exports, and so does any other non-`:priv` name a sibling module in the package imports.
- **`package.json`.** Built from `[project]` (`name`, `version`, `description`, `license`, `keywords`, `repository`) plus `[dependencies.npm]`. Override npm-specific fields under `[npm]`:

    ```toml
    [npm]
    name = "@yourscope/mylib"   # scoped npm name (defaults to the normalized project name)
    entry = "mylib/index.jac" # entry module (defaults to an index.* module)
    ```

- **TypeScript declarations.** A `.d.ts` is generated for each module and `package.json` `types`/`exports` point at the entry's declarations, so TypeScript consumers get full type-checking. Function signatures, `obj`/`node` classes, and globals are all typed; JSDoc is also embedded in the `.js`.

!!! note "Pure client code only"
    npm packages must be standalone client code. A module that crosses a server boundary (a `sv` import/call) can't run as a plain npm install, so `jac build --as npm` rejects it with a clear error. Keep server-coupled code in your app, not in the published library.

### Controlling what ships

By default `jac build --as npm` collects a single directory named after the project (`mylib/`, with hyphens converted to underscores). Override this with `[project.include]`:

```toml
[project.include]
packages = ["mylib", "mylib_extras"]
```

See [`[project.include]`](config/index.md#projectinclude) for the details, and the [Configuration Reference](config/index.md#project) for the full `[project]` field list.

!!! warning "Single-file modules"
    `[project.include]` `packages` matches **directories**. A module that is a single top-level `.jac` file is not collected -- put your code in a directory first.

## The runtime dependency

Libraries that use JSX or the reactive API (`createSignal`, `createEffect`, …) reference the Jac client runtime. The build wires an `import { … } from "@jaseci/runtime"` into those modules and adds `@jaseci/runtime` to `dependencies` automatically. The runtime is a normal, React-independent npm package; modules that explicitly `import from react` instead get `react`/`react-dom` added to `peerDependencies`.

The `@jaseci/runtime` package itself is produced by an internal maintenance build (run when cutting a jaclang release), not by a user-facing `jac build` projection -- it emits `@jaseci/runtime` at the current jaclang version.

## Upload to npm

`jac` does not upload -- use the `npm` CLI:

```bash
npm pack dist/<name>-<version>.tgz   # optional: inspect the contents
npm publish dist/<name>-<version>.tgz --access public
```

In CI, authenticate with an automation token via `NODE_AUTH_TOKEN`.

## Editable installs

While developing a library locally, install it in editable mode so changes are picked up without rebuilding:

```bash
jac install -e .
```

This installs the project's runtime dependencies and writes a `.pth` file and a complete `.dist-info/` directory into `site-packages`, so the source tree is importable and `pip show mylib` and `pip list` report it correctly -- all without a `pyproject.toml`. You can also editable-install a cloned dependency from anywhere:

```bash
jac install -e /path/to/cloned/lib
```

### Console scripts

Declare CLI commands with `[entrypoints]`:

```toml
[entrypoints.scripts]
# `jac install -e .` makes this runnable as `jac x mylib`
mylib = "mylib.cli:main"
```

An editable install writes `[entrypoints.scripts]` as `[console_scripts]` in the `.dist-info`, so [`jac x mylib`](cli/index.md#jac-x) runs the command under the `jac` runtime without it being on your shell `PATH`. Other `[entrypoints.<group>]` tables are written through verbatim for consumers that use `importlib.metadata.entry_points()`; Jac itself no longer loads any entry-point group at startup.

## See Also

- [`jac build`](cli/index.md#jac-build) -- command reference (`--as npm`)
- [`jac install`](cli/index.md#jac-install) -- installing dependencies and editable installs
- [Packages](packages.md) -- sharing Jac code with other Jac projects through `jac publish`
- [Configuration Reference](config/index.md#project) -- every `jac.toml` field
