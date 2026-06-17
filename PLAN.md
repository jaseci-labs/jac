# Jac NA TUI Plan - pi-inspired, zero render deps

> **Goal:** A high-quality `jac ai --tui` experience built entirely in Jac NA +
> libc (via `libc_tty.na.jac`), with **no custom C files** and **no external
> rendering dependencies** (no OpenTUI, no Bun/npm TUI packages).
> [`reference/pi`](reference/pi) is the **implementation spec** - algorithms and
> architecture are ported into `.na.jac`; pi is never a package dependency.
>
> Feature parity with pi's coding-agent TUI is **incremental**. The architecture
> must support expanding toward everything pi supports (editor, markdown,
> overlays, selectors, tools, images) without rewrites.

## Principles

1. **No render deps in jac-super** - terminal I/O is libc FFI + Jac only. No
   `@opentui/core`, no `@earendil-works/pi-tui`, no vendored npm packages for
   drawing. **No custom `.c` shims** - `tui_helpers.c` is replaced by
   `libc_tty.na.jac` (POC-validated).
2. **pi as spec, not dependency** - read `reference/pi/packages/tui` and
   `reference/pi/packages/coding-agent/src/modes/interactive/components` when
   porting; copy patterns and algorithms, not TypeScript files.
3. **Keep the protocol seam** - `PROTOCOL.md` + `run_tui_session` stay frozen.
   Agent ↔ sidecar remains text frames (`EV:id:kind:node:text`). Agent and UI
   evolve independently.
4. **Component tree from day one** - adopt pi-tui's `Component` interface early.
   Flat `render_full()` painting is transitional; the component spine is what
   makes pi-scale features possible later.
5. **Incremental shipping** - every phase is usable on its own.

## Architecture

Two layers, cleanly separated (same split pi uses internally):

```
┌─────────────────────────────────────────────────────────┐
│  Agent (jac) - exists today                             │
│  bus → frames (EV:id:kind:node:text)                    │
│  event kinds grow richer over time                      │
└───────────────────────┬─────────────────────────────────┘
                        │ PROTOCOL.md (frozen)
┌───────────────────────▼─────────────────────────────────┐
│  Sidecar (ai_tui_na) - pi-tui architecture in Jac NA    │
│                                                         │
│  ipc / state     ← frame parser, event store  [have]    │
│  feed            ← event → display projection [have]    │
│  screen          ← root Container, layout      [new]     │
│  components/     ← Text, Input, Editor, …     [new]     │
│  tui/            ← diff render engine           [new]     │
│  libc_tty.na.jac ← raw tty, poll, ioctl, termios [POC]  │
│  terminal.na.jac ← escape sequences, write batch [new]    │
│  utils/          ← width, wrap, ANSI          [new]     │
└─────────────────────────────────────────────────────────┘
```

**Do not** port `interactive-mode.ts` wholesale (it is wired to pi's
`AgentSession`, pi-ai message types, extensions, and theme tooling).

**Do** port pi-tui's engine + individual components, wired to existing
`TuiState` / `feed`.

## Terminal layer - `libc_tty.na.jac` (no custom C)

POC (`proto/libc_tty.na.jac`, `proto/no_c_smoke.na.jac`) proved that all
`tui_helpers.c` functionality can live in Jac via direct libc FFI. The binary
links **only** `libc.so.6` + `libm.so.6` - no `libtui_helpers.so`, no `gcc` in
`build.sh`.

| Layer | Owns |
|-------|------|
| **`libc_tty.na.jac`** | tty open/close, raw mode, fd remap, `ioctl`, `poll`, `read`/`write`, key/line readers |
| **`terminal.na.jac`** | Escape-sequence helpers (alt screen, cursor, clear), write batching, optional CSI 2026 wrappers |
| **Jac (`tui/`, `screen/`, `components/`)** | Component tree, layout, diff render logic, theme tokens |

Promote `proto/libc_tty.na.jac` → `libc_tty.na.jac` at package root during
phase 0a. Delete `tui_helpers.c` once wired.

