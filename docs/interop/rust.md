---
description: The Rust toolchain jac carries - jac cargo, rustc and rustdoc, the Rust targets and how each links, another target's standard library on first use, C in a crate's build, and jac build of a Cargo.toml.
keywords: Rust, Rust toolchain, Rust target, wasm32-wasip1, Rust standard library
---
# Rust

`jac cargo`, `jac rustc` and `jac rustdoc` run Rust 1.99, for every target below, from
any machine jac runs on, with nothing else installed. They are the same Rust that compiles a
program's [Rust modules](rust-modules.md), and share one LLVM with jac.

```sh
jac cargo build --release                                # this machine
jac cargo build --target x86_64-unknown-linux-musl       # a static Linux program
jac cargo build --target aarch64-apple-darwin            # macOS on Apple silicon
jac rustc --target x86_64-pc-windows-gnullvm main.rs     # Windows
jac rustc --target wasm32-wasip1 main.rs                 # WASI
jac cargo test                                           # unit tests and doctests
```

Each takes its tool's own command line: `jac cargo --help` is cargo's help, and
`jac cargo` exits with cargo's own statuses (101 for an unknown command, 1 for a bad flag).
There is no rustfmt or Clippy: `jac cargo fmt` and `jac cargo clippy` are unknown commands.

## Targets

| Rust target | Linked by |
|---|---|
| `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` | [`jac cc`](c-and-cpp.md) for glibc 2.17 and later |
| `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl` | `jac cc` for musl, static |
| `x86_64-apple-darwin`, `aarch64-apple-darwin` | `jac cc` for macOS |
| `x86_64-pc-windows-gnullvm` | `jac cc` for mingw-w64 with the Universal CRT (the Rust host on Windows) |
| `wasm32-wasip1` | LLD's `wasm-ld`, with the WASI C library jac ships |

On macOS, a crate may link the system's libraries and frameworks (`#[link(name = "iconv")]`,
`#[link(name = "Foundation", kind = "framework")]`): the toolchain carries stubs of them, so a
build for macOS from any machine links.

## Another target's standard library

The toolchain carries the standard library of its own machine's target. Another target's is
compiled from source the first time a build names it, by jac's own rustc, in under a minute on
a large machine:

```text
jac: compiling Rust's standard library for x86_64-unknown-linux-musl
```

jac fetches the source and keeps it and what it compiled beside the build cache, in a directory
`fetched/`; an installed toolchain is never written. Only that first build needs the network.
`jac rustc --print sysroot --target <target>` prints where a target's standard library is: the
toolchain's own for its machine, the fetched one for any other.

## C and C++ in a crate's build

Every target's C and C++ compiler is `jac cc` and `jac c++`. cargo runs them through links in
the toolchain's `lib/bin/` (`x86_64-linux-musl-cc`, `ar`, ...), each of which runs the tool its name
says, and sets the `cc` crate's `CC_<target>`, `CXX_<target>` and `AR_<target>` to them. So a crate
whose build script compiles C (with the `cc` crate) builds for any target, from any machine.

## Building a Rust program with `jac build`

```sh
jac build app/Cargo.toml -o app            # a plain build
jac build app/Cargo.toml -o app --release
```

`jac build` given a crate's `Cargo.toml`, or the directory that holds it, builds the Rust program
it describes ([build](../toolchain/build.md#what-a-program-is)), with no Jac, as it
builds a [Rust module](rust-modules.md): each crate compiled by jac and kept in the build cache,
so a rebuild compiles what changed. It does so in a project whose archwire declares apps too.

It builds for this machine, and takes `-o` and `--release`. Every other option of `jac build` is
a Jac program's, and is refused with a crate: `--target` among them, since
`jac cargo build --target <target>` builds a crate for another target. A manifest given to
`jac check` or `jac test` is refused too; `jac cargo check` and `jac cargo test` are
cargo's.

```text
jac build: a crate's build takes -o and --release, and '--target' is an option of a Jac program's build: `jac cargo build --target x86_64-unknown-linux-gnu` builds a crate for another platform
```

## How the tools are installed

- On Linux and macOS the tools are part of jac: the toolchain's `lib/rust/bin/rustc`,
  `rustdoc` and `cargo` are links to jac, which runs as the tool it is named. On Windows they
  are programs of their own, and `jac` puts the directory of the LLVM library they load on
  their `PATH`.
- `jac rustc -vV` prints rustc's version, and one `jac-build: <64 hex digits>` line naming
  the build of the toolchain, which is how cargo tells one build of it from another.

## Differences from rustup's Rust

- rustup installs one standard library per target with `rustup target add`. Here a target's
  standard library is compiled on its first use, and every target links with jac's own linkers,
  with no system C toolchain.
- cargo and rustc behave as upstream's otherwise: `Cargo.toml`, `Cargo.lock`, `.cargo/config.toml`,
  `RUSTFLAGS` and `CARGO_INCREMENTAL` mean what they mean for rustup's cargo.
