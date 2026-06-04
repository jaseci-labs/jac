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
./demo.sh
```

`demo.sh` will:

1. detect your platform/architecture,
2. download the matching precompiled raylib release from GitHub,
3. stage its shared library under the platform's natural name (`libraylib.so` on
   Linux, `libraylib.dylib` on macOS),
4. compile `shooter.na.jac` with `jac nacompile`, and
5. launch the resulting `./shooter` binary.

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
| `demo.sh`        | platform detection, download, link, run                                |

## Requirements

- The `jac` CLI (`pip install jaclang`, or the repo's `.venv`).
- `curl` and `tar` (used by `demo.sh`).
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
