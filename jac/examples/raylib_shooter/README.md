# Jac Cube Shooter - a native 3D demo linked against precompiled raylib

A tiny first-person 3D shooter written in **Jac**, compiled straight to a
standalone native binary that links against a **precompiled
[raylib](https://www.raylib.com) shared library** - no Python runtime and no C
source of our own.

_A perspective floor grid with floating red target cubes and a live FPS counter; run `./demo.sh` to see it._

The whole renderer is driven from Jac through raylib's C API using Jac's native
C-import syntax. The library is named by its **logical name** - `import from
raylib` - with no path and no extension:

```jac
import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def rlVertex3f(x: f32, y: f32, z: f32) -> None;
    def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;
    # ...
}
```

The native backend resolves the platform-correct filename from the target triple
(`libraylib.so` on Linux, `libraylib.dylib` on macOS, `raylib.dll` on Windows), so
this **one unchanged source targets all three** - no per-OS edits, no renaming. An
explicit string path (`import from "/usr/lib/.../libm.so.6" { ... }`) is still
accepted for libraries that need a pinned filename.

Every declaration in that block becomes an `extern` symbol that the Jac native
linker resolves out of the shared library. Notably, the linker is pure Python -
there is **no `cc`/`ld` invocation**; `jac build --native` emits the object code and
writes the ELF/Mach-O executable itself, recording the resolved library as a
needed entry plus a `$ORIGIN`/`@loader_path` runpath so the sibling library
resolves no matter where the binary is launched from.

## Run it

```bash
./demo.sh              # default: benchmark all four builds (8s each) in both modes
./demo.sh --jac        # build & play only the Jac-native shooter, interactively
./demo.sh --zig        # build & play only the Zig shooter, interactively
./demo.sh --rust       # build & play only the Rust shooter, interactively
./demo.sh --python     # play only the Python shooter, interactively
./demo.sh --jac --flock  # any interactive mode, with the 256-boid flock turned on
./demo.sh --headless   # benchmark the borrow-checked headless sim (no window/GPU)
```

> **Run it in the browser too:** [`web/`](web/) compiles the _same_ rlgl source to
> WebAssembly (`jac build --native --target wasm32`) and renders it with WebGL - the
> `import from raylib` externs become the wasm module's imports. See
> [`web/README.md`](web/README.md); run `cd web && ./demo.sh`.

`demo.sh` will:

1. detect your platform/architecture,
2. download the matching precompiled raylib release from GitHub,
3. stage its shared library beside the script (`libraylib.so` on Linux,
   `libraylib.dylib` on macOS),
4. build the shooter(s) it needs:
   - `shooter.jac` with `jac build --native` (no C compiler, no `cc`/`ld`),
     producing `./shooter`;
   - `shooter.zig` with the Zig toolchain against the staged library, producing
     `./shooter_zig`. If `zig` is not already on your `PATH`, the script
     downloads the matching single-archive Zig distribution into `.build/` and
     uses it from there - nothing is installed system-wide;
   - `shooter.rs` with a single-file `rustc` build (no cargo, no crates) against
     the staged library, producing `./shooter_rust`. If a `rustc` >= 1.85 is not
     already on your `PATH`, the script installs a minimal stable toolchain via
     rustup into `.build/rust/` (no `PATH` or shell-profile edits);
   - `shooter.py` needs no build step: it runs on `$PYTHON` (default `python3`)
     and loads the staged library through the standard library's `ctypes`. If
     no interpreter is found, the benchmark skips the Python row;
5. run them: the default **benchmarks** all four in both modes (see below);
   `--jac` / `--zig` / `--rust` / `--python` launch one interactively, and
   `--flock` turns on flock mode for that run.

### Benchmark mode (default)

With no flag, `demo.sh` runs each build for 8 seconds in each of two modes -
the original shooter, then [flock mode](#flock-mode) - and prints one table per
mode, with each build's average FPS as a multiple of the Python twin's:

```
====== raylib cube shooter benchmark (8s each, uncapped) ======
  original: rendering only
  build       avg FPS      max FPS     frames  vs Python
  Jac          3286.5       5163.5      26292       1.9x
  Zig          3222.3       5114.0      25779       1.9x
  Rust         3414.6       5259.7      27317       2.0x
  Python       1724.4       2534.6      13796       1.0x
================================================================

====== raylib cube shooter benchmark (8s each, uncapped) ======
  flock mode: 256 boids steering every frame
  build       avg FPS      max FPS     frames  vs Python
  Jac          1379.9       1839.1      11040       8.9x
  Zig          2090.7       3852.3      16727      13.5x
  Rust         2167.1       3885.4      17337      14.0x
  Python        155.3        186.3       1243       1.0x
================================================================
```

(Numbers above are from an Apple M5 Max with CPython 3.14.6; yours will
differ. In the original mode the three native builds track each other closely -
they link the same precompiled raylib and do identical per-frame work, so the
frame time is dominated by raylib and the GPU driver, and even Python's per-call
overhead only halves the frame rate. A single 8s run moves by several percent
from run to run; over repeated interleaved runs the three native averages land
within about 3% of each other, with the ordering changing between runs. Flock
mode moves most of the frame into each language's own arithmetic, which is where
the builds separate: there the native builds run roughly 9-14x faster than
Python, and Jac's build of the flock loop trails Zig and Rust. Max FPS is the
single fastest frame and is mostly noise.)

How it works without changing how the demos _play_: a binary can't report FPS to
the shell on its own (raylib paints the counter onto the framebuffer, not
stdout), so each shooter has a small, **dormant** benchmark path. `demo.sh`
writes the requested duration into a sibling `.bench_seconds` file before
launching; each binary reads that file with raylib's own cross-platform helpers
(`FileExists` / `LoadFileText` / `TextToInteger`), and when present it times
itself with raylib's `GetTime`, then writes a `BENCH_RESULT avg max frames
seconds` line to a sibling `.bench_result` file (via raylib's `SaveFileText`) and
exits; `demo.sh` reads that back and cleans both files up. When `.bench_seconds`
is absent - every `--jac` / `--zig` / `--rust` / `--python` run, or a bare `./shooter` - that path is
skipped entirely and the game loop runs until you close the window, exactly as
before. (The result travels through a file rather than stdout because the demos
go through raylib's own I/O - no `print`, no libc - so the Jac, Zig, Rust, and
Python twins stay parallel.)

### Flock mode

The original shooter spends almost all of each frame inside raylib and the GPU
driver, so it shows that the four builds drive raylib equally well but says
little about the languages themselves. Flock mode adds a workload that runs in
each language's own code: 256 boids that every frame steer against **every
other boid** - separation (move away from boids that are too close), alignment
(match the average heading of the boids in view), and cohesion (move toward
their centre) - plus a pull back toward the arena. That is 65,280 neighbour
tests of plain floating-point arithmetic per frame, followed by an integration
pass with a speed clamp. The boids are drawn as short streaks trailing their
velocity, which adds only 512 vertices to the frame.

All four twins implement it line for line: the same constants, the same
two-pass update (steer every boid from the current state, then integrate), the
same 12-iteration Newton square root in place of libm, and the same LCG seeding
the flock after the targets are placed. Like the benchmark, it is switched by a
sibling file: `demo.sh` writes `.flock` before launching a flock-mode run
(`--flock`, or the second half of the benchmark) and deletes it afterwards, and
each twin checks for it once at startup with raylib's `FileExists`. Without the
file none of the flock code runs - nothing is spawned, updated, or drawn - so
the original mode is exactly the original shooter.

### The borrow-checked headless twin

`shooter_headless.jac` is the shooter's game loop with the ownership dial
turned all the way up and the window removed. Every heap-holding binding is
annotated (`w: own World`, `&World` / `&mut World` borrows, `f(&mut w)` call
sites), so the whole program passes Jac's **enforced borrow checker** and
compiles headerless with **no collector and machine-checked zero reference
counting**:

```bash
jac build --native shooter_headless.jac --memory nogc
```

It runs the exact per-frame pipeline of `shooter.jac` -- input, fire
cooldown, bullet integration + hit tests, target respawn and bob -- at a fixed
240 Hz tick, with two substitutions so it needs no window: the human is
replaced by a deterministic scripted pilot built from the same turn/move
constants as `handle_input`, and the rlgl render pass is replaced by a
virtual renderer that folds the very vertex stream `draw_floor`/`draw_box`
would emit (grid lines, six shaded quads per cube, camera pose) into an
integer digest instead of calling `rlVertex3f`. The target/bullet pools live
as parallel arrays inside one owned `World` -- the index-arena idiom from
[ownbench](../ownbench/)'s rbtree kernel, the design-intended shape for pool
mutation under whole-binding affine moves.

`./demo.sh --headless` builds the _same unchanged source_ under all three of
Jac's memory modes -- `none` (enforced ownership, headerless, zero RC), `rc`
(reference counting), `cycles` (rc + cycle collector) -- runs each for
`HEADLESS_FRAMES` frames (default 100000), and prints a table:

```
==== headless shooter benchmark (100000 frames, 240 Hz sim tick) ====
  gc mode       sim FPS    ns/frame    score       digest
  none           187442        5335       34    502241830
  rc             191893        5211       34    502241830
  cycles         188651        5301       34    502241830
  digests identical across gc modes: OK
```

Byte-identical digests across the three builds are the executable witness
that the fully-annotated, collector-free build is a semantics-preserving
drop-in (the ownbench erasure/identity discipline applied to a real game
loop). Because it needs no GPU, no display, and no raylib download, this
mode runs anywhere -- including CI.

### The Zig twin

`shooter.zig` is a faithful Zig port of `shooter.jac`. Like the Jac version,
it **binds raylib by declaring its entry points directly** - here as `extern
fn`, the moral equivalent of Jac's `import from raylib { def ... }` block - so it
needs **no C headers**; the symbols resolve straight out of the precompiled
shared library:

```zig
extern fn InitWindow(width: c_int, height: c_int, title: [*:0]const u8) void;
extern fn rlVertex3f(x: f32, y: f32, z: f32) void;
extern fn rlColor4ub(r: u8, g: u8, b: u8, a: u8) void;
// ...
```

It renders through the same scalar `rlgl` immediate-mode API, so the two builds
are pixel-identical on screen. It exists as the conventional-toolchain baseline:
same precompiled library, but linked the ordinary way (with a
`$ORIGIN`/`@loader_path` runpath so it, too, finds the sibling library). One
wrinkle the Jac backend sidesteps: a conventional linker records raylib's
**SONAME** (`libraylib.so.600`) rather than the plain `libraylib.so`, so the
`--zig` path stages the release's full versioned symlink set beside the binary.

### The Rust twin

`shooter.rs` is the same port again in Rust, kept line-for-line with
`shooter.zig`. It binds raylib the same way, with no bindings crate and no
headers: the entry points are declared in an `unsafe extern "C"` block linked
against the staged library, so the symbols resolve straight out of the
precompiled raylib:

```rust
#[link(name = "raylib")]
unsafe extern "C" {
    fn InitWindow(width: c_int, height: c_int, title: *const c_char);
    fn rlVertex3f(x: f32, y: f32, z: f32);
    fn rlColor4ub(r: u8, g: u8, b: u8, a: u8);
    // ...
}
```

It renders through the same scalar `rlgl` calls and speaks the same
`.bench_seconds` / `.bench_result` protocol, so `demo.sh` benchmarks it exactly
like the other two. The one structural difference is idiomatic: the player and
world state that the Jac and Zig twins keep as module globals live in a single
`Game` struct passed by `&mut`, rather than `static mut`. It is built with plain
`rustc` (`-C opt-level=3 -C codegen-units=1 -C panic=abort`) and an
`@loader_path` / `$ORIGIN` runpath, so like the Zig build it records raylib's
versioned install name and relies on the staged symlink set.

### The Python twin

`shooter.py` is the same port in CPython, kept line for line with
`shooter.zig` and `shooter.rs`. It binds raylib with the standard library's
`ctypes` - each entry point declared with its argument and return types, the
moral equivalent of the `extern` blocks in the other twins - so it needs no
bindings package and loads the very same staged `libraylib`. It renders
through the same scalar `rlgl` calls and speaks the same `.bench_seconds` /
`.bench_result` / `.flock` protocol, so `demo.sh` benchmarks it exactly like
the others. Every raylib call crosses the `ctypes` boundary, so the original
mode measures Python's per-call overhead on top of raylib's own cost, while
flock mode measures the interpreter on pure arithmetic. Set `PYTHON` to choose
the interpreter (`PYTHON=python3.14 ./demo.sh`).

### Controls

| Key / device   | Action                     |
| -------------- | -------------------------- |
| Click window   | Capture mouse for look     |
| Mouse          | Aim (when captured)        |
| Arrow keys     | Aim (look around)          |
| `W` `A` `S` `D`| Move / strafe              |
| `Space`        | Fire                       |
| `Tab`          | Capture / release cursor   |
| `Esc`          | Quit                       |

The window starts with the cursor **free**, so you can move or drag it. Click in
the window (or press `Tab`) to capture the mouse for FPS-style look; `Tab`
releases it again.

The current frame rate is shown top-left. The loop runs **uncapped** (no
`SetTargetFPS`), so it reaches whatever the hardware can sustain.

## Files

| File             | Purpose                                                                |
| ---------------- | ---------------------------------------------------------------------- |
| `shooter.jac` | the whole demo: raylib FFI bindings, wrappers, and the game + render loop |
| `shooter.zig`    | faithful Zig twin of the demo, built with `./demo.sh --zig`            |
| `shooter.rs`     | faithful Rust twin of the demo, built with `./demo.sh --rust`          |
| `shooter.py`     | faithful CPython twin of the demo, run with `./demo.sh --python`       |
| `demo.sh`        | platform detection, download, build, benchmark (default) or run one    |

## Requirements

- The `jac` binary (built via `./scripts/fresh_env.sh`, or installed via the install script) - for the Jac build
  (i.e. the default benchmark and `--jac`).
- A `zig` toolchain - for the Zig build (the default benchmark and `--zig`).
  `demo.sh` downloads one into `.build/` automatically if you don't already have
  it on your `PATH` (nothing system-wide).
- A Rust toolchain (`rustc` >= 1.85) - for the Rust build (the default
  benchmark and `--rust`). `demo.sh` installs a minimal stable toolchain into
  `.build/rust/` via rustup if you don't already have one. Unlike the Jac side,
  `rustc` links through the platform linker (Xcode command-line tools on macOS,
  `cc` on Linux).
- A Python 3 interpreter - for the Python twin (the default benchmark and
  `--python`). No packages are needed beyond the standard library; without one
  the benchmark prints `n/a` for the Python row.
- `curl` and `tar` (used by `demo.sh`; the Zig archive is `.tar.xz`).
- A GPU/desktop with OpenGL 3.3+ and a window system. On Linux that means
  `libGL`/`libX11` (raylib's own transitive dependencies); software rendering
  (Mesa `llvmpipe`) works too.

No C compiler or system linker is required to build the Jac side.

## How the 3D works (a deliberate scalar pipeline)

raylib's headline 3D API passes small math structs **by value** -
`DrawCube(Vector3 position, …)`, `BeginMode3D(Camera3D camera)`. The Jac native
backend lowers struct-by-value calls to the platform C ABI (System V AMD64
eightbyte classification / AArch64 AAPCS), so those entry points _can_ be bound
directly: declare the C struct as an `obj` in the `import from` block and call
the by-value API.

This demo nonetheless builds its 3D pipeline on raylib's lower-level **`rlgl`
immediate-mode API**, which is entirely scalar (`rlVertex3f`, `rlColor4ub`,
`rlTranslatef`, `rlRotatef`, `rlFrustum`, …) - a deliberate choice, not a
workaround. Two reasons: the `shooter.zig` and `shooter.rs` twins bind the same
scalar `rlgl` entry points, so the Jac, Zig, and Rust builds stay line-for-line
comparable and pixel-identical; and the WebGL/DOM `raylib_shim` behind the `web/` build emulates
exactly this scalar `rlgl` surface, so one unchanged game source targets native
_and_ the browser. The camera is a hand-built `rlFrustum` projection plus an
`rlRotatef`/`rlTranslatef` view transform; cubes are drawn the same way raylib
draws its own - `rlPushMatrix` + per-vertex emission. Every FFI call in the
bindings is scalar - even the screen clear goes through `rlClearColor`'s four
`u8` channels rather than `ClearBackground(Color)`, and mouse look reads
`GetMouseX/Y` as `float(GetMouseX())`.
