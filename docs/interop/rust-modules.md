---
description: Rust crates as modules of a Jac program - what a crate's interface gives Jac, calling back into Jac and C, how crates are compiled, cached and linked into the one binary, and what goes wrong.
keywords: Rust module, crate, Cargo.toml, extern "C", no_mangle, repr(C), .cargo/config.toml, CARGO_INCREMENTAL, RUSTFLAGS, CARGO_ENCODED_RUSTFLAGS
---
# Rust modules

A directory holding a `Cargo.toml` is a Rust module: a crate that a program compiles with it and
imports as it imports a [C module](c-modules.md). In a project (a directory with a `jac.toml`) the
manifest is a table of `jac.toml`, `[cargo."<directory>"]`, which jac writes as that file:
`jac absorb <directory>` takes an existing one in ([Packages](../toolchain/packages.md#rust-crates-and-c-modules)). `jac build` compiles the crate, with its
dependencies, build scripts and procedural macros, and links it all into the one binary.

## The shortest example

`adder/Cargo.toml`:

```toml
[package]
name = "adder"
version = "0.1.0"
edition = "2024"
```

`adder/src/lib.rs`:

```rust
#[unsafe(no_mangle)]
pub extern "C" fn add(a: i64, b: i64) -> i64 {
    a + b
}
```

`main.jac`, beside `adder/`:

<!-- example: not checked: needs the Rust crate adder beside the program -->
```jac
import from adder { add }

with entry {
    print(add(2, 3));
}
```

```sh
jac build main.jac -o main && ./main      # prints 5
```

No Rust needs installing: the toolchain carries cargo and rustc (see [Rust](rust.md),
`jac docs Rust`). A crate in a subdirectory is named by its dotted path (`ws.ffi` for
`ws/ffi/Cargo.toml`), as any module is.

## What a crate gives Jac

A crate's interface is what rustdoc reads of it, in the types a [C library](c-libraries.md#types-in-a-declaration)
declaration takes:

| Rust | Jac |
|---|---|
| `#[unsafe(no_mangle)] pub extern "C" fn` | A function. `i64` is `int`, `u64` is `u64`, `i32` is `i32`, `f64` is `float`, `*const c_char` is `str`, another `*const T` / `*mut T` is `ptr[T]` (which also takes `&x`), an `extern "C" fn` pointer a `Callable` |
| `#[unsafe(no_mangle)] pub static` (or `static mut`) | A global, read in place |
| `#[repr(C)] pub struct` | A record, constructed by keyword and passed by value |
| Any other `pub struct` | An opaque type, held as `ptr[T]` |
| `pub const` of an integer type | An `int` constant |
| A `#[repr(i32)]` (or other integer) `enum`'s variants | `int` constants named as the variants |

```rust
use std::ffi::CStr;
use std::os::raw::c_char;

pub const ADDER_LIMIT: i32 = 41;

#[repr(i32)]
pub enum Color {
    Red = 1,
    Blue = 2,
}

#[repr(C)]
pub struct Pair {
    pub left: i64,
    pub right: f64,
}

pub struct Tally {
    seen: Vec<i64>,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn text_length(s: *const c_char) -> usize {
    unsafe { CStr::from_ptr(s) }.to_bytes().len()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn pair_sum(p: Pair, q: *const Pair) -> f64 {
    p.left as f64 + p.right + unsafe { (*q).right }
}

#[unsafe(no_mangle)]
pub extern "C" fn apply(f: extern "C" fn(i64) -> i64, x: i64) -> i64 {
    f(x) + 1
}

#[unsafe(no_mangle)]
pub extern "C" fn tally_new() -> *mut Tally {
    Box::into_raw(Box::new(Tally { seen: Vec::new() }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_add(t: *mut Tally, x: i64) {
    unsafe { &mut *t }.seen.push(x);
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_sum(t: *const Tally) -> i64 {
    unsafe { &*t }.seen.iter().sum()
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tally_free(t: *mut Tally) {
    drop(unsafe { Box::from_raw(t) });
}

#[unsafe(no_mangle)]
pub static mut ADDER_COUNTER: i32 = 7;
```

<!-- example: not checked: needs the Rust crate adder beside the program -->
```jac
import from adder {
    ADDER_COUNTER,
    ADDER_LIMIT,
    Blue,
    Pair,
    apply,
    pair_sum,
    tally_add,
    tally_free,
    tally_new,
    tally_sum,
    text_length,
}

def tripled(x: int) -> int {
    return x * 3;
}

with entry {
    print(ADDER_LIMIT, Blue, ADDER_COUNTER);
    print(text_length("héllo"), apply(tripled, 4));
    p = Pair(left=1, right=0.5);
    print(pair_sum(p, &p));
    t = tally_new();
    tally_add(t, 4);
    tally_add(t, 38);
    print(tally_sum(t));
    tally_free(t);
}
```

```text
41 2 7
6 13
2.0
42
```

A public item the interface cannot express is left out, and importing it says why (E5138): a
`pub fn` that isn't `extern "C"` (`it isn't extern "C"`), one without a fixed name, one whose
types C cannot pass. Rust's own types (`String`, `Vec`, generics, methods) do not cross; pass
pointers and C types, and keep Rust's values behind an opaque handle as `Tally` is above.

## Calling Jac and C from Rust

A crate calls C modules and Jac functions by name, declared in an `unsafe extern "C"` block, and
the project's [archwire](../language/modules-wiring.md) says where each comes from. In a project
with C modules `shapes` and `geom`, a crate `tally` and a Jac module `helpers`:

`archwire.jac`:

<!-- example: not checked: an archwire.jac of a project with C modules and a crate -->
```jac
graph layers {
    layer helpers { helpers; }
    layer libraries { shapes | geom | tally; }
    layer program { main; }
}

graph import {
    edge Helpers: helpers --> libraries;
    edge Libraries: libraries --> program;

    shapes ++> geom;
    geom ++> main { geom_total }
    tally ++> geom;
    tally ++> main { tally_twice }
    helpers ++> tally { jac_double }
}
```

| Wire | Means |
|---|---|
| `helpers ++> tally { jac_double }` | The Jac module `helpers`' functions `jac_double` become C-ABI functions of that name, which the crate calls |
| `shapes ++> tally;` | The crate calls the C module `shapes`' functions by name; `shapes` is built into every program the crate is in |
| `tally ++> geom;` | The C module `geom`'s code calls the crate's `extern "C"` functions by name; the crate is linked, as a library whatever its `crate-type`, into every program `geom` is in |
| `tally ++> main { tally_twice }` | Jac binds the crate's names, as `import from tally { tally_twice }` does |

A crate takes names from a Jac module and a C module whole; any other wire into it is E5141. A Jac
function a crate calls that raises an exception returns 0 to Rust, and the exception's traceback is
printed on standard error.

## A crate's files

A crate of the project's own is what cargo builds, and its files are modules of the project
besides: `ws/gear/src/teeth.rs` is `ws.gear.src.teeth`. Where one file of the crate names an item
another defines, a `-->` wire declares it, as for a file in any other language
([Declared wires](../language/modules-wiring.md#declared-wires---)):

<!-- example: not checked: a graph import block is valid only in a file named archwire.jac, beside the modules it wires -->
```jac
graph import {
    ws.gear.src.teeth --> ws.gear.src.lib { RATIO, count }
    ws.gear.src.util --> ws.gear.src.teeth;
}
```

`lib.rs` holds `use crate::teeth::count;` and `teeth::RATIO` in an expression; `teeth.rs` holds
`use crate::util::*;`.

- rustc reads the crate: its library and its programs, as cargo builds them. An import is a path
  rustc resolved to an item of the crate that another file defines, wherever the path is written.
  A method has no path of its own; the type's is the import. What a macro's expansion names
  counts for the file that calls the macro.
- A `mod` declaration is no import: it says a file is part of the crate, not that its names are
  used.
- A crate is the project's own where `jac.toml` holds its manifest (`[cargo."ws/gear"]`). A crate
  with a `Cargo.toml` that `jac.toml` does not hold is a dependency, one module whole, and so is a
  crate from crates.io. An import of another crate is cargo's, in the manifest.
- Code differs by platform (`#[cfg(windows)]`), so a crate is read for the platform being built
  and for every other platform jac builds Rust for whose standard library is at hand. A reading
  never compiles a standard library. Where one is missing, an import no reading holds may be one
  that platform compiles, so a wire is not reported as declaring nothing (E1147) until every
  platform has been read; an import no wire declares (E1575) is reported from any.
- A reading is kept in the build cache by what the crate holds (its manifest and every `.rs` file
  under it), the platforms read, and the jac that read it; it names the crate's files from the
  crate's directory. A copy of the project in another directory is checked from the same reading.
- These wires are checked by `jac arch`, by the editor, and mended by `jac fmt --fix`. A
  `macro_rules!` macro called by its textual scope leaves no path in what rustc resolves, and is
  not an import here.

## How it is built and linked

- **cargo plans, jac compiles.** cargo resolves and fetches the dependencies from `Cargo.lock`
  and says what to build; jac runs rustc on each crate, and each build script and procedural
  macro, as cargo would. A build script's output lines mean what they mean to cargo, in both
  spellings (`cargo::rustc-link-lib=static=cadd` and `cargo:rustc-link-lib=static=cadd`).
- **Profiles.** Each crate compiles with its profile's settings as cargo resolves them for it,
  `lto = "off"` among them. One package that two Rust modules build with different settings
  (`debug-assertions = false` in one's `[profile.dev]`) is two crates, and the program links
  both.
- **Each crate is a unit of the build cache**, kept by the content of the files rustc read. A
  rebuild compiles what an edit changed and the crates that depend on it; an edit to the Jac alone
  compiles no Rust. A crate is the smallest thing rustc compiles, so editing one file of a large
  crate costs more than editing one C file.
- **Incremental mode.** A crate compiles with rustc's incremental mode where cargo's profile says
  so: a local package's crates in the dev profile (a build without `--release`), unless
  `CARGO_INCREMENTAL=0`, `build.incremental` or the profile turns it off, or the build runs under
  CI, where cargo turns it off. An incremental crate is
  not the same bytes from build to build, since rustc names its objects at random; every other
  crate is the same bytes from every build of the same sources, wherever they, the toolchain and
  the build cache are, and a module's crates link in the same order from every build.
- **Variables.** A crate that reads a variable (`env!`, `option_env!`) compiles again when it
  changes, and a change to a variable cargo or rustc is configured by makes the build look again.
- **cargo's configuration** applies as it does to `cargo build`: `.cargo/config.toml`'s `[env]`
  (a plain value, `{ value = ..., force = true }` which wins over the environment, and
  `{ value = ..., relative = true }` made absolute from the file's directory), its
  `[build] rustflags` for the target's crates (not procedural macros, which are built for the
  machine building), `RUSTFLAGS` in place of the configured flags, `CARGO_ENCODED_RUSTFLAGS` in
  place of both, and `$CARGO_HOME/config.toml`.
- **`NEOJAC_DEPENDENCY_DIGEST`** is in every crate's compile environment: a digest (a multiple of
  64 hex characters) of what the crates it depends on are, their artifacts and the native
  libraries they link, by content and never by path. A crate that reads it
  (`env!("NEOJAC_DEPENDENCY_DIGEST")`) can say exactly which build of its dependencies it was
  linked with, the same from any rebuild of the same sources.
- **Builds at once.** Builds that compile Rust in one cache run side by side: nothing a build
  script or rustc writes there is written twice. Two builds that need the same crate at the same
  moment compile it once: one does, and the other does the rest of its work, waits for that
  crate if it has nothing else to do (`waiting for the crates another build is compiling`), and
  reads it.
- **`--release`** compiles the crate whose items the Jac binds to bitcode, which optimizes with the
  program's Jac and C, so calls inline across the languages both ways.
- **Each Rust module links as a unit of its own**, which shows the rest of the program only its
  interface: the names the Jac imports of it, and, for a module wired into a C module, the
  symbols that C module calls. Every other symbol of it, a `#[no_mangle]` one or one of the C its
  build scripts compile included, is private to it, so two modules may each define a symbol of
  one name. A static library a build script names from outside its build (`openssl-sys` naming
  the toolchain's OpenSSL) is linked once.
- **One standard library.** The crates of a program share one copy of `std`.
- **Panics and memory.** A panic unwinds inside Rust and aborts the program at an `extern "C"`
  boundary, as Rust defines (`panic in a function that cannot unwind`). Rust allocates with the C
  library's allocator; memory crossing the boundary is freed by the side that allocated it.
- **Targets.** A program with Rust modules builds for every platform `jac build` does but
  `wasm32-wasi`, with `--target` and `--release` as usual; another target's Rust standard library
  is compiled the first time, as [Rust](rust.md) describes.

## What goes wrong

| Code | Cause |
|---|---|
| E5138 | The imported item is something the interface leaves out; the message says why |
| E1145 | The crate has no public item of that name |
| E5146 | Two Rust modules both give the program a symbol the program calls by name |
| E5144 | The crates of one Rust module do not link together (two `#[global_allocator]`s, say); rustc's reason follows |
| E5140 | A crate does not compile; rustc's errors are printed first |
| E5137 | cargo cannot resolve the module (a bad `Cargo.toml`, a dependency it cannot fetch) |
| E5139 | The crate's interface cannot be read |
| E5141 | A wire into a crate other than names from a Jac module or a C module whole |

## Differences from Python and from the reference design

- Python reaches Rust through a compiled extension module (PyO3, maturin). Here a crate's
  `extern "C"` items are bound directly, and the crate is linked into the program.
- The reference design has no Rust modules.
