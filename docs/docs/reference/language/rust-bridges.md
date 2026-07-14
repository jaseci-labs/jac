# Rust Crate Bridges

Jac can import functions and types from **Rust crates** that ship a
`jac-bridge-*` shared library. A bridge crate is a normal Rust crate compiled to
a C-ABI `cdylib` with an embedded metadata section; the Jac compiler reads that
metadata, generates the marshaling code, and exposes the crate's surface as
typed Jac objects and functions with native strings, lists, and dicts.

!!! note "Native-first (production path)"
    Rust bridges are a **`nacompile` / `jac bundle` feature**. The supported
    workflow is: declare `[rust-bridges]` → `jac install` → compile with the
    native backend. The CPython runtime (`jac run`) can load bridges via ctypes
    for development, but **na is the ship bar**.

This page is the reference for the **developer-facing** surface: the import
syntax, the `jac add rust:` / `[rust-bridges]` dependency mechanism, how
`jac install` resolves a bridge, the local-build requirements, the environment
variables that steer resolution, and how bridges travel with `jac bundle`. The
binary contract these libraries implement is specified separately in the
[Rust Bridge ABI](../../internals/rust_bridge_abi.md) internals document.

## Importing from a crate

Bridges live under the reserved `rust.` import namespace. Name the crate after
`rust.`, and list the items you want in the braces. A crate type (here
`regex::Regex`) crosses as an opaque handle: construct it, call its methods, and
close it to release the underlying Rust value:

```jac
import from rust.regex { Regex }

with entry {
    re = Regex(r"^\d+$");
    print(re.is_match("12345"));   # True
    re.close();                    # or use `with Regex(...) as re { ... }`
}
```

The same `import from rust.<crate>` syntax is used on both paths, but **production
targets the native compiler**:

- the **native compiler** (`jac nacompile` / `jac nc`), **primary**: marshaling is
  synthesized as Jac source (`.na.jac` cache) and compiled into the binary; the
  bridge `.so` is NEEDED-linked (or copied beside the bundle);
- the **CPython runtime** (`jac run`, `jac start`, `jac test`), **secondary**:
  ctypes interprets marshaling at call time; best-effort, not required for ship.

A crate name maps to a bridge module 1:1: `rust.regex` resolves the `regex`
bridge, `rust.uuid` resolves `uuid`, and so on. Only a single dotted segment is
allowed after `rust.` (`rust.regex`, not `rust.regex.internals`).

## Declaring a dependency

Add a bridge to your project with `jac add`, using the `rust:` prefix on the
package name. An optional version constraint is written with `@` or `==`:

```bash
jac add rust:regex@1.12      # pin the 1.12.x series
jac add rust:uuid            # any available version
jac add rust:base64==0.22    # pin the 0.22.x series
```

This records the crate under a `[rust-bridges]` table in `jac.toml`:

```toml
[rust-bridges]
regex = "1.12"
uuid = "*"
base64 = "0.22"
```

The value is a version **constraint**, not an exact pin. A constraint like
`"1.12"` matches the whole `1.12.x` series; `"*"` (or `""`) matches any version.
When several versions satisfy a constraint, resolution always selects the
**highest** matching version compared numerically, so `1.12` outranks `1.9`
(a lexicographic comparison would get this backwards).

