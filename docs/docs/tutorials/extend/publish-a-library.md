# Publish a Library

Build a reusable library in Jac and ship it to PyPI as a wheel and to npm as a package -- from `jac create` to `twine upload`. The [publishing reference](../../reference/publishing.md) documents every knob; this tutorial walks the happy path end to end.

**What you'll do:**

1. Scaffold a `py-package` project and write a small library
2. Build a PyPI-ready wheel with `jac bundle` and test it locally
3. Upload it with twine
4. Do the same for npm with a `js-package`

**Time:** ~15 minutes

---

## 1. Scaffold the library

```bash
jac create greetlib --kind py-package
cd greetlib
```

This creates a minimal library project -- note there is no `main.jac`; packages don't need an entry point:

```
greetlib/
├── jac.toml          # kind = "py-package", name, version
├── lib.jac           # your public API
├── AGENTS.md         # guidance for AI coding agents
└── .gitignore
```

The generated `jac.toml` already carries the metadata that will become your wheel's `METADATA`:

```toml
[project]
name = "greetlib"
version = "0.1.0"
description = "Distributable Python package (built into a wheel)"
entry-point = "lib.jac"
kind = "py-package"
```

## 2. Write the library

Everything marked `:pub` is your public API. Replace `lib.jac`:

```jac
"""A tiny greeting library."""

def:pub greet(name: str) -> str {
    return f"Hello, {name}!";
}

def:pub greet_many(names: list[str]) -> list[str] {
    return [greet(n) for n in names];
}
```

Add a test in `lib.test.jac` and run it:

```jac
test "greet works" {
    assert greet("Jac") == "Hello, Jac!";
}
```

```bash
jac test
```

## 3. Build the wheel

```bash
jac bundle
```

```
✔ Built greetlib-0.1.0-py3-none-any.whl (1,151 bytes)
✔ greetlib-0.1.0.tar.gz (815 bytes)

Distributions written to: dist
Upload with: twine upload dist/*
```

That's a standard PEP 427 wheel plus an sdist. Two things worth knowing:

- **Consumers don't need Jac.** The wheel ships your `.jac` source (plus `.jir` bytecode when present); `pip install greetlib` works in any Python project, and `jaclang` is *not* added as a runtime dependency. Runtime dependencies your library actually uses must be declared under `[dependencies]` in `jac.toml` -- they become `Requires-Dist` entries.
- **Because the project's `kind` is `py-package`, plain `jac run` builds the wheel too** -- `jac run --show` prints the resolved plan.

Test the wheel locally before uploading:

```bash
pip install dist/greetlib-0.1.0-py3-none-any.whl
python -c "import greetlib; print(greetlib.greet('PyPI'))"
```

## 4. Upload to PyPI

`twine` is the only external tool you need, and only for the upload itself:

```bash
pip install twine
twine upload dist/*          # add --repository testpypi for a dry run
```

## 5. Now for npm

The npm flow is symmetric -- the `js-package` kind compiles `cl` (client) code to ES-module JavaScript with TypeScript declarations:

```bash
cd ..
jac create jsgreet --kind js-package
cd jsgreet
jac bundle --target npm
```

```
✔ Built jsgreet-0.1.0.tgz (213 bytes)
Tarball written to: dist/jsgreet-0.1.0.tgz
Publish with: npm publish
```

The tarball contains compiled `.js` modules, matching `.d.ts` TypeScript declarations, and a `package.json` generated from `[project]` and `[dependencies.npm]` in `jac.toml`. If your components use JSX or the reactive API, Jac auto-wires `@jaseci/runtime` as a dependency. Publish with:

```bash
npm publish dist/jsgreet-0.1.0.tgz --access public
```

!!! tip "One project, both targets"
    `jac bundle --target all` builds the wheel *and* the npm tarball from a single project, when your library has both server-usable and client-usable modules. Modules that cross the server boundary are rejected with a clear error at bundle time.

## Gotchas

- **Wrap top-level modules in a directory.** Single-file top-level modules aren't collected into the wheel -- put your code in a package directory (the scaffold already does this).
- **Data files must be declared.** Non-code files ship only if listed under `[project.include.data]` -- see [What gets included](../../reference/publishing.md#1-declare-package-metadata).
- **Version bumps live in `jac.toml`.** The `[project] version` field is the single source for wheel, sdist, and npm versions.

## Where to go next

- [Publishing reference](../../reference/publishing.md) -- metadata fields, `[entrypoints.scripts]` console commands, editable installs
- [Shared library (C ABI)](../../quick-guide/project-kinds.md#shared-library-c-abi) -- the third packaging target: `jac nacompile --shared` builds a `.so`/`.dylib`/`.dll` any language can link
- [Build a Jac Plugin](build-a-plugin.md) -- packages that extend the `jac` CLI itself
