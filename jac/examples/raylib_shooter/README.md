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
there is **no `cc`/`ld` invocation**; `jac nacompile` emits the object code and
writes the ELF/Mach-O executable itself, recording the resolved library as a
needed entry plus a `$ORIGIN`/`@loader_path` runpath so the sibling library
resolves no matter where the binary is launched from.

## Run it

```bash
./demo.sh         # default: benchmark BOTH builds (8s each), print avg/max FPS
./demo.sh --jac   # build & play only the Jac-native shooter, interactively
./demo.sh --zig   # build & play only the Zig shooter, interactively
```

> **Run it in the browser too:** [`web/`](web/) compiles the _same_ rlgl source to
> WebAssembly (`jac nacompile --target wasm32`) and renders it with WebGL - the
> `import from raylib` externs become the wasm module's imports. See
> [`web/README.md`](web/README.md); run `cd web && ./demo.sh`.

`demo.sh` will:

1. detect your platform/architecture,
2. download the matching precompiled raylib release from GitHub,
3. stage its shared library beside the script (`libraylib.so` on Linux,
   `libraylib.dylib` on macOS),
4. build the shooter(s) it needs:
   - `shooter.na.jac` with `jac nacompile` (no C compiler, no `cc`/`ld`),
     producing `./shooter`;
   - `shooter.zig` with the Zig toolchain against the staged library, producing
     `./shooter_zig`. If `zig` is not already on your `PATH`, the script
     downloads the matching single-archive Zig distribution into `.build/` and
     uses it from there - nothing is installed system-wide;
5. run them: the default **benchmarks** both (see below); `--jac` / `--zig` launch
   one interactively.

### Benchmark mode (default)

With no flag, `demo.sh` runs each build for 8 seconds and prints a table:

```
====== raylib cube shooter benchmark (8s each, uncapped) ======
  build        avg FPS        max FPS       frames
  Jac            461.7          719.9         3694
  Zig            470.5          719.1         3764
===============================================================
```

(Numbers above are from a WSLg + Mesa `llvmpipe` software-rendering box; yours
will differ. The two builds track each other closely - they link the same
precompiled raylib and do identical per-frame work.)

How it works without changing how the demos _play_: a binary can't report FPS to
the shell on its own (raylib paints the counter onto the framebuffer, not
stdout), so each shooter has a small, **dormant** benchmark path. `demo.sh`
writes the requested duration into a sibling `.bench_seconds` file before
launching; each binary reads that file with raylib's own cross-platform helpers
(`FileExists` / `LoadFileText` / `TextToInteger`), and when present it times
itself with raylib's `GetTime`, then writes a `BENCH_RESULT avg max frames
seconds` line to a sibling `.bench_result` file (via raylib's `SaveFileText`) and
exits; `demo.sh` reads that back and cleans both files up. When `.bench_seconds`
is absent - every `--jac` / `--zig` run, or a bare `./shooter` - that path is
skipped entirely and the game loop runs until you close the window, exactly as
before. (The result travels through a file rather than stdout because the demos
go through raylib's own I/O - no `print`, no libc - so the Jac and Zig twins stay
byte-for-byte parallel.)

### The Zig twin

`shooter.zig` is a faithful Zig port of `shooter.na.jac`. Like the Jac version,
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
| `shooter.na.jac` | the whole demo: raylib FFI bindings, wrappers, and the game + render loop |
| `shooter.zig`    | faithful Zig twin of the demo, built with `./demo.sh --zig`            |
| `demo.sh`        | platform detection, download, build, benchmark (default) or run one    |

## Requirements

- The `jac` CLI (`pip install jaclang`, or the repo's `.venv`) - for the Jac build
  (i.e. the default benchmark and `--jac`).
- A `zig` toolchain - for the Zig build (the default benchmark and `--zig`).
  `demo.sh` downloads one into `.build/` automatically if you don't already have
  it on your `PATH` (nothing system-wide).
- `curl` and `tar` (used by `demo.sh`; the Zig archive is `.tar.xz`).
- A GPU/desktop with OpenGL 3.3+ and a window system. On Linux that means
  `libGL`/`libX11` (raylib's own transitive dependencies); software rendering
  (Mesa `llvmpipe`) works too.

No C compiler or system linker is required to build the Jac side.

## How the 3D works (and a caveat)

raylib's headline 3D API passes small math structs **by value** -
`DrawCube(Vector3 position, …)`, `BeginMode3D(Camera3D camera)`. The Jac native
backend does not yet implement the full C struct-by-value ABI for multi-field
float structs, so those entry points can't be called correctly today.

This demo therefore builds its 3D pipeline on raylib's lower-level **`rlgl`
immediate-mode API**, which is entirely scalar (`rlVertex3f`, `rlColor4ub`,
`rlTranslatef`, `rlRotatef`, `rlFrustum`, …) and so crosses the FFI boundary
cleanly. The camera is a hand-built `rlFrustum` projection plus an
`rlRotatef`/`rlTranslatef` view transform; cubes are drawn the same way raylib
draws its own - `rlPushMatrix` + per-vertex emission. Every FFI call in the
bindings is scalar - even the screen clear goes through `rlClearColor`'s four
`u8` channels rather than `ClearBackground(Color)`, and mouse look reads
`GetMouseX/Y` as `float(GetMouseX())`.
