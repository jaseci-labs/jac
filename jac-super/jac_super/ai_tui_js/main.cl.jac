"""Entry point for the JS OpenTUI renderer sidecar (`jac ai --tui`, backend `js`).

Owns all real I/O around the I/O-free logic in state/protocol/input:
  - process.stdin   <- control-plane frames (KEY:VALUE ... `---`)
  - process.stdout  -> commands (SEND:/STOP/RESET/QUIT/APPLY:)
  - /dev/tty        -> OpenTUI render surface + keyboard, kept off the pipes by
                       passing explicit tty streams to createCliRenderer (so the
                       process stdin/stdout stay the protocol pipes).

`node:tty` ReadStream/WriteStream require `new`, which the Jac->JS backend does
not emit for imported symbols; Reflect.construct bridges that.

Phase 3 scope: boot + clean teardown + the full IPC seam (frames in, commands
out, seed prompt, quit) + the parity transcript/header/status/prompt UI, painted
imperatively from TuiState via `render.render_full` (registered as an OpenTUI
post-process callback so it lands after the empty renderable tree, as the final
word before the native flush). Render is on-demand: every state change calls
`renderer.requestRender()` to schedule one frame.
"""

import from '@opentui/core' { createCliRenderer }
import from 'node:tty' { ReadStream, WriteStream }
import from 'node:fs' { openSync }
import from 'node:readline' { createInterface }
import from .state { TuiState }
import from .protocol { Protocol }
import from .input { Input }
import from .render { render_full }

# Accumulates control-plane frame lines until the `---` terminator, then applies
# the whole frame. Kept as a same-module object so the closure handler can mutate
# it without reassigning a captured binding.
obj FrameBuf {
    has lines: list[str] = [];

    def feed(line: str, state: TuiState, proto: Protocol) -> None {
        s = line.strip();
        if s == "---" {
            proto.apply_frame(state, self.lines);
            self.lines = [];
            state.dirty = True;
            return;
        }
        if len(s) > 0 {
            self.lines.append(s);
        }
    }
}

def emit_cmd(cmd: str) {
    process.stdout.write(cmd + "\n");
}

def do_quit(renderer: any) {
    try {
        renderer.destroy();
    } except Exception { }
    process.exit(0);
}

def on_key(k: any, state: TuiState, inp: Input, renderer: any) {
    # OpenTUI hands us a KeyEvent; `.raw` is the raw terminal byte sequence,
    # which is exactly what handle_key (ported from the NA raw-key dispatcher)
    # expects.
    res = inp.handle_key(state, k.raw);
    for cmd in res.commands {
        emit_cmd(cmd);
    }
    state.dirty = True;
    renderer.requestRender();
    if res.quit {
        do_quit(renderer);
    }
}

def on_line(line: str, state: TuiState, proto: Protocol, fb: FrameBuf, renderer: any) {
    fb.feed(line, state, proto);
    renderer.requestRender();
}

# SIGWINCH is only auto-handled by OpenTUI when its stdout is process.stdout; ours
# is /dev/tty, so we drive resize ourselves: re-read the tty geometry and hand it
# to the renderer (which reconfigures buffers, emits "resize", and repaints).
def on_sigwinch(renderer: any, tty_out: any) {
    cols = tty_out.columns;
    rows = tty_out.rows;
    if cols and rows {
        renderer.resize(cols, rows);
    }
}

# The renderer emits "resize" with the new (width, height); mirror it into state
# so the next paint lays out at the new geometry. A width change is picked up by
# render_full's layout cache (layout_cols != cols) and triggers a row rebuild.
def on_resize(state: TuiState, w: int, h: int) {
    state.term_cols = w;
    state.term_rows = h;
    state.dirty = True;
}

async def:pub main {
    state = TuiState();
    proto = Protocol();
    inp = Input();
    fb = FrameBuf();

    proj = process.env.JAC_AI_UI_PROJECT;
    if proj and len(proj) > 0 {
        state.cwd = proj;
    } else {
        state.cwd = process.cwd();
    }
    model = process.env.JAC_AI_UI_MODEL;
    if model {
        state.model_name = model;
    }

    # Render surface + keyboard on /dev/tty; the pipes stay free for the protocol.
    tty_in = Reflect.construct(ReadStream, [openSync("/dev/tty", "r")]);
    tty_out = Reflect.construct(WriteStream, [openSync("/dev/tty", "w")]);

    renderer = await createCliRenderer(
        {"stdin": tty_in, "stdout": tty_out, "exitOnCtrlC": False, "useMouse": False}
    );

    # Initial geometry from the tty; SIGWINCH keeps it current thereafter.
    state.term_cols = renderer.width;
    state.term_rows = renderer.height;

    # Full-screen paint from TuiState. Registered as a post-process callback so it
    # runs after the (childless) renderable tree renders into the buffer — making
    # our paint the final content before the native flush. The buffer is passed
    # in (it is reallocated on resize, so we must not capture a stale reference).
    renderer.addPostProcessFn(lambda buf: any , dt: any : render_full(state, buf));
    renderer.on("resize", lambda w: any , h: any : on_resize(state, w, h));
    process.on("SIGWINCH", lambda : on_sigwinch(renderer, tty_out));

    renderer.keyInput.on("keypress", lambda k: any : on_key(k, state, inp, renderer));

    rl = createInterface({"input": process.stdin});
    rl.on("line", lambda line: any : on_line(line, state, proto, fb, renderer));
    rl.on("close", lambda : do_quit(renderer));

    # Initial paint (header/status/empty transcript/prompt) before any frames.
    renderer.requestRender();

    # Seed prompt: control plane passes it as the first positional arg (argv[2]
    # under node/bun: [runtime, script, seed]).
    if len(process.argv) > 2 {
        seed = process.argv[2].strip();
        if len(seed) > 0 {
            emit_cmd(f"SEND:{seed}");
        }
    }
}

with entry {
    main();
}