### Libc FFI patterns (validated in POC)

These are the rules discovered while porting `tui_helpers.c` to NA. Follow them
in all terminal code.

#### Import syntax

```jac
# C library - clib import block with def declarations + optional clib structs
import from "/usr/lib/libc.so.6" {
    def open(path: str, flags: i32, mode: i32) -> i32;
    def ioctl(fd: i32, request: i64, arg: str) -> i32;
    obj Termios { has c_iflag: u32, ...; }
}

# Jac module - symbol list only (NOT def declarations)
import from .libc_tty { tty_open, tty_close, tty_poll, tty_read_key }
```

Using `def` in a `.na.jac` module import makes nacompile treat it as a C FFI
import and emit a bogus `DT_NEEDED` for `lib<module>.so`. Always use the symbol
list form for Jac modules.

#### Type rules

| Jac side | FFI decl | Notes |
|----------|----------|-------|
| `int` locals, object fields | `i32` params/returns | Jac `int` = i64; coerce at call boundary |
| `str` | `str` (i8*) | `calloc` return assigns to `str`; kernel may write in-place |
| `i64` | `ioctl` request arg | `TIOCGWINSZ = 0x5413` as `int`, pass to `i64` slot |
| clib `Termios` struct | `tcsetattr` input only | Input-by-value works; output copy-back does not |

Avoid `i32` locals mixed with integer literals in binary ops - use `int`
everywhere on the Jac side (same rule as `opentui_helpers.na.jac`).

#### Syscall patterns

| Operation | Pattern | Why |
|-----------|---------|-----|
| **Scalar I/O** | `open`, `close`, `read`, `write`, `dup2`, `fcntl` directly | Just works |
| **`ioctl(TIOCGWINSZ)`** | `ws: str = calloc(8, 1)` → `ioctl(fd, req, ws)` → `ord(ws[i])` | Struct output via `str` buffer; `i64` request type |
| **`tcgetattr`** | `term: str = calloc(60, 1)` → `tcgetattr(fd, term)` → `read_u32(term, off)` | glibc `termios` is 60 bytes; read fields with `ord()` |
| **`tcsetattr`** | Build `Termios` struct in Jac → `tcsetattr(fd, TCSANOW, term)` | Input-by-value works; use `termios_from_buf()` to restore saved state |
| **`poll`** | `pack_pollfd(fd, POLLIN)` → 8-byte string; concat for multiple fds | `Pollfd` clib struct fails at runtime; packed string works and `revents` updates in-place |
| **Read key/byte** | `buf: str = calloc(n, 1)` → `read(fd, buf, 1)` → `ord(buf[0])` | Same buffer pattern as `read(2)` smoke test |

Helper shapes (from POC):

```jac
def read_u32(buf: str, off: int) -> int {
    return ord(buf[off]) | (ord(buf[off+1]) << 8)
         | (ord(buf[off+2]) << 16) | (ord(buf[off+3]) << 24);
}

def pack_pollfd(fd: int, events: int) -> str {
    return chr(fd & 0xFF) + chr((fd >> 8) & 0xFF)
         + chr((fd >> 16) & 0xFF) + chr((fd >> 24) & 0xFF)
         + chr(events & 0xFF) + chr((events >> 8) & 0xFF)
         + chr(0) + chr(0);
}
```

#### What does NOT work (yet)

| Approach | Result |
|----------|--------|
| clib struct as **output** arg (`ioctl(fd, req, Winsize())`) | `tcgetattr`/`ioctl` return -1 or fields stay zero |
| `Pollfd` struct for `poll` | Returns -1 even with a TTY |
| `ptr` subscript read/write in product code | Compile errors or unsupported in NA |
| `str` subscript **assignment** (`buf[i] = chr(c)`) | Not implemented in NA - build new strings or use struct input |
| `import from .mod { def foo... }` for Jac modules | Emits spurious `libmod.so` dependency |

#### Runtime requirements

