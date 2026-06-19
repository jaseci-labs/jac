# macOS Port - `jac ai --tui` native backend

Status: **planning**. Branches off the in-process default (`8f2bec97c`,
`PLAN-tui-in-process.md`).

> **No Mac hardware locally (decision 2026-06-18).** All validation is
> CI-driven: a cross-compile gate on a Linux runner + native headless gates
>
> + a PTY termios harness on `macos-latest`. The only thing CI can't cover
> is real-terminal visual UX, so **the port lands behind a flag and merge is
> blocked on a human Mac sign-off** (Phase 5). CI green is necessary but not
> sufficient to merge.

Related:

+ `jac-super/jac_super/ai_tui/PORTING.md` - the platform-support matrix and
  high-level per-OS notes (this plan is the concrete macOS breakdown).
+ `PLAN-tui-in-process.md` §16 - distribution/signing risk for the
  `dlopen`'d shared library.
+ `jac-super/jac_super/ai_tui_na/libc_tty.na.jac` - the only Linux-specific
  source file today (verified by grep: it is the sole file referencing
  `/usr/lib/libc.so.6`, `0x5413`, or `TERMIOS_SZ = 60`).

## TL;DR

The macOS port is a **one-module swap**, not a re-architecture. A verified
grep of `ai_tui_na/**/*.na.jac` shows the entire Linux-specific surface lives
in `libc_tty.na.jac` - the libc import, the termios struct size, the flag
bitmasks, the `TIOCGWINSZ` ioctl number, and `O_NONBLOCK`. Everything above
the tty seam (`width`, `tui_core`, `state`, `feed`, `screen`, `components`,
`diff`, `input`, `ipc`, `terminal`) is byte-for-byte shared. And because the
default backend is now **in-process** (`libtui.so` via ctypes), the spawn/
session plumbing surface that `PORTING.md` used to call out for macOS is
already deleted - there is no child to spawn, no `setsid`/`dup2`/fd-3 remap.
So this plan touches **the tty module, the build script, one lib-path line,
and signing/CI.** Nothing else in the sidecar.

Estimated effort: ~1.5–2 weeks of implementation + CI work (no Mac hardware
needed for those phases). The final visual sign-off is a separate, deferred
human step that gates merge (consistent with `PORTING.md`'s ~1–2 weeks, now
CI-shaped rather than interactive-terminal-shaped).

## The real crux is the flag table, not the struct size

Everyone (including the existing `PORTING.md`) says "re-derive the termios
struct size." Having read `libc_tty.na.jac`, the struct size (44 vs 60 bytes)
is the **easy** part. The dangerous diff is that glibc and xnu assign
different numeric values to almost every termios flag. The Linux file bakes
the glibc values into `glob` constants; a single wrong mask yields silently
half-working raw mode - echo left on, `ICANON` not actually cleared (keys
still line-buffered), or `CS8` not set. The TUI would "run" and look broken.

Derived from glibc's `<bits/termios.h>` vs xnu's `<sys/termios.h>`:

| Constant            | glibc (today) | xnu (macOS needs) | same? |
| ------------------- | ------------- | ----------------- | ----- |
| `IGNBRK`            | `0x00000001`  | `0x00000001`      | ✓     |
| `BRKINT`            | `0x00000002`  | `0x00000002`      | ✓     |
| `PARMRK`            | `0x00000008`  | `0x00000008`      | ✓     |
| `ISTRIP`            | `0x00000020`  | `0x00000020`      | ✓     |
| `INLCR`             | `0x00000040`  | `0x00000040`      | ✓     |
| `IGNCR`             | `0x00000080`  | `0x00000080`      | ✓     |
| `ICRNL`             | `0x00000100`  | `0x00000100`      | ✓     |
| `IXON`              | `0x00000400`  | `0x00000400`      | ✓     |
| `OPOST`             | `0x00000001`  | `0x00000001`      | ✓     |
| `PARENB`            | `0x00000100`  | `0x00000100`      | ✓     |
| `ECHO`              | `0x00000008`  | `0x00000008`      | ✓     |
| **`ECHONL`**        | `0x00000040`  | `0x00000010`      | **✗** |
| **`ICANON`**        | `0x00000002`  | `0x00000100`      | **✗** |
| **`ISIG`**          | `0x00000001`  | `0x00000080`      | **✗** |
| **`IEXTEN`**        | `0x00008000`  | `0x00000400`      | **✗** |
| **`CSIZE`**         | `0x00000030`  | `0x00003000`      | **✗** |
| **`CS8`**           | `0x00000030`  | `0x00003000`      | **✗** |
| **`O_NONBLOCK`**    | `0x800`       | `0x00000004`      | **✗** |
| **`TIOCGWINSZ`**    | `0x5413`      | `0x40087468`      | **✗** |

