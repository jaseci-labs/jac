"""OpenTUI handle manager — Jac Native implementation.

Replaces opentui_helpers.c.  All OpenTUI handles are void* on x64; we store
them as i64.  The only C surface remaining is opentui_shim.c, which handles
the two things Jac NA's scalar-only FFI cannot express:
  - ioctl(TIOCGWINSZ)  → struct winsize*  (non-scalar output param)
  - bufferDrawText / bufferFillRect → uint16_t[4] RGBA arrays

Type rule: Jac NA integer literals are i64 (= Jac `int`).
  - Use `int` for all Jac-side variables and object fields.
  - Use `i32` only in C FFI declarations that truly map to C `int` params.
  - Use `i64` in FFI declarations for void* handles.
  - Never mix `i32` variables with integer literals in binary ops.

fd layout after otui_init():
  0  IPC in pipe   (stdin — unchanged)
  1  terminal      (OpenTUI writes ANSI here; was stderr before remap)
  2  terminal      (stderr — unchanged; used for TIOCGWINSZ)
  3  IPC out pipe  (was stdout; Jac writes SEND:/STOP/QUIT here)
"""

# ── Direct imports from libopentui.so ────────────────────────────────────
# Handles are void* on x64 — i64 so the full 64-bit pointer is preserved.
import from .opentui {
    def createRenderer(w: i32, h: i32, testing: i32, remote: i32) -> i64;  def destroyRenderer(
        renderer: i64
    ) -> None;  def render(renderer: i64, force: i32) -> None;  def getNextBuffer(
        renderer: i64
    ) -> i64;  def resizeRenderer(renderer: i64, w: i32, h: i32) -> None;  def setupTerminal(
        renderer: i64, useAlt: i32
    ) -> None;  def restoreTerminalModes(renderer: i64) -> None;  def clearTerminal(
        renderer: i64
    ) -> None;
}

# ── C shim: ioctl struct, uint16_t[4] RGBA, and dup2 ─────────────────────
import from .opentui_shim {
    def shim_query_size(fd: i32) -> None;  def shim_get_rows -> i32;  def shim_get_cols -> i32;  def shim_dup2(
        oldfd: i32, newfd: i32
    ) -> i32;  def shim_fill_rect(
        buf: i64, x: i32, y: i32, w: i32, h: i32, bg_r: i32, bg_g: i32, bg_b: i32
    ) -> None;  def shim_draw_text(
        buf: i64,
        text: str,
        x: i32,
        y: i32,
        fg_r: i32,
        fg_g: i32,
        fg_b: i32,
        bg_r: i32,
        bg_g: i32,
        bg_b: i32,
        use_bg: i32,
        attrs: i32
    ) -> None;
}

import from .tui_helpers { def tui_write(fd: i32, s: str) -> None;  }

# ── Module state ──────────────────────────────────────────────────────────
# All fields typed as `int` (= i64) so they're compatible with integer literals
# in binary ops.  renderer/buf are i64 explicitly (they store void* values).
obj OtuiCtx {
    has renderer: i64 = 0,
        buf: i64 = 0,
        rows: int = 24,
        cols: int = 80,
        fd_saved: int = 0;
}

glob g_ctx: OtuiCtx = OtuiCtx();

# ── Public API ────────────────────────────────────────────────────────────
def otui_init -> i32 {
    null64: i64 = 0;

    # dup2(1, 3): save IPC out pipe (stdout) to fd 3
    rc0: int = shim_dup2(1, 3);
    if rc0 < 0 {
        tui_write(2, "otui: dup2(1,3) failed\n");
        return -1;
    }
    # dup2(2, 1): route stderr (= terminal) into fd 1 for OpenTUI
    rc1: int = shim_dup2(2, 1);
    if rc1 < 0 {
        shim_dup2(3, 1);
        tui_write(2, "otui: dup2(2,1) failed\n");
        return -1;
    }
    g_ctx.fd_saved = 1;

    # Measure terminal size via fd 2 (stderr = terminal, unchanged)
    shim_query_size(2);
    g_ctx.rows = shim_get_rows();
    g_ctx.cols = shim_get_cols();

    # Create renderer (testing=0, remote=0 → local terminal on fd 1)
    h: i64 = createRenderer(g_ctx.cols, g_ctx.rows, 0, 0);
    if h == null64 {
        tui_write(2, "otui: createRenderer returned NULL\n");
        return -1;
    }
    g_ctx.renderer = h;

    # Enter alternate screen and hide cursor
    setupTerminal(g_ctx.renderer, 1);

    return 0;
}

def otui_close {
    null64: i64 = 0;
    if g_ctx.renderer != null64 {
        restoreTerminalModes(g_ctx.renderer);
        destroyRenderer(g_ctx.renderer);
        g_ctx.renderer = null64;
        g_ctx.buf = null64;
    }
    if g_ctx.fd_saved != 0 {
        shim_dup2(3, 1);
        g_ctx.fd_saved = 0;
    }
}

def otui_ipc_fd -> i32 {
    return 3;
}

def otui_update_size {
    old_r: int = g_ctx.rows;
    old_c: int = g_ctx.cols;
    shim_query_size(2);
    nr: int = shim_get_rows();
    nc: int = shim_get_cols();
    g_ctx.rows = nr;
    g_ctx.cols = nc;
    null64: i64 = 0;
    if g_ctx.renderer != null64 {
        if nr != old_r or nc != old_c {
            resizeRenderer(g_ctx.renderer, nc, nr);
        }
    }
}

def otui_rows -> i32 {
    return g_ctx.rows;
}

def otui_cols -> i32 {
    return g_ctx.cols;
}

def otui_begin -> None {
    null64: i64 = 0;
    if g_ctx.renderer == null64 {
        return;
    }
    g_ctx.buf = getNextBuffer(g_ctx.renderer);
}

def otui_draw_text(
    x: i32,
    y: i32,
    text: str,
    fg_r: i32,
    fg_g: i32,
    fg_b: i32,
    bg_r: i32,
    bg_g: i32,
    bg_b: i32,
    attrs: i32
) -> None {
    null64: i64 = 0;
    if g_ctx.buf == null64 {
        return;
    }
    use_bg: i32 = 1;
    if bg_r < 0 {
        use_bg = 0;
    }
    shim_draw_text(
        g_ctx.buf, text, x, y, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b, use_bg, attrs
    );
}

def otui_fill_rect(
    x: i32, y: i32, w: i32, h: i32, bg_r: i32, bg_g: i32, bg_b: i32
) -> None {
    null64: i64 = 0;
    if g_ctx.buf == null64 {
        return;
    }
    shim_fill_rect(g_ctx.buf, x, y, w, h, bg_r, bg_g, bg_b);
}

def otui_flush -> None {
    null64: i64 = 0;
    if g_ctx.renderer == null64 {
        return;
    }
    render(g_ctx.renderer, 0);
}