- **Controlling terminal required** - `open("/dev/tty")`, `ioctl`, `tcgetattr`
  return -1 without a TTY (e.g. piped CI). Smoke tests use `script` or manual
  run; CI should skip or use a pseudo-tty wrapper.
- **No libc setup in `glob` init** - call `tty_open()` inside `with entry`, not
  `glob fd = tty_open()`. Global init calling libc/termios triggered `abort()` in
  the POC.

#### glibc `termios` layout (Linux x86_64)

For `termios_from_buf()` when restoring saved state:

| Field | Byte offset |
|-------|-------------|
| `c_iflag` | 0 |
| `c_oflag` | 4 |
| `c_cflag` | 8 |
| `c_lflag` | 12 |
| `c_line` | 16 |
| `c_cc[0..31]` | 17–48 |
| `c_ispeed` | 52 |
| `c_ospeed` | 56 |
| **total** | **60** |

## FD remap (critical - extract before deleting OpenTUI)

Today fd remap lives inside `otui_init()` in `opentui_helpers.c`:

```
dup2(1, 3)  →  fd 3 = IPC out pipe  (saves original stdout)
dup2(2, 1)  →  fd 1 = terminal      (was stderr)
```

After remap:

| fd | Role |
|----|------|
| 0 | IPC in (stdin - unchanged) |
| 1 | terminal (ANSI output) |
| 2 | terminal (stderr - unchanged) |
| 3 | IPC out (`SEND:` / `STOP` / `QUIT` / `APPLY:`) |

**Phase 0a:** move to `libc_tty.na.jac` as `tty_init_stdio_remap()` /
`tty_restore_stdio()` / `tty_ipc_fd()` using libc `dup2` directly. `tui.na.jac`
calls these instead of `otui_init()`; `ipc_fd` comes from `tty_ipc_fd()`, not
`otui_ipc_fd()`.

Keep the keyboard fd ≥ 10 (`F_DUPFD`) so `dup2(1,3)` cannot clobber it.

## Existing spikes

| File | Status | Use |
|------|--------|-----|
| `proto/libc_tty.na.jac` | **POC pass** (scalar + termios + poll) | Promote to `libc_tty.na.jac` |
| `proto/no_c_smoke.na.jac` | **PASS** - open/dup2/write | libc FFI sanity |
| `proto/no_c_buf_smoke.na.jac` | **PASS** (with TTY) - ioctl/tcgetattr | buffer pattern proof |
| `proto/no_c_poll_pack_smoke.na.jac` | **PASS** - packed pollfd | poll pattern proof |
| `proto/no_c_poc.na.jac` | compiles; runtime fix in progress | full interactive demo |
| `proto/rawmode_proto.na.jac` | alt-screen sequences (used `tui_helpers.c`) | reuse escape sequences in `terminal.na.jac` |

## Resize handling

Width changes invalidate wrapped-row caches and trigger a full redraw in diff
render (same as pi).

**v1:** call `tty_update_size()` every main-loop iteration (`ioctl(TIOCGWINSZ)`
via calloc buffer). Compare `term_cols` / `term_rows`; set `layout_dirty` on
width change.

**Later (optional):** `SIGWINCH` - only if polling proves insufficient. No C
handler needed for v1; can add later via libc `signal` if ever required.

## Extension spine (adopt in phase 1)

Port pi's component contract early - everything else hangs off it.

**Validate the NA pattern first:** compile a minimal `Component` + `Container`
stub before locking the API.

```jac
# tui/component.na.jac - same contract as pi packages/tui
obj Component {
    def render(width: int) -> list[str];
    def handle_input(data: str) -> bool;  # true if consumed
    def invalidate -> None;
}

obj Container(Component) {
    has children: list[Component] = [];
    # render = vertical concat of children
}
```

`TUI` (`tui/core.na.jac`) owns **focus routing**: walk focused child and call
`handle_input`; `true` means the key was consumed.

Main loop (`tui.na.jac`):