(`c_iflag`/`c_oflag` low bits are POSIX-standardized and survive; `c_lflag`,
`c_cflag` high bits, the ioctl, and `O_NONBLOCK` do not.) **Every ✗ row is a
required change in the Darwin module.** This table is the single most useful
artifact in the port - it is what prevents subtle half-working raw mode.

### Struct layout diff (the easy part)

glibc userspace `struct termios` = 60 bytes (flags ×4, `c_line`, `c_cc[32]`).
xnu `struct termios` = **44 bytes**:

| Field        | xnu offset | size |
| ------------ | ---------- | ---- |
| `c_iflag`    | 0          | 4    |
| `c_oflag`    | 4          | 4    |
| `c_cflag`    | 8          | 4    |
| `c_lflag`    | 12         | 4    |
| `c_cc[NCCS]` | 16         | 20   | (`NCCS = 20`, no `c_line`) |
| `c_ispeed`   | 36         | 4    |
| `c_ospeed`   | 40         | 4    |

`VMIN`/`VTIME` land at `c_cc[16]` / `c_cc[17]` → byte offsets **32** / **33**
(vs glibc's `c_cc[5]@22`, `c_cc[6]@23`). `build_raw_termios` keeps the same
calloc-buffer pattern (never pass the struct by value - that segfaults in
`tcsetattr` under NA FFI on both platforms); only `TERMIOS_SZ`, the VMIN/VTIME
poke offsets, and the flag constants change.

## Source layout

Follow `PORTING.md`'s recommended split, plus an explicit build-time
selection mechanism (the gap `PORTING.md` leaves open):

```
jac_super/ai_tui_na/
  tty/
    libc_tty.linux.na.jac    # the current libc_tty.na.jac, verbatim
    libc_tty.darwin.na.jac   # NEW: libSystem + xnu constants + 44-byte struct
  libc_tty.na.jac            # gitignored; staged by build.sh from tty/
  tui.na.jac                 # unchanged: import from .libc_tty { ... }
  host.na.jac                # unchanged: same priming import of .libc_tty
  (everything else unchanged)
```

`tui.na.jac` and `host.na.jac` keep their existing `import from .libc_tty {…}`
(the DFS-order resolver priming documented in `tui.na.jac` must stay intact).
`tty.na.jac` is **not** a Jac conditional import - Jac AOT imports are static,
and the compiler's `_resolve_clib_lib_name` only swaps the *clib soname*
(`lib<name>.<ext>`) per target triple, not the *Jac source module*. So the
platform module is selected at **build time** (next section), which is the
clean, compiler-free mechanism.

## Build & selection mechanism

`build.sh` is the single source of truth for platform selection. Detect the
host and stage the right tty module into place before `nacompile`:

```bash
# uname -s → linux | darwin (win32 handled in the Windows plan)
case "$(uname -s)" in
  Linux*)  TTY=linux;  LIBEXT=so;     LIBNAME=libtui.so     ;;
  Darwin*) TTY=darwin; LIBEXT=dylib;  LIBNAME=libtui.dylib  ;;
  *) echo "unsupported host"; exit 1 ;;
esac
cp "tty/libc_tty.${TTY}.na.jac" libc_tty.na.jac   # gitignored transient file
trap 'rm -f libc_tty.na.jac' EXIT                  # leave the tree clean

"${JAC[@]}" nacompile tui.na.jac -o "bin/jac-na-tui"
"${JAC[@]}" nacompile host.na.jac --shared -o "bin/${LIBNAME}"
[ "$TTY" = darwin ] && codesign --sign - "bin/${LIBNAME}"   # §signing
```

Why staging (not a per-target build dir, not a compiler `--target` switch):

+ A separate build dir would require copying every shared module to keep
  relative imports resolving - more moving parts for no gain.
+ `nacompile --target darwin` exists for the **clib soname** resolution, but
  does not pick `.darwin.na.jac` source files; making it do so is a compiler
  feature, out of scope for a port (AGENTS.md: one thing per branch).
+ Staging one gitignored file with a trap-cleanup is the minimal, explicit,
  debuggable choice. `.gitignore` gains `ai_tui_na/libc_tty.na.jac`.

Cross-compilation (build mac from linux, or universal arm64+x86_64) is a
**phase-2** concern; `build.sh` just needs the `TTY`/`LIBEXT` vars exposed as
overridable env (`JAC_AI_TUI_TARGET`) so a future CI matrix can set them.

## Phase 1 - the Darwin tty module

`tty/libc_tty.darwin.na.jac` is a copy of the Linux file with these changes
and **only** these changes:

1. **Clib import.** Replace `import from "/usr/lib/libc.so.6" {…}` with
   `import from "/usr/lib/libSystem.B.dylib" {…}`. The Mach-O linker keeps
   absolute paths verbatim (`macho_linker.impl.jac:781`) and already adds
   libSystem as ordinal 1 (`macho_linker.jac:62`), so every `def open/read/
   write/dup2/fcntl/ioctl/tcgetattr/tcsetattr/poll/calloc/free/memset/memcpy`
   resolves. The `def` signatures are byte-identical - `poll` and `termios`
   calls have the same C ABI on darwin.
2. **Flag table.** Apply every **✗** row from the table above. The ✓ rows
   stay (defensive: re-state them in the Darwin file rather than sharing, so
   each platform file is self-contained and grep-able - matches the
   "self-contained per-platform" intent in `PORTING.md`).
3. **`TERMIOS_SZ = 44`.**
4. **VMIN/VTIME poke offsets** in `build_raw_termios`: `memset(p + 32, 1, 1)`
   (VMIN=1) and `memset(p + 33, 0, 1)` (VTIME=0). Mind the index→offset: xnu
   `VMIN=cc[16]`, `VTIME=cc[17]`, `c_cc` base = 16.
5. **`TIOCGWINSZ = 0x40087468`**, **`O_NONBLOCK = 0x00000004`**.
6. Everything else - `tty_open`/`tty_close`/`tty_poll`/`tty_read_key`/
   `tty_read_line`/`tty_write`/`tty_update_size`/`tty_rows`/`tty_cols`/the
   stdio-remap stubs, the `TtyCtx` obj, `g_tty`, `_tty_device_path` - is
   **unchanged**. `/dev/tty`, `/dev/pts/N`, `os.ttyname()`, `poll()`,
   `dup2`, `start_new_session` (in the control plane) all work identically on
   macOS.

### First thing to validate (de-risks the whole port - no Mac needed)

Two cheap CI gates replace the old "run a smoke on a Mac" step:

1. **Cross-compile gate (Linux runner).** `nacompile --target darwin` on an
   adaptation of `proto/no_c_termios_smoke.na.jac` (libSystem + 44-byte
   termios) must produce a valid Mach-O linking libSystem. Can't run it on
   Linux, but it catches the bulk of the "does the compiler's Mach-O path
   handle our calloc'd-struct-buffer / `ioctl(i64)` FFI" risk - the Mach-O
   backend is less exercised than ELF and these patterns specifically have
   not run on Mach-O. **If a compiler bug surfaces here, stop and open a
   separate branch** (AGENTS.md); expect 1–2 Mach-O-side fixes analogous to
   the `PT_GNU_STACK` one the in-process swap needed.
2. **PTY termios harness (macos-latest runner).** See §"Validation without
   Mac hardware" - a PTY allocation + `tcgetattr` assertion that directly
   validates the flag table against reality on real macOS, with no human and
   no real terminal.

## Phase 2 - control-plane lib-path branch

One function changes; the macOS path is otherwise identical to Linux (POSIX):

`tui_host.jac::_tui_lib_path`:

```python
def _tui_lib_path(pkg_root) -> str:
    import sys;
    name = "libtui.dylib" if sys.platform == "darwin" else "libtui.so";
    return str(pkg_root / "ai_tui_na" / "bin" / name);
```

`os.path.abspath` before `CDLL` (already present, `tui_host.jac:26`) covers
the Windows DLL-search footgun and is harmless on macOS. `_ensure_tui_lib`'s
error strings say `libtui.so`; leave them generic or pass the resolved name
through - cosmetic. `run_tui_in_process.impl.jac` needs **no** change:
`os.ttyname()` works on macOS and `JAC_AI_TUI_TTY` (`/dev/ttys003`) flows
through unchanged.

## Phase 3 - signing & distribution

The artifact flips from `libtui.so` to `libtui.dylib`. New hazards
(`PLAN-tui-in-process.md` §16):

+ **Ad-hoc signing is mandatory on Apple Silicon.** An unsigned `.dylib`
  loaded by CPython under the hardened runtime/Gatekeeper is refused. Build
  step: `codesign --sign - bin/libtui.dylib` right after `nacompile --shared`.
  Verify the load in CI (`CDLL` succeeds on `macos-latest` arm64).
+ **Notarization** - only if/when the jac-super wheel is notarized; the dylib
  is then in the ticket's scope. The pre-existing executable had the same
  requirement, so this is not *new*. Defer until a notarization policy exists.
+ **Architecture** - start with the CI runner's native arch. Universal
  (`lipo arm64 x86_64`) or per-arch dylibs + selection is phase 2.

## Validation without Mac hardware

Three CI pillars replace "iterate at a Mac terminal," plus one gap that stays
human:

1. **Cross-compile gate (Linux runner).** `nacompile --target darwin
   host.na.jac --shared -o libtui.dylib` from the Linux CI job. Proves the
   compiler's Mach-O backend emits a loadable dylib linking libSystem for
   this code's FFI shape (calloc'd struct buffers, `ioctl(i64)`, the `def`
   import block). Can't run it on Linux, but `file` / `llvm-objdump` assert
   it's Mach-O 64-bit with a libSystem load command. Cheap, catches the
   Mach-O codegen risk before any macOS runner is involved.
