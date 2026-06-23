"""In-process TUI host: the C-ABI :pub surface the sv agent dlopens (plan §5).

Built as a shared library:  jac nacompile host.na.jac --shared -o bin/libtui.so
Loaded from the sv side via ctypes.CDLL; see jac_super/ai_agent/tui_host (Phase 2).

The TUI owns its own TuiState + DiffEngine as module globs -- they never cross
the ABI as Jac objects, so no jac_retain/jac_release dance is needed (plan §4).
Only scalars and the frame/command `str` (c_char_p) cross. na -> sv is a PULL
QUEUE, not callbacks: tui_handle_key enqueues commands into ipc.na.jac's
cmd_queue and the host drains them via tui_next_command (plan §4/§5/§8).

Threading contract the host MUST honor (plan §9): tui_wait_key is the ONLY
lock-free export (pure poll, GIL released); tui_apply_frame / tui_handle_key /
tui_render all read or mutate TuiState and MUST run under the host's render lock.
"""

# Import order matters: the native cross-module type resolver is DFS-order
# sensitive and resolves leaf types (e.g. select_list.SelectItem, reached via
# input -> overlay) to <Unknown> if first seen too deep -- E5090/E2018. This flat
# block mirrors the proven-good order primed by tui.na.jac; the libc_tty /
# terminal / screen symbols beyond what the exports use are otherwise unused but
# REQUIRED to keep the --shared build green. Do not prune them.
# Upstream fix tracked in jaseci-labs/jaseci#6793.
import from .libc_tty {
    tty_open,
    tty_open_dev,
    tty_close,
    tty_fd,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_x_pixels,
    tty_y_pixels,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_write,
    tty_init_stdio_remap,
    tty_restore_stdio,
    tty_ipc_fd
}
import from .terminal {
    term_enter_alt_screen,
    term_leave_alt_screen,
    term_hide_cursor,
    term_show_cursor,
    term_enable_mouse,
    term_disable_mouse
}
import from .state { TuiState }
# See tui.na.jac priming comment: phase-7 state.na.jac changes require explicit
# select_list priming so SelectItem resolves in overlay.na.jac during DFS.
import from .select_list { SelectList, SelectItem }
import from .ipc { ipc_read_frame_v2, ipc_send_cmd, ipc_parse_frame, ipc_next_command }
import from .screen { screen_render }
import from .diff { DiffEngine, diff_take_buf }
import from .input { handle_key }
import from .terminal_image { term_hyperlink, image_rows }
import from .tui_core {
    tui_populate_state,
    tui_enter_screen,
    tui_leave_screen,
    tui_render_once,
    _sync_size
}

# Pure object construction is safe in glob init (no libc / no tty); the libc/tty
# calls happen only inside the :pub exports below, never during glob init.
glob host_state: TuiState = TuiState(),
     host_diff: DiffEngine = DiffEngine();

# One-time setup. No callback pointers -- na -> sv is a pull queue. Returns 0 on
# success, non-zero on a tty failure. Idempotent: a second call re-inits the
# in-process state. `tty_dev` is /dev/pts/N or "" for the _tty_device_path()
# default (JAC_AI_TUI_TTY / /dev/tty).
def:pub tui_init(project: str, files_env: str, presets_env: str, tty_dev: str) -> int {
    host_state.reset_events();
    host_state.files = [];
    host_state.model_presets = [];
    host_state.quit_flag = False;
    # -1 = enqueue commands into cmd_queue; there is no IPC pipe in-process.
    host_state.ipc_fd = -1;
    # Idempotent re-init (this is documented as safe to call twice): also clear the
    # header/interactive state a prior session -- or a frame applied before init --
    # may have left set. Without this, a stale status == "running" survives and
    # _handle_submit (input.na.jac) silently drops the next SEND; a stale open
    # overlay would also swallow keystrokes.
    host_state.status = "idle";
    host_state.active = "";
    host_state.model_name = "";
    host_state.needs_key = False;
    host_state.key_env = "";
    host_state.editor.clear();
    host_state.overlay_active = False;
    host_state.overlay_kind = "palette";
    host_state.overlay_filter = "";
    host_diff.invalidate();

    fd: int = tty_open_dev(tty_dev);
    if fd < 0 {
        return 1;
    }
    tui_populate_state(host_state, project, files_env, presets_env);
    tui_enter_screen(host_state, fd);
    return 0;
}