1. `tty_poll` → read IPC frames / keys
2. `tty_update_size` → detect terminal resize
3. `ipc_read_frame_v2(state, …)` (unchanged)
4. `screen.sync(state)` - update component tree from state
5. `tui.request_render()` when dirty
6. `tui.paint()` - differential ANSI via `diff.na.jac`

`render.na.jac` (flat OpenTUI / cell paint) is **removed** once phase 1 lands.

## State → components (adapter layer)

Keep `TuiState` + protocol. Add `screen.sync(state)`:

| `TuiState` change | Component action |
|-------------------|------------------|
| New `user` event | `transcript.add_child(UserMessage(…))` |
| Upsert `answer` id N | find or create `AssistantMessage` for id N |
| `reasoning` streaming | same component, `invalidate()` |
| `call` / `tool_result` | `ToolBlock` component |
| `STATUS` / `MODEL` frame fields | update `Header` / `StatusBar` |
| Input buffer | `Editor` or `Input` child |

**v1 shortcut:** transcript section can be a single `TranscriptComponent` that
calls `build_rows()` internally until id-keyed components exist.

## Target module layout

```
jac-super/jac_super/ai_tui_na/
  libc_tty.na.jac          # terminal I/O - libc FFI, no .c (from proto/)
  terminal.na.jac          # escape sequences, write batching
  proto/                   # POC smoke tests (keep until product wired)
    libc_tty.na.jac          # canonical POC copy during transition
    no_c_smoke.na.jac
    no_c_poc.na.jac
  tui/
    component.na.jac
    core.na.jac
    diff.na.jac
    overlay.na.jac           # later
  utils/
    width.na.jac
    wrap.na.jac
    ansi.na.jac
  components/
    text.na.jac
    truncated_text.na.jac
    input.na.jac
    editor.na.jac            # later
    markdown.na.jac          # later
    select_list.na.jac       # later
    loader.na.jac
    tool_block.na.jac
    user_message.na.jac
    assistant_message.na.jac
  theme.na.jac               # phase 2
  screen.na.jac
  state.na.jac               # keep
  feed.na.jac                # keep
  ipc.na.jac                 # keep
  input.na.jac               # keep until merged into components/
  tui.na.jac                 # entry - slim main loop
```

**Remove:** `tui_helpers.c`, `libtui_helpers.so`, all `opentui_*` files.

**Build:** `nacompile tui.na.jac -o bin/jac-na-tui` only - no `gcc`, no Bun.

## No external deps - what pi uses and how we replace it

| pi-tui uses | Jac NA approach |
|-------------|-----------------|
| `process.stdin/stdout` raw mode | `libc_tty.na.jac` + `terminal.na.jac` |
| ANSI diff render (`tui.ts`) | `tui/diff.na.jac` |
| `get-east-asian-width` | `utils/width.na.jac` (ASCII-first, then CJK) |
| `marked` | `components/markdown.na.jac` (Jac subset parser) |
| Kitty / iTerm images | optional phase 8 |
| Native darwin/win32 modifiers | optional; keyboard via `tty_read_key` first |

### CSI 2026 synchronized output

Wrap diff-render bursts in `\x1b[?2026h` … `\x1b[?2026l` when supported.
**Fallback:** plain ANSI diff without the wrapper - correctness does not depend
on CSI 2026.

## `ai_tui_js` backend - short and long term

| Horizon | Policy |
|---------|--------|
| **Now** | **NA (`jac-na-tui`) is the primary TUI.** Pure libc, nacompile-only, phase 0a landed. |
| **Short term** | JS OpenTUI sidecar (`ai_tui_js`) is legacy dev fallback only when explicitly built; default launcher may still try `js` then fall back to `na` until default flips. |
| **Long term** | Retire JS OpenTUI render path; keep `ai_tui_js` protocol tests only. |
| **Never** | Change `PROTOCOL.md` or `run_tui_session` framing for a backend swap. |

## Testing

