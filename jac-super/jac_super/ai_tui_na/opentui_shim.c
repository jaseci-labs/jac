/*
 * opentui_shim.c — minimal C bridge for the two things Jac NA can't do:
 *
 *   1. ioctl(TIOCGWINSZ)  — requires struct winsize*
 *   2. bufferDrawText / bufferFillRect — require uint16_t[4] RGBA arrays
 *
 * Everything else lives in opentui_helpers.na.jac.
 *
 * Compiled with -lopentui so the extern symbols resolve at load time.
 */
#define _GNU_SOURCE
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>

/* ── ioctl wrapper ───────────────────────────────────────────────────────── */

static int g_rows = 24, g_cols = 80;

void shim_query_size(int fd) {
    struct winsize ws;
    if (ioctl(fd, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 && ws.ws_col > 0) {
        g_rows = (int)ws.ws_row;
        g_cols = (int)ws.ws_col;
    }
}

int shim_get_rows(void) { return g_rows; }
int shim_get_cols(void) { return g_cols; }

/* dup2 is scalar-only and could theoretically be imported from libc, but
 * library naming (libc.so.6 vs liblibc.so) makes that unreliable in nacompile.
 * One extra line here avoids the ambiguity. */
int shim_dup2(int oldfd, int newfd) { return dup2(oldfd, newfd); }

/* ── RGBA array wrappers ─────────────────────────────────────────────────── */
/* These extern symbols resolve from libopentui.so (linked below). */

extern void bufferDrawText(void *buf, const char *text, uint32_t len,
                            uint32_t x, uint32_t y,
                            const uint16_t *fg, const uint16_t *bg,
                            uint32_t attrs);
extern void bufferFillRect(void *buf, uint32_t x, uint32_t y,
                            uint32_t w, uint32_t h,
                            const uint16_t *bg);

/* ── ptr probe helpers (used by test_ptr_ops.na.jac) ────────────────────── */
#include <stdlib.h>

/* Allocate n uint16_t values on the heap; returns ptr (void*). */
void *shim_alloc16(int n) { return calloc((size_t)n, sizeof(uint16_t)); }
void  shim_free(void *p)  { free(p); }

/* Write a single uint16_t value at index idx. */
void shim_write16(void *p, int idx, int val) {
    ((uint16_t *)p)[idx] = (uint16_t)val;
}

/* bufferFillRect taking a raw ptr for bg — lets Jac NA pass the ptr directly. */
void shim_fill_rect_ptr(long long buf, int x, int y, int w, int h, void *bg) {
    if (!buf || w <= 0 || h <= 0) return;
    bufferFillRect((void *)buf,
                   (uint32_t)x, (uint32_t)y,
                   (uint32_t)w, (uint32_t)h,
                   (const uint16_t *)bg);
}

void shim_fill_rect(long long buf, int x, int y, int w, int h,
                    int bg_r, int bg_g, int bg_b) {
    if (!buf || w <= 0 || h <= 0) return;
    uint16_t bg[4] = {(uint16_t)bg_r, (uint16_t)bg_g, (uint16_t)bg_b, 255};
    bufferFillRect((void *)buf,
                   (uint32_t)x, (uint32_t)y,
                   (uint32_t)w, (uint32_t)h, bg);
}

void shim_draw_text(long long buf, const char *text,
                    int x, int y,
                    int fg_r, int fg_g, int fg_b,
                    int bg_r, int bg_g, int bg_b,
                    int use_bg, int attrs) {
    if (!buf || !text) return;
    uint32_t tlen = (uint32_t)strlen(text);
    if (!tlen) return;
    uint16_t fg[4] = {(uint16_t)fg_r, (uint16_t)fg_g, (uint16_t)fg_b, 255};
    if (use_bg) {
        uint16_t bg[4] = {(uint16_t)bg_r, (uint16_t)bg_g, (uint16_t)bg_b, 255};
        bufferDrawText((void *)buf, text, tlen,
                       (uint32_t)x, (uint32_t)y,
                       fg, bg, (uint32_t)attrs);
    } else {
        bufferDrawText((void *)buf, text, tlen,
                       (uint32_t)x, (uint32_t)y,
                       fg, NULL, (uint32_t)attrs);
    }
}