2. **Native headless gates (macos-latest runner).** `test_host.py` (CDLL load
   + `apply_frame`/`render`) and `bin/test_pickers` run unchanged - no real
   TTY needed. These are the reliable "does it run on macOS at all" signals.
3. **PTY termios harness (macos-latest runner) - validates the crux.** A small
   harness that:
   + allocates a PTY (`os.openpty()`),
   + sets `JAC_AI_TUI_TTY` to the slave name,
   + drives `tty_open` (via a tiny NA test binary or the shared lib's exports),
   + reads the PTY's termios back from the **master** side and asserts the
     raw-mode masks: `ECHO`/`ICANON`/`ISIG`/`IEXTEN` cleared in `c_lflag`;
     `CS8` set and `PARENB` clear in `c_cflag`; `ICRNL`/`IXON` clear in
     `c_iflag`; `OPOST` clear in `c_oflag`; `VMIN=1`/`VTIME=0` at the xnu
     `c_cc` offsets.
   This directly checks the glibc-vs-xnu flag table against reality. A wrong
   `ICANON` value (the most likely typo) fails this assertion loudly.
4. **The gap (human-only).** The PTY proves raw mode is *applied*; it cannot
   prove the rendered output looks right on Terminal.app/iTerm2/Warp, that
   resize works over SIGWINCH, or that Option-key byte sequences are what
   `tty_read_key` expects. That is Phase 5, and it gates merge.

Optional cheap probe: on the macOS runner, `cc -E`/`ctypes` `<sys/termios.h>`
and print the real `ECHO`/`ICANON`/`CS8`/etc. constants, diffed against the
values in `tty/libc_tty.darwin.na.jac`. Catches header-drift in the table
independent of the runtime harness.

## Phase 4 - CI (cross-compile + native)

Two jobs, in whatever workflow already builds the jac-super NA artifacts:

**Linux job (cross-compile gate):**

1. `JAC_AI_TUI_TARGET=darwin ./build.sh` (or a `--target darwin` path) →
   `nacompile --target darwin host.na.jac --shared -o bin/libtui.dylib`.
2. Assert `bin/libtui.dylib` is Mach-O 64-bit and links libSystem
   (`llvm-objdump` / `file`). Do **not** attempt to run it.

**macos-latest job (native):**

1. `./build.sh` → `bin/libtui.dylib` + `bin/jac-na-tui` (Mach-O).
2. `codesign --sign - bin/libtui.dylib`.
3. Headless host gate: `python test_host.py` (no TTY).
4. Picker logic: `bin/test_pickers`.
5. PTY termios harness (§"Validation without Mac hardware" pillar 3).
6. Optional: the `<sys/termios.h>` constant probe.

The libc `proto/no_c_*` smokes need a controlling terminal; skip on CI unless
the PTY harness subsumes them. **CI green is necessary but not sufficient to
merge** - Phase 5 still gates.

## Phase 5 - human Mac sign-off (merge gate)

**This phase blocks merge.** It is the one thing CI cannot cover. Interactive,
requires Mac hardware - deferred until a maintainer (or contributor) with a
Mac runs it; until then the macOS artifact ships behind a flag and stays off
the default lib-path resolution. The checklist for whoever runs the sign-off:

+ **Terminal.app, iTerm2, Warp.** Warp is the interesting one - its block/
  prompt model sometimes fights alt-screen apps; verify the `?2026h` sync
  wrap (`render.na.jac`) and full-screen takeover.
+ Resize handling (`SIGWINCH` → `tty_update_size` via `TIOCGWINSZ`).
+ Key sequences: arrows (`\x1b[A…`), Home/End/PageUp/Down, fn-keys. macOS
  Terminal sends standard CSI; mostly parity with Linux. **Option/Alt** key
  (ESC-prefixed or special glyphs) is a **phase-2 follow-up**, same as
  `PORTING.md` §"Keyboard follow-ups".

A sign-off checklist file (e.g. `ai_tui/SIGNOFF-darwin.md`) should capture
the runner above, the OS/arch, the terminals tried, and the result, so the
human pass is reproducible rather than ad-hoc.

## Sequencing

| Phase | Work | Effort |
| ----- | ---- | ------ |
| 1 | `tty/libc_tty.darwin.na.jac` (table + 44 + offsets + ioctl/O_NONBLOCK + libSystem); validate Mach-O FFI with an adapted termios smoke first | 3–4 days |
| 2 | `build.sh` host detection + staging; `_tui_lib_path` branch; `.gitignore` | 1 day |
| 3 | `codesign` step; verify `CDLL` load on arm64 | 1 day |
| 4 | Linux cross-compile gate + `macos-latest` CI (host gate + pickers + PTY termios harness) | 2 days |
| 5 | Human Mac sign-off (Terminal.app/iTerm2/Warp) - **merge gate** | deferred |

Phases 1–4 are the port and need **no Mac hardware**. Land them **behind a
flag** (e.g. `JAC_AI_TUI_DARWIN=1`, and/or a non-default `libtui.dylib`
artifact) and keep macOS **off** the default `_tui_lib_path` resolution until
Phase 5 passes. CI green is necessary but not sufficient to merge.

## Risks & open questions

1. **The flag table is the crux** (see §crux). Mitigation: derive from xnu
   headers, then auto-check in CI with a one-off probe (risk 7) that prints
   the real `ECHO`/`ICANON`/`CS8`/etc. values on the `macos-latest` runner
   before trusting the table.
2. **Mach-O FFI parity with ELF** is unproven for this code's specific
   patterns (calloc'd struct buffers, `ioctl(i64)`). This is where a compiler
   bug is most likely; validate early (Phase 1 cross-compile gate) and fork to
   a separate branch if one appears.
3. **`ioctl` request encoding.** xnu `TIOCGWINSZ = 0x40087468` is an
   `_IOR`-encoded value (dir/size/type/num). The `i64` arg carries it fine,
   but the literal must be exact - a transposed digit silently returns
   `ENOTTY` and `tty_update_size` quietly keeps 24×80.
4. **Warp terminal** may not behave like a conventional alt-screen terminal;
   decide whether v1 supports it or documents it out.
5. **Architecture matrix** (arm64 vs x86_64, universal) - deferred, but the
   `TTY`/`LIBEXT` env hooks in `build.sh` should land now so phase 2 doesn't
   re-plumb.
6. **PTY ≠ real terminal (residual - why Phase 5 exists).** The PTY termios
   harness proves the flag table is *applied* to a tty-like device, but a PTY
   is not Terminal.app/iTerm2/Warp: it can't catch wrong rendering, alt-screen
   takeover, `?2026h` sync, the SIGWINCH resize path, or Option-key byte
   sequences. A green PTY gate does **not** mean the TUI looks right on a Mac
   + that gap is exactly what the human Phase 5 sign-off closes, and why merge
   is blocked on it.
7. **Flag-table derivation without a local runtime check.** With no Mac to
   eyeball, the table rests on xnu headers + the PTY assertion. Cross-check
   each ✗ value against `<sys/termios.h>` on the `macos-latest` runner (a
   one-line `cc -E` / `ctypes` probe in CI) before trusting it - don't rely
   on transcribing from a secondhand source.

## Out of scope (this branch)

+ Windows (`console.win32.na.jac` + ConPTY) - `PLAN-tui-windows.md`.
+ Notarization of the jac-super wheel.
+ Universal-binary / per-arch artifact selection.
+ Option/Alt and terminal-specific fn-key variants (phase-2 keyboard).

## Changelog

| Date       | Phase | Notes |
| ---------- | ----- | ----- |
| 2026-06-18 | plan  | Initial macOS port plan. Verified the Linux-specific surface is contained in `libc_tty.na.jac` alone; derived the glibc-vs-xnu flag table; chose build-time tty-module staging over a compiler `--target` source switch. |
| 2026-06-18 | plan  | **No Mac hardware** - reshaped validation to CI-first: added a Linux cross-compile gate, a `macos-latest` PTY termios harness that auto-validates the flag table (the crux), and deferred real-terminal UX to a human Phase 5 **merge gate**. Port lands behind a flag; CI green is necessary but not sufficient to merge. |
