/*
 * opentui_helpers.c — thin C wrapper over libopentui.so for Jac Native FFI.
 *
 * Exposes scalar-only functions so the NA side never sees C structs or
 * pointer-wide handles.  OpenTUI handles are opaque void* on x64; this file
 * stores them as C globals so the NA side only passes ints.
 *
 * fd remap (done once in otui_init):
 *   dup2(1, 3)  →  fd 3 = IPC out pipe  (saves original stdout)
 *   dup2(2, 1)  →  fd 1 = terminal      (was stderr)
 * After this:
 *   fd 0  IPC in pipe   (stdin — unchanged)
 *   fd 1  terminal      (OpenTUI writes ANSI here)
 *   fd 2  terminal      (stderr — unchanged; queried for TIOCGWINSZ)
 *   fd 3  IPC out pipe  (Jac writes SEND:/STOP/QUIT here)
 *
 * RGBA format (uint16_t[4]):
 *   Each element stores the 8-bit channel in the LOW byte; HIGH byte = 0
 *   for RGB intent (meta = 0).  So { r, g, b, 255 } is fully-opaque RGB.
 *   Passing bg_r < 0 to otui_draw_text signals a transparent background
 *   (NULL bg pointer → terminal-default bg).
 *
 * Build:
 *   gcc -O2 -shared -fPIC -DOPENTUI_SO_PATH=\"/path/to/libopentui.so\" \
 *       -o libopentui_helpers.so opentui_helpers.c -ldl
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>

/*
 * All OpenTUI handles are opaque void* (64-bit pointer on x64).
 * Never store them in uint32_t — the high 32 bits would be silently lost.
 */
#define INVALID_HANDLE NULL

/* ── function pointer types matching the actual C ABI (from Bun FFI defs) ── */

/* createRenderer(width:u32, height:u32, testing:bool, remote:bool) -> ptr */
typedef void * (*fn_createRenderer_t)(uint32_t w, uint32_t h,
                                      uint8_t testing, uint8_t remote);
/* destroyRenderer(renderer:ptr) -> void */
typedef void   (*fn_destroyRenderer_t)(void *renderer);
/* render(renderer:ptr, force:bool) -> void */
typedef void   (*fn_render_t)(void *renderer, uint8_t force);
/* getNextBuffer(renderer:ptr) -> ptr */
typedef void * (*fn_getNextBuffer_t)(void *renderer);
/* resizeRenderer(renderer:ptr, w:u32, h:u32) -> void */
typedef void   (*fn_resizeRenderer_t)(void *renderer, uint32_t w, uint32_t h);
/* clearTerminal(renderer:ptr) -> void */
typedef void   (*fn_clearTerminal_t)(void *renderer);
/* setupTerminal(renderer:ptr, useAlternateScreen:bool) -> void */
typedef void   (*fn_setupTerminal_t)(void *renderer, uint8_t useAlternateScreen);
/* restoreTerminalModes(renderer:ptr) -> void */
typedef void   (*fn_restoreTerminalModes_t)(void *renderer);
/* bufferDrawText(buf:ptr, text:ptr, len:u32, x:u32, y:u32, fg:ptr, bg:ptr, attrs:u32) -> void */
typedef void   (*fn_bufferDrawText_t)(void *buf,
                                      const char *text, uint32_t len,
                                      uint32_t x, uint32_t y,
                                      const uint16_t *fg, const uint16_t *bg,
                                      uint32_t attrs);
/* bufferFillRect(buf:ptr, x:u32, y:u32, w:u32, h:u32, bg:ptr) -> void */
typedef void   (*fn_bufferFillRect_t)(void *buf,
                                      uint32_t x, uint32_t y,
                                      uint32_t w, uint32_t h,
                                      const uint16_t *bg);

/* ── module globals ─────────────────────────────────────────────────────── */

static void   *g_dl       = NULL;
static void   *g_renderer = INVALID_HANDLE;
static void   *g_buf      = INVALID_HANDLE;
static int     g_rows     = 24;
static int     g_cols     = 80;
static int     g_fd_saved = 0;  /* non-zero once fd remap has been done */