| Layer | What | Spec / location |
|-------|------|-----------------|
| **Protocol** | Frame parse, command emit | `test_ai_tui_bridge.jac`, `PROTOCOL.md` |
| **Libc tty** | open/dup2, ioctl, tcgetattr, poll | `proto/no_c_smoke.na.jac`, `proto/no_c_buf_smoke.na.jac`, `proto/no_c_poll_pack_smoke.na.jac` |
| **Headless render** | `Component.render(w)` → diff → assert ANSI | pi `tui-render.test.ts` scenarios |
| **Resize** | Width change → full redraw | pi `tui-shrink.test.ts` patterns |
| **Integration** | `jac ai --tui` end-to-end | CI with pseudo-tty or skip |

Libc smoke tests need a controlling terminal - run under `script` locally; CI
should not assume a TTY unless wrapped.

### Cleanup on OpenTUI removal

Delete FFI experiment files (`test_ffi.na.jac`, `test_ptr_*.na.jac`,
`test_noscalar_*.na.jac`) and all `opentui_*` / `tui_helpers.c` artifacts.

## Incremental roadmap

| Phase | Ship | Borrow from pi | Notes |
|-------|------|----------------|-------|
| **0a** | `libc_tty.na.jac` wired + fd remap + full ANSI redraw | `terminal.ts` escapes; POC patterns | No custom C; no OpenTUI yet |
| **0b** | Delete OpenTUI; `nacompile`-only `build.sh` | - | No `gcc`, no Bun, no `.so` helpers |
| **1** | `Component` + `Container` + `TUI` diff render | `tui.ts` `doRender` (simplified v1) | Foundation for later phases |
| **2** | `width.na.jac` + `theme.na.jac`; restyle transcript | `user-message.ts` / `assistant-message.ts` look | Fixes naive `_trunc` |
| **3** | `Editor` or upgraded multiline `Input` | `editor.ts` incrementally | |
| **4** | Minimal markdown | `markdown.ts` logic, not `marked` | |
| **5** | `ToolBlock` | `tool-execution.ts` patterns | |
| **6** | Overlays + `SelectList` | `tui.ts` overlays; `select-list.ts` | |
| **7** | Autocomplete, fuzzy file complete | `autocomplete.ts` | |
| **8** | Images, OSC-8, Kitty (optional) | `terminal-image.ts` | |

## What to keep vs replace

| Keep | Replace / remove |
|------|------------------|
| `PROTOCOL.md`, `run_tui_session` | `opentui_helpers.*`, `opentui_shim.c`, `libopentui.so` |
| `state.na.jac`, `ipc.na.jac`, `feed.na.jac` | `render.na.jac` flat cell paint |
| `input.na.jac` key → `SEND:` / `STOP` logic | evolves into `components/input` or `editor` |
| `proto/libc_tty.na.jac` (until promoted) | `tui_helpers.c`, `libtui_helpers.so` |
| `ai_tui_js` protocol/state tests | `ai_tui_js` OpenTUI render path |
| FFI experiment tests | delete with OpenTUI |

## Phase 0 + 1 - recommended first move

Target ~1 week, sequenced to avoid a broken `jac ai --tui` window:

### Phase 0a - libc tty + ANSI redraw

1. **Promote `proto/libc_tty.na.jac`** → `libc_tty.na.jac`; wire `tui.na.jac`
   to `tty_*` API instead of `tui_helpers` / `opentui_helpers`.
2. **Fd remap in `libc_tty.na.jac`** - `tty_init_stdio_remap()` /
   `tty_restore_stdio()` via libc `dup2`.
3. **Add `terminal.na.jac`** - alt-screen, cursor, clear (sequences from
   `rawmode_proto.na.jac`).
4. **Replace `render_full`** with full ANSI redraw to fd 1 (same layout, string
   paint). All tty setup inside `with entry`, not `glob` init.
5. Verify `jac ai --tui` NA backend end-to-end (interactive terminal).

### Phase 0b - delete OpenTUI + C