# Apply one frame. `blob` is the exact KEY:VALUE\n...\n--- text from PROTOCOL.md
# (the host joins _frame_blob and passes it). Parses into the module TuiState.
# Host holds the render lock. Returns 0 on a clean parse.
def:pub tui_apply_frame(blob: str) -> int {
    ok = ipc_parse_frame(host_state, blob);
    if ok {
        return 0;
    }
    return 1;
}

# Block on poll(2) over the tty for up to `timeout_ms`. PURE I/O: does NOT touch
# TuiState, does NOT dispatch, does NOT render. Safe to call LOCK-FREE (the GIL
# is released for the poll). Returns 1 if a key is ready, 0 on timeout. (The raw
# key is read under the lock in tui_handle_key; see plan §5/§9. The stdin pollfd
# slot is irrelevant in-process -- there is no IPC stdin; a tty-only poll is a
# Phase-2 refinement.)
def:pub tui_wait_key(timeout_ms: int) -> int {
    tty_poll(timeout_ms);
    return tty_key_ready();
}

# Read one keystroke and apply it to TuiState (scroll / overlay / prompt edit),
# possibly enqueuing a command into cmd_queue. MUTATES TuiState -- the host MUST
# hold the render lock. Returns 1 if the key requested quit, else 0.
def:pub tui_handle_key -> int {
    k = tty_read_key();
    if len(k) == 0 {
        return 0;
    }
    quit = handle_key(k, host_state, host_state.ipc_fd);
    if quit {
        host_state.quit_flag = True;
        return 1;
    }
    return 0;
}

# Drain the native command queue, one command per call (FIFO), "" when empty.
# Called in a loop right after tui_handle_key, still under the render lock; each
# line is fed to the host's _dispatch_cmd (same SEND:/STOP/RESET/QUIT/APPLY:
# grammar as the pipe).
def:pub tui_next_command -> str {
    return ipc_next_command();
}

# 1 if the user requested quit (QUIT command / quit key), else 0. Polled by the
# host's ticker so quit needs no callback.
def:pub tui_quit_requested -> int {
    if host_state.quit_flag {
        return 1;
    }
    return 0;
}

# Render if dirty into the tty fd the host owns (NOT fd 1 -- in-process fd 1 is
# the sv stdout; see plan §2). Host holds the lock. Returns 1 if it painted, 0 if
# nothing changed (or the tty is not open).
def:pub tui_render -> int {
    fd: int = tty_fd();
    if fd < 0 {
        return 0;
    }
    # Re-sync the terminal size every tick. The in-process host has no SIGWINCH
    # handler (unlike the subprocess loop, which calls _sync_size each iteration),
    # so this is the one place a resize is detected: _sync_size marks dirty when
    # rows or cols change, and the gated render below repaints accordingly.
    _sync_size(host_state);
    if tui_render_once(host_state, host_diff, fd) {
        return 1;
    }
    return 0;
}

# Headless render: paint a full snapshot of the current TuiState into diff's
# in-memory buffer (fd = -1) and return it. No TTY required -- this is the
# Phase-1 gate path (feed a frame via tui_apply_frame, then assert the rendered
# bytes). tui_render() is the real on-tty path used in Phase 2.
def:pub tui_render_buf -> str {
    host_diff.invalidate();
    host_state.dirty = True;
    tui_render_once(host_state, host_diff, -1);
    return diff_take_buf();
}

# Tear down: leave the alt screen, restore termios, close the tty. Safe to call
# once. Returns 0.
def:pub tui_shutdown -> int {
    fd: int = tty_fd();
    if fd >= 0 {
        tui_leave_screen(host_state, fd);
    }
    tty_close();
    return 0;
}