static fn_createRenderer_t       fn_createRenderer;
static fn_destroyRenderer_t      fn_destroyRenderer;
static fn_render_t               fn_render;
static fn_getNextBuffer_t        fn_getNextBuffer;
static fn_resizeRenderer_t       fn_resizeRenderer;
static fn_clearTerminal_t        fn_clearTerminal;
static fn_setupTerminal_t        fn_setupTerminal;
static fn_restoreTerminalModes_t fn_restoreTerminalModes;
static fn_bufferDrawText_t       fn_bufferDrawText;
static fn_bufferFillRect_t       fn_bufferFillRect;

/* ── private helpers ────────────────────────────────────────────────────── */

static void err(const char *msg) {
    write(2, msg, strlen(msg));
}

static int load_sym(const char *name, void **out) {
    *out = dlsym(g_dl, name);
    if (*out == NULL) {
        char buf[128];
        snprintf(buf, sizeof(buf), "otui: missing symbol: %s\n", name);
        err(buf);
        return -1;
    }
    return 0;
}

static void query_size(void) {
    struct winsize ws;
    /* fd 2 = stderr = terminal; unchanged by our remap */
    if (ioctl(2, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 && ws.ws_col > 0) {
        g_rows = (int)ws.ws_row;
        g_cols = (int)ws.ws_col;
    }
}

/* ── public API ─────────────────────────────────────────────────────────── */

/*
 * otui_init — remap fds, load libopentui.so, create renderer, enter alt screen.
 * Returns 0 on success, -1 on any failure.
 * Call tui_open() (tui_helpers.c) BEFORE this to set raw mode on /dev/tty.
 */
int otui_init(void) {
    /* Step 1: remap fds so OpenTUI writes to terminal, IPC pipe on fd 3 */
    if (dup2(1, 3) < 0) { err("otui: dup2(1,3) failed\n"); return -1; }
    if (dup2(2, 1) < 0) { dup2(3, 1); err("otui: dup2(2,1) failed\n"); return -1; }
    g_fd_saved = 1;

    /* Step 2: measure terminal size via fd 2 (stderr = terminal) */
    query_size();

    /* Step 3: locate and load libopentui.so */
    g_dl = NULL;

    /* Try path next to this binary first ($ORIGIN layout) */
    char exe[4096];
    ssize_t elen = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    if (elen > 0) {
        exe[elen] = '\0';
        char *slash = strrchr(exe, '/');
        if (slash) {
            *slash = '\0';
            char so_path[5120];
            snprintf(so_path, sizeof(so_path), "%s/libopentui.so", exe);
            g_dl = dlopen(so_path, RTLD_LAZY | RTLD_GLOBAL);
        }
    }
#ifdef OPENTUI_SO_PATH
    if (!g_dl) {
        g_dl = dlopen(OPENTUI_SO_PATH, RTLD_LAZY | RTLD_GLOBAL);
    }
#endif
    if (!g_dl) {
        g_dl = dlopen("libopentui.so", RTLD_LAZY | RTLD_GLOBAL);
    }
    if (!g_dl) {
        err("otui: dlopen(libopentui.so) failed\n");
        return -1;
    }

    /* Step 4: resolve all required symbols */
    if (load_sym("createRenderer",       (void **)&fn_createRenderer)       < 0) return -1;
    if (load_sym("destroyRenderer",      (void **)&fn_destroyRenderer)      < 0) return -1;
    if (load_sym("render",               (void **)&fn_render)               < 0) return -1;
    if (load_sym("getNextBuffer",        (void **)&fn_getNextBuffer)        < 0) return -1;
    if (load_sym("resizeRenderer",       (void **)&fn_resizeRenderer)       < 0) return -1;
    if (load_sym("clearTerminal",        (void **)&fn_clearTerminal)        < 0) return -1;
    if (load_sym("setupTerminal",        (void **)&fn_setupTerminal)        < 0) return -1;
    if (load_sym("restoreTerminalModes", (void **)&fn_restoreTerminalModes) < 0) return -1;
    if (load_sym("bufferDrawText",       (void **)&fn_bufferDrawText)       < 0) return -1;
    if (load_sym("bufferFillRect",       (void **)&fn_bufferFillRect)       < 0) return -1;

    /* Step 5: create renderer (testing=false, remote=false → local stdout mode) */
    g_renderer = fn_createRenderer((uint32_t)g_cols, (uint32_t)g_rows,
                                   0 /* testing=false */,
                                   0 /* remote=false, local terminal */);
    if (g_renderer == INVALID_HANDLE) {
        err("otui: createRenderer returned NULL\n");
        return -1;
    }

    /* Step 6: enter alternate screen and hide cursor */
    fn_setupTerminal(g_renderer, 1 /* useAlternateScreen=true */);

    return 0;
}

/* otui_close — restore terminal, destroy renderer, restore fd 1 = IPC pipe */
void otui_close(void) {
    if (g_renderer != INVALID_HANDLE) {
        fn_restoreTerminalModes(g_renderer);
        fn_destroyRenderer(g_renderer);
        g_renderer = INVALID_HANDLE;
        g_buf      = INVALID_HANDLE;
    }
    if (g_dl) {
        dlclose(g_dl);
        g_dl = NULL;
    }
    if (g_fd_saved) {
        dup2(3, 1);  /* restore fd 1 = IPC out pipe */
        g_fd_saved = 0;
    }
}

/* otui_ipc_fd — fd to use for writing IPC commands (always 3 after init) */
int otui_ipc_fd(void) { return 3; }

/* otui_update_size — re-query terminal size; resize renderer if changed */
void otui_update_size(void) {
    int old_rows = g_rows, old_cols = g_cols;
    query_size();
    if (g_renderer != INVALID_HANDLE &&
        (g_rows != old_rows || g_cols != old_cols)) {
        fn_resizeRenderer(g_renderer, (uint32_t)g_cols, (uint32_t)g_rows);
    }
}

int otui_rows(void) { return g_rows; }
int otui_cols(void) { return g_cols; }

/* otui_begin — get the next frame buffer; call before any draw operations */
void otui_begin(void) {
    if (g_renderer == INVALID_HANDLE) return;
    g_buf = fn_getNextBuffer(g_renderer);
}

/*
 * otui_draw_text — draw UTF-8 text at cell (x, y) with given colors.
 * Coordinates are 0-indexed (column, row).
 * Pass bg_r < 0 for a transparent (terminal-default) background.
 * attrs: 0=none, 1=bold, 2=dim, 4=italic, 8=underline (combinable).
 */
void otui_draw_text(int x, int y, const char *text,
                    int fg_r, int fg_g, int fg_b,
                    int bg_r, int bg_g, int bg_b,
                    int attrs) {
    if (g_buf == INVALID_HANDLE || !text) return;
    uint32_t tlen = (uint32_t)strlen(text);
    if (tlen == 0) return;
    uint16_t fg[4] = { (uint16_t)fg_r, (uint16_t)fg_g, (uint16_t)fg_b, 255 };
    if (bg_r < 0) {
        fn_bufferDrawText(g_buf, text, tlen,
                          (uint32_t)x, (uint32_t)y,
                          fg, NULL, (uint32_t)attrs);
    } else {
        uint16_t bg[4] = { (uint16_t)bg_r, (uint16_t)bg_g, (uint16_t)bg_b, 255 };
        fn_bufferDrawText(g_buf, text, tlen,
                          (uint32_t)x, (uint32_t)y,
                          fg, bg, (uint32_t)attrs);
    }
}

/* otui_fill_rect — fill a rectangle with a solid background color */
void otui_fill_rect(int x, int y, int w, int h,
                    int bg_r, int bg_g, int bg_b) {
    if (g_buf == INVALID_HANDLE || w <= 0 || h <= 0) return;
    uint16_t bg[4] = { (uint16_t)bg_r, (uint16_t)bg_g, (uint16_t)bg_b, 255 };
    fn_bufferFillRect(g_buf,
                      (uint32_t)x, (uint32_t)y,
                      (uint32_t)w, (uint32_t)h,
                      bg);
}

/* otui_flush — commit the current buffer to the terminal via frame diffing */
void otui_flush(void) {
    if (g_renderer == INVALID_HANDLE) return;
    fn_render(g_renderer, 0 /* force=false */);
}
