# Python Interop Tier (PyO3 wheels)

The **py tier** lets a native (`nacompile`) Jac binary carry and drive
**Python extension wheels** -- the thousands of PyO3/C-extension libraries on
PyPI (`polars`, `cryptography`, `orjson`, `numpy`, ...) -- with **no Python
installed on the target machine**. The wheels ride inside the binary alongside an
embedded CPython interpreter; at boot the binary brings up that interpreter and
imports the wheel from its own bundled `site-packages`.

!!! note "Native-first, host-platform-only (v1)"
    The py tier is a **`nacompile` / `jac build --as binary` feature**. Wheels
    are resolved with `pip --only-binary=:all:` against the **bundled
    interpreter's tags** (cp314 / abi3) for the **build host's platform only**;
    the build host's libc must match the target. Cross-platform wheel resolution
    (`pip --platform`) is deferred.

## Two tiers, one choice: `rust:` vs `py:`

Jac offers two ways to reach code that isn't Jac. They are complementary, and the
prefix on `jac add` makes the trade explicit and user-chosen:

| | `jac add rust:<crate>` | `jac add py:<pkg>` |
|---|---|---|
| **Answer to** | *performance* | *variety* |
| **What crosses** | a Rust crate compiled to a `jac-bridge` C-ABI cdylib | a PyPI extension wheel + embedded CPython |
| **Call cost** | native marshaling, no interpreter | PyO3 / C-API boundary + GIL per call |
| **Surface** | typed Jac objects, native str/list/dict | `PyObj` handles with getattr/call |
| **Breadth** | crates with a bridge shim (a curated, growing set) | the existing PyPI extension ecosystem, unchanged |
| **Ships via** | `.so` NEEDED-linked beside the binary | interpreter + wheel bundled into the binary |

Reach for **`rust:`** when the hot path is yours to make fast -- a bridge call is
native marshaling with no interpreter in the loop. Reach for **`py:`** when you
want a library that already exists and only ships as a Python wheel -- you inherit
thousands of author-maintained bindings at the PyO3-boundary cost, without a
rewrite. A project can use both.

See [Rust Crate Bridges](rust-bridges.md) for the performance tier.

## Declaring a dependency

Add a wheel to your project with `jac add`, using the `py:` prefix. An optional
version constraint is written with `@` or a PEP 440 operator:

```bash
jac add py:polars            # any available version
jac add py:polars@1.2.3      # pin exactly 1.2.3
jac add py:orjson>=3.10      # a lower bound
jac remove py:polars         # drop it again
```

This records the wheel under a `[py-interop]` table in `jac.toml`, mirroring
`[rust-bridges]`:

```toml
[py-interop]
polars = "==1.2.3"
orjson = "*"
```

The value is the constraint verbatim: `"*"` means any version, an operator-led
string (`"==1.2.3"`, `">=3.10"`) is passed straight to pip, and a bare version is
resolved as `==`. Editing the table by hand is equivalent to `jac add py:`.

## Building a py-interop binary

The entry point must be an `.na.jac` host that boots the runtime and drives the
wheel through the embedded interpreter. Build it with `--as binary` and
`--with_py_interop`:

```bash
jac build --as binary --with_py_interop
```

The wheels come from the `[py-interop]` table. To add ad-hoc wheels not in the
manifest, pass `--py` (space- or comma-separated); manifest wheels are always
included:

```bash
jac build --as binary --with_py_interop --py "orjson polars"
```

What the build does, end to end:

1. `nacompile` the entry host to an ELF binary.
2. Materialize a slim CPython runtime (libpython + zipped stdlib), then
   `pip install --only-binary=:all: --target <site-packages>` the wheels for the
   host platform tag.
3. Slim the payload (drop `jaclang`, `pytest`, unused `pip`/`setuptools`; keep
   libpython, the zipped stdlib, the wheels, and `cacert.pem`).
4. `patchelf` each wheel `.so` so its `RPATH` finds the bundled libpython at
   `$ORIGIN`.
5. Repack into a runtime payload and graft it onto the binary.

The result is a single self-contained executable. On a machine with no Python it
brings up embedded CPython 3.14 and imports the bundled wheels off its own
`site-packages`.

## Runtime model and limits

- **GIL / threading (v1):** calls acquire the GIL (`PyGILState_Ensure/Release`);
  the interpreter is **main-thread only**. Uncontended GIL acquisition is
  ~100 ns -- marshaling dominates.
- **GIL build only:** the bundled interpreter is a standard GIL build (not
  free-threaded).
- **Symbol interposition:** a wheel that vendors its own native libraries (e.g.
  `cryptography` vendoring OpenSSL) must not have those symbols interposed by the
  binary's own `NEEDED` libraries. The flagship acceptance suite pins this with a
  `cryptography` Fernet round-trip and a `polars` group_by on a Python-free
  machine.
- **Platform tags:** wheel availability on cp314 / abi3 varies per package;
  `--only-binary=:all:` means a package with no matching binary wheel fails the
  build rather than compiling from source on the target.