1. **Delete** all `opentui_*` files and `tui_helpers.c`.
2. **Simplify `build.sh`** to `nacompile` only - no `gcc`, no `find ~/.bun`.
3. **Delete** FFI experiment tests.

### Phase 1 - component spine + diff render

1. Validate `Component` / `Container` compiles in NA.
2. Add `tui/component.na.jac`, `tui/core.na.jac`, `tui/diff.na.jac`.
3. Add `screen.na.jac`; wire `screen.sync` + `tui.paint`.
4. Add headless diff-render tests from pi `tui-render.test.ts`.

### Graceful shutdown

On exit: restore termios (`tty_close`), leave alt screen, restore stdio fds
(`tty_restore_stdio`) - never leave raw mode or alternate buffer active.

## pi coding-agent components - why not copy the TS files

Port **visual intent** into `components/*.na.jac` fed by `TuiState` - not the
TS files (they assume `AgentSession`, chalk themes, in-process mutation).

## Success criteria

- `jac ai --tui` runs with **only** `jac-na-tui` - links `libc.so.6` only; no
  custom `.c`, no Bun, no `libopentui.so`, no npm for rendering.
- `build.sh` is `nacompile` only (no `gcc`).
- Streaming chat is flicker-free (diff render) by end of phase 1.
- Headless diff-render tests match pi core scenarios.
- Terminal always restored on exit.
- `reference/pi` remains a diffable spec for terminal behavior.

## Status log