See the [Configuration Reference](../config/index.md#rust-bridges) for the
`[rust-bridges]` table schema.

## Installing bridges

`jac install` (with no arguments, or as part of `jac install <pkg>`) resolves
every crate declared under `[rust-bridges]`. For each crate it walks a fixed
list of sources and stops at the first that produces a matching library:

1. **Local cache** -- a previously resolved or built library under
   `$XDG_CACHE_HOME/jac/rust-bridges/<crate>/<version>/<triple>/`
   (falling back to `~/.cache` when `XDG_CACHE_HOME` is unset).
2. **Registry** -- if `JAC_BRIDGE_REGISTRY` names an index (an HTTPS URL or a
   local path), the matching artifact for the current target triple is
   downloaded and verified against the index's recorded `sha256` before it is
   cached. A checksum mismatch is a hard failure, never a silent accept.
3. **Local build** -- if the Rust toolchain is installed and
   `JAC_BRIDGE_WORKSPACE` points at a bridge workspace, the crate is built from
   source (see [Local build requirements](#local-build-requirements)) and the
   result is installed into the cache.

If no source can satisfy a declared bridge, `jac install` records the dependency
but reports it as **not installed** and exits non-zero, rather than claiming
success. Set `JAC_BRIDGE_REGISTRY`, or install the toolchain and set
`JAC_BRIDGE_WORKSPACE`, to complete the resolution.

## Resolution at runtime

Once a bridge library exists on disk, an `import from rust.<crate>` locates it by
searching, in order:

1. any directories registered at runtime (e.g. a sealed bundle's `rust-bridges/`
   folder, wired in when the image loads);
2. the `os.pathsep`-separated directories in `JAC_RUST_BRIDGES_PATH`;
3. the version-scoped local cache, newest matching version first;
4. `./target/{release,debug}` when `JAC_BRIDGE_DEV_FALLBACK` is set (a developer
   convenience for a bridge you are building in the current workspace).

The library filename is matched cross-platform: `libjac_bridge_<crate>.so` on
Linux, `libjac_bridge_<crate>.dylib` on macOS, and `jac_bridge_<crate>.dll` on
Windows.

## Local build requirements

A local build (resolution source 3, and what `jac install` falls back to on a
cache and registry miss) needs:

- **The Rust toolchain** -- both `cargo` and `rustup` must be on `PATH`. A
  `nightly` toolchain is used for the rustdoc-JSON step
  (`rustup toolchain install nightly`).
- **A bridge workspace** -- `JAC_BRIDGE_WORKSPACE` must point at a directory that
  contains the `jac-bridge` and `jac-bridge-binder` crates. This is the workspace
  the auto-binder and the `#[jac_bridge::bridge]` macro live in.

The build fetches the crate, produces rustdoc JSON, runs the binder to generate a
wrapper crate, and compiles that crate to a `cdylib`. The produced library is
named for the current platform (`libjac_bridge_<crate>.so` / `.dylib` /
`.dll`); the same cross-platform naming is used to locate the build output and to
install it into the cache, so a local build works identically on Linux, macOS,
and Windows once the toolchain is present.

If the toolchain is missing, the build path fails closed with guidance to
install `rustup` rather than emitting a cryptic subprocess error.

## Bundling

`jac bundle` copies each resolved bridge library into a `rust-bridges/` folder
placed beside the sealed image. The runtime registers that folder as a search
directory when the image loads (resolution source 1 above), so a bundled
application carries its bridges with it and needs no cache, registry, or
toolchain on the deployment host.

## Environment variables

| Variable | Role |
|----------|------|
| `JAC_RUST_BRIDGES_PATH` | Extra `os.pathsep`-separated directories to search for bridge libraries, checked before the cache. |
| `JAC_BRIDGE_REGISTRY` | Registry index URL or local path used to fetch bridges on a cache miss. Downloads are verified against the index `sha256`. |
| `JAC_BRIDGE_WORKSPACE` | Rust workspace root (containing `jac-bridge` and `jac-bridge-binder`) used to build bridges locally. |
| `JAC_BRIDGE_DEV_FALLBACK` | When set, also search `./target/{release,debug}` at import time -- for a bridge you are actively building. |
| `XDG_CACHE_HOME` | Base for the local cache (`$XDG_CACHE_HOME/jac/rust-bridges/`); defaults to `~/.cache`. |

## Type marshaling

The bridge boundary marshals a fixed set of shapes between Rust and Jac:

- scalars: `bool`, integers (all widths), and `String` / `&str` as Jac `str`;
- owned collections: `Vec<T>` as a Jac `list`, `HashMap<String, V>` as a Jac
  `dict[str, V]`;
- `Option<T>` and `Result<T, E>` for nullable and fallible returns, where a Rust
  `Err` surfaces as a Jac exception;
- opaque handles for crate types that cross by reference, with their public
  methods exposed as methods on the Jac-side object.

The exact wire encoding, status codes, and shim naming are documented in the
[Rust Bridge ABI](../../internals/rust_bridge_abi.md) internals reference.

### Handle ownership

Every opaque handle carries an ownership class that decides what `close()` (and
the Jac object's `__del__`) does to the underlying Rust object:

- **owned** (the default): the wrapper owns the object; `close()` drops it, and
  it is safe to `close()` exactly once. A constructor result and any method that
  returns a *fresh* object (e.g. `NaiveDate::and_time -> NaiveDateTime`) is
  owned.
- **shared**: the wrapper holds one reference on a reference-counted inner.
  Adopting or aliasing the handle retains it; `close()` decrements the count and
  the inner is freed only when the last reference drops, so a shared alias stays
  valid after its originator closes and a double-close is idempotent.
- **borrowed**: a live, non-owning view into an owner's interior. Minting the
  view retains its owner, so the owner physically cannot be freed while the view
  is live; the view reads through a live pointer (zero-copy) and dropping it
  releases the owner. Mutable interior aliases (`&mut Field` views such as
  serde_json `get_mut` or ndarray `view_mut`) are **not** bridged -- they would
  alias the owner's exclusive borrow (Rust UB) -- and are skipped with a reason.

Handles are reference-counted at the ABI layer (each box tracks its own count),
so two wrappers over one object free it exactly once. A crate whose API is
*unsound at the Rust level* -- one that hands out a second raw owner of the same
allocation -- is **skipped with a reason**, not silently "defended": the bridge
refuses to generate it rather than pretend a handle-table trick can make a
double-owning `Drop` safe.

An author records such a refusal in the crate's `.overlay.toml` with a `reason`
alongside the `skip`:

```toml
[fn."Cell::alias"]
skip = true
reason = "unsound: hands out a second raw owner of the same allocation"
```

The reason surfaces verbatim in the coverage report, and the skip is always
counted there -- a refused method stays visible in the API-coverage ratio
instead of silently vanishing.

### Known limitations (ABI v1)

!!! warning "Callback detection on na"
    On the native (`nacompile`) path, a `lambda` argument is lowered to a
    callback trampoline when it lands in an `i64` parameter slot and the loaded
    bridge exposes a `make_buf` sink, not by consulting the callee's declared
    `TAG_FN` parameter tag in the bridge metadata. This shape-based gate is
    narrow enough for ABI v1 (callbacks are the only bridged `i64` params that
    accept lambdas today), but a future ABI should thread `FnDesc` param tags
    into na codegen so detection follows the blob, not the LLVM slot type.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `jac install` reports a bridge is **not installed** (non-zero exit) | No source satisfied the constraint. Set `JAC_BRIDGE_REGISTRY`, or install the Rust toolchain and set `JAC_BRIDGE_WORKSPACE`. |
| Import fails at runtime after a successful install | The library is outside every search path. Confirm it is in the version-scoped cache, or point `JAC_RUST_BRIDGES_PATH` at its directory. |
| A local build fails with a toolchain error | Install `rustup` and a `nightly` toolchain; ensure `cargo` and `rustup` are on `PATH`. |
| A registry download is rejected | The artifact's `sha256` did not match the index. The index or the artifact is stale or corrupt; do not bypass the check. |