| Date | Phase | Notes |
|------|-------|-------|
| 2026-06-16 | - | Prior work: protocol seam, `state`/`ipc`/`feed`/`input`, JS parity tests. OpenTUI still in NA/JS paths. |
| 2026-06-16 | - | Plan rewritten: pi-inspired component architecture, zero render deps. |
| 2026-06-16 | - | Plan clarified: fd remap, 0a/0b/1 sequencing, testing, CSI 2026, `ai_tui_js` policy. |
| 2026-06-17 | POC | **No custom C validated:** `proto/libc_tty.na.jac` + smoke tests. libc FFI patterns documented. `tui_helpers.c` slated for removal. `no_c_poc` compiles (libc-only); runtime init-order fix pending. |
| 2026-06-17 | 0a | **Phase 0a complete:** `libc_tty.na.jac` promoted from proto; `terminal.na.jac` (ANSI helpers, f-string sequences); `render.na.jac` ported to ANSI (_dt helper, CSI 2026 sync, true-color SGR); `tui.na.jac` rewired to libc_tty (all libc in `with entry`, no glob-init abort); `ipc.na.jac` now imports `tty_read_line`/`tty_write` from libc_tty; `build.sh` nacompile-only. Binary links libc.so.6 + libm.so.6 only - zero OpenTUI, zero custom C. |
| 2026-06-17 | 0b | **Phase 0b complete:** deleted `opentui_helpers.c`, `opentui_shim.c`, `tui_helpers.c`, `opentui_helpers.na.jac`, all `libopentui*`/`libtui_helpers.so`, FFI test files (`test_ffi.na.jac`, `test_noscalar_*`, `test_ptr_*`). Binary still compiles clean. |
| 2026-06-17 | 1  | **Phase 1 complete:** `component.na.jac` (Component + Container stubs); `diff.na.jac` (DiffEngine - full render on width change, differential row repaint otherwise using `ESC[r;1H ESC[2K` absolute addressing); `screen.na.jac` (TuiState → list[str] row renderer replacing render_full); `tui.na.jac` wired to `screen_render` + `DiffEngine`. Note: inner-function docstrings must be `#` comments in NA (triple-quote docstrings only valid at module level). |
| 2026-06-17 | 2  | **Phase 2 complete:** `width.na.jac` (`visible_width`/`ansi_trunc`/`ansi_pad` - byte-safe UTF-8 iteration, ANSI-aware truncation); `theme.na.jac` (canonical palette RGB constants + SGR attr bitmasks); `screen.na.jac` updated: all `len()` layout math replaced with `visible_width()` (fixes "○ idle" byte-vs-column bug), `_trunc` replaced with `ansi_trunc`, user-message rows get full-width tinted background fill (`_USER_MSG` glob), `sep` kind renders as blank border row; `feed.na.jac`: separator rows inserted between events for visual breathing room. Binary: 148 KB, links libc.so.6 + libm.so.6 only. |
| 2026-06-17 | 3  | **Phase 3 complete:** `editor.na.jac` (EditorState + full multiline operations: insert/backspace/forward-delete/newline, left/right/up/down cursor with visual-line awareness, Home/End, Ctrl+K/U/W, word-left/right, history nav up/down); `state.na.jac` adds `EditorState` obj, replaces `input_buf: str` with `editor: EditorState`; `input.na.jac` rewritten to dispatch all keys via editor ops (Ctrl+A/E/K/U/W, arrows, word-move, Alt+Enter newline, Enter submit, history nav); `screen.na.jac` replaces single `_input_row` with variable-height `_editor_rows` (word-wrapped visual lines, inverted-video cursor, scroll offset, dynamic transcript reflow). Binary: 209 KB, links libc.so.6 + libm.so.6 only. |
| 2026-06-17 | 4  | **Phase 4 complete:** `markdown.na.jac` (`md_render` - block parser: headings h1/h2/h3, fenced code blocks, unordered/ordered lists, blockquotes, horizontal rules, paragraphs; inline spans: **bold**, *italic*, `code`, ~~strikethrough~~; ANSI-aware word-wrap via `visible_width`); `state.na.jac` adds `pre_styled: bool` to `DisplayRow`; `feed.na.jac` routes `answer`/`reasoning` events through `md_render` (pre-styled rows, no _kind_sgr override); `screen.na.jac` handles `pre_styled` rows with a direct ANSI embed path. NA syntax quirks: `skip` is a Jac keyword, `else if` unsupported (use `else { if ... }`). Binary: 267 KB, links libc.so.6 + libm.so.6 only. |
| 2026-06-17 | 5  | **Phase 5 complete:** `tool_block.na.jac` (`tool_call_rows` / `tool_result_rows` - pi tool-execution.ts visual patterns: `⚙ bold-purple tool_name  dim-gray args-inline` for calls; `✓ bold-green first-line` / `✗ bold-red (empty)` with dim-gray continuation for results); `feed.na.jac` routes `call`/`tool_result` events through ToolBlock (pre-styled rows, replaces plain `#` / `  | ` prefix-wrap). NA gotcha: `node` is a keyword - use `tool_name` as parameter name. Binary: 279 KB, links libc.so.6 + libm.so.6 only. |
| 2026-06-17 | 6  | **Phase 6 complete:** `overlay.na.jac` (center-anchored modal compositing) + `select_list.na.jac` (filtered picker: substring match, wrap nav, `handle_key` returns none/changed/select/cancel) + `commands.na.jac` (palette/model/file item builders + dispatch). **Model picker** (`/model`, palette, or model-select on a `/`-filtered entry) lists `MODEL_PRESETS` (mirrors `ai_agent._MODEL_PRESETS`, marks current) and emits `APPLY:model=<name>` (frozen protocol, no wire change). **File picker** (`/files`) inserts `@path` into the editor via `editor_insert_text`; the project file list is computed control-plane side (`run_tui_session.impl.jac` `_list_project_files`: `git ls-files`, else a bounded walk) and handed to the sidecar as the newline-separated `JAC_AI_UI_FILES` env var, read with `os.getenv`. This keeps all filesystem access out of the native binary, sidestepping the NA `str = calloc(...)` refcount double-free that crashes any in-binary file read (and the jac-format `combine-glob` rule that hoists such a read into the fatal split form). `screen.na.jac` composites the modal over the base when `overlay_active`. **Tests:** `test_pickers.na.jac` (24 headless logic checks, no TTY) wired into `build.sh`. Binary: 354 KB, links libc.so.6 + libm.so.6 only. |
