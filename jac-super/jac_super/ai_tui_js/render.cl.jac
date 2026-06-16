"""Imperative @opentui/core renderer for the JS sidecar: paints the full screen
from TuiState into the renderer's frame buffer each repaint.

Ported 1:1 from `ai_tui_na/render.na.jac`. The NA backend drew through a custom
OpenTUI FFI (`otui_draw_text`/`otui_fill_rect`); here the same cells are written
through `OptimizedBuffer.drawText`/`.fillRect` on the buffer @opentui/core hands
to a post-process callback (so the paint lands after the empty renderable tree
renders, and is the final word before the native flush). See PLAN.md Phase 3.

Layout (0-indexed rows), identical to NA:
  0        ┌─ jac.ai ─ cwd ─────────────────── model ─┐
  1        │ status  phase  [key hints right-aligned]   │
  2        ├─────────────────────────────────────────────┤
  3..R-3   │ transcript events                           │
  R-2      ├─────────────────────────────────────────────┤
  R-1      │ › input text                                │

Color/attr constants and per-kind palette match render.na.jac exactly. OpenTUI's
TextAttributes (BOLD=1, DIM=2, ITALIC=4) coincide with the NA ATTR_* bitmask, so
the integer attrs carry over unchanged.
"""

import from '@opentui/core' { RGBA }
import from .state { TuiState }

# Attribute bits (match @opentui/core TextAttributes and the NA ATTR_* constants).
glob ATTR_BOLD: int = 1,
     ATTR_DIM: int = 2,
     ATTR_ITAL: int = 4;

# Convenience: an RGBA from 0-255 int channels (mirrors otui_draw_text's r,g,b).
def rgb(r: int, g: int, b: int) -> any {
    return RGBA.fromInts(r, g, b);
}

def _trunc(s: str, width: int) -> str {
    if len(s) <= width {
        return s;
    }
    if width < 2 {
        return s[:width];
    }
    return s[:width - 1] + "~";
}

def _hline(left: str, fill: str, right: str, width: int) -> str {
    if width <= 0 {
        return "";
    }
    if width == 1 {
        return left;
    }
    s: str = left;
    i: int = 1;
    while i < width - 1 {
        s = s + fill;
        i = i + 1;
    }
    s = s + right;
    return s;
}

# Shorten a cwd to "~/<last-two-segments>", or the original if it has <2 slashes.
def _cwd_short(cwd: str) -> str {
    slen = len(cwd);
    last: int = -1;
    i: int = slen - 1;
    while i >= 0 and last < 0 {
        if cwd[i] == "/" {
            last = i;
        }
        i = i - 1;
    }
    if last <= 0 {
        return cwd;
    }
    prev: int = -1;
    j: int = last - 1;
    while j >= 0 and prev < 0 {
        if cwd[j] == "/" {
            prev = j;
        }
        j = j - 1;
    }
    if prev < 0 {
        return cwd;
    }
    return "~" + cwd[prev:];
}

def:pub render_full(state: TuiState, buf: any) -> None {
    cols = state.term_cols;
    rows = state.term_rows;
    if cols < 10 or rows < 5 {
        return;
    }

    bg = rgb(18, 18, 28);
    br = rgb(70, 70, 100);

    buf.fillRect(0, 0, cols, rows, bg);

    # inner content width: col 0 = border, col 1 = space, cols-2 = space, cols-1 = border
    inner_w = cols - 4;
    if inner_w < 4 {
        inner_w = 4;
    }

    # ── Row 0: Top border with title ──────────────────────────────────────
    top_line = _hline("┌", "─", "┐", cols);
    buf.drawText(top_line, 0, 0, br, bg, 0);
    buf.drawText(" jac.ai ", 2, 0, rgb(204, 0, 204), bg, ATTR_BOLD);

    cwd_d = _cwd_short(state.cwd);
    model = state.model_name;
    if len(model) == 0 {
        model = "no model";
    }
    cwd_start: int = 12;
    model_start = cols - len(model) - 2;
    if model_start < 0 {
        model_start = 0;
    }
    cwd_avail = model_start - cwd_start - 2;
    if cwd_avail > 2 {
        buf.drawText(_trunc(cwd_d, cwd_avail), cwd_start, 0, rgb(86, 182, 194), bg, 0);
    }
    if model_start > cwd_start {
        buf.drawText(model, model_start, 0, rgb(120, 120, 120), bg, ATTR_DIM);
    }

    # ── Row 1: Status bar ─────────────────────────────────────────────────
    buf.drawText("│", 0, 1, br, bg, 0);
    buf.drawText("│", cols - 1, 1, br, bg, 0);

    st_text: str = "○ idle";
    st_r: int = 140;
    st_g: int = 140;
    st_b: int = 140;
    st_a: int = ATTR_DIM;
    if state.status == "running" {
        st_text = "● running";
        st_r = 255;
        st_g = 200;
        st_b = 50;
        st_a = 0;
    }
    if state.status == "done" {
        st_text = "✓ done";
        st_r = 80;
        st_g = 200;
        st_b = 80;
        st_a = 0;
    }
    if state.status == "stopping" {
        st_text = "○ stopping";
        st_r = 255;
        st_g = 80;
        st_b = 80;
        st_a = 0;
    }
    buf.drawText(st_text, 2, 1, rgb(st_r, st_g, st_b), bg, st_a);
    if len(state.active) > 0 {
        act_x = len(st_text) + 4;
        buf.drawText(
            _trunc(state.active, inner_w - act_x), act_x, 1, rgb(255, 210, 60), bg, 0
        );
    }
    hints = "^G stop  ^R reset  ^C quit";
    hints_x = cols - len(hints) - 2;
    if hints_x > len(st_text) + 8 {
        buf.drawText(hints, hints_x, 1, br, bg, ATTR_DIM);
    }

    # ── Row 2: Content divider ────────────────────────────────────────────
    div_line = _hline("├", "─", "┤", cols);
    buf.drawText(div_line, 0, 2, br, bg, 0);

    # ── Layout ────────────────────────────────────────────────────────────
    input_row = rows - 1;
    input_div = rows - 2;

    transcript_start: int = 3;
    transcript_end: int = input_div - 1;

    transcript_h = transcript_end - transcript_start + 1;
    if transcript_h < 0 {
        transcript_h = 0;
    }

    # Reserve last transcript row for key warning if needed
    warn_row: int = -1;
    t_draw_end = transcript_end;
    if state.needs_key {
        warn_row = transcript_end;
        t_draw_end = transcript_end - 1;
    }

    # ── Transcript ────────────────────────────────────────────────────────
    # Refresh the cached row layout only when text changed (layout_dirty) or the
    # width drifted from what the cache was built at.
    if state.layout_dirty or state.layout_cols != cols {
        state.build_rows();
    }

    drows = state.display_rows;
    total = len(drows);
    t_draw_h = t_draw_end - transcript_start + 1;
    if t_draw_h < 0 {
        t_draw_h = 0;
    }
    max_top = total - t_draw_h;
    if max_top < 0 {
        max_top = 0;
    }
    # Pin to the last row while following the tail (streaming); otherwise just
    # clamp the manual scroll position into range.
    if state.follow_tail {
        state.viewport_top = max_top;
    }
    if state.viewport_top > max_top {
        state.viewport_top = max_top;
    }
    if state.viewport_top < 0 {
        state.viewport_top = 0;
    }

    row_idx: int = state.viewport_top;
    screen_row: int = transcript_start;

    while row_idx < total and screen_row <= t_draw_end {
        dr = drows[row_idx];
        # Cached text already carries prefix/indent; _trunc is a defensive guard
        # for the one frame a resize may precede a rebuild.
        display = _trunc(dr.text, inner_w);

        kind = dr.kind;
        ev_r: int = 200;
        ev_g: int = 200;
        ev_b: int = 200;
        ev_a: int = 0;
        if kind == "user" {
            ev_r = 255;
            ev_g = 255;
            ev_b = 255;
            ev_a = ATTR_BOLD;
        }
        if kind == "answer" {
            ev_r = 220;
            ev_g = 220;
            ev_b = 220;
            ev_a = 0;
        }
        if kind == "reasoning" {
            ev_r = 160;
            ev_g = 160;
            ev_b = 160;
            ev_a = ATTR_DIM;
        }
        if kind == "system" {
            ev_r = 86;
            ev_g = 182;
            ev_b = 194;
            ev_a = 0;
        }
        if kind == "error" {
            ev_r = 255;
            ev_g = 80;
            ev_b = 80;
            ev_a = ATTR_BOLD;
        }
        if kind == "phase" {
            ev_r = 255;
            ev_g = 210;
            ev_b = 60;
            ev_a = 0;
        }
        if kind == "call" {
            ev_r = 204;
            ev_g = 119;
            ev_b = 255;
            ev_a = 0;
        }
        if kind == "tool_result" {
            ev_r = 140;
            ev_g = 140;
            ev_b = 140;
            ev_a = ATTR_DIM;
        }

        buf.drawText("│", 0, screen_row, br, bg, 0);
        buf.drawText(display, 2, screen_row, rgb(ev_r, ev_g, ev_b), bg, ev_a);
        buf.drawText("│", cols - 1, screen_row, br, bg, 0);

        row_idx = row_idx + 1;
        screen_row = screen_row + 1;
    }

    # Empty transcript rows — borders only
    while screen_row <= t_draw_end {
        buf.drawText("│", 0, screen_row, br, bg, 0);
        buf.drawText("│", cols - 1, screen_row, br, bg, 0);
        screen_row = screen_row + 1;
    }

    # Key warning row
    if warn_row >= 0 {
        env = state.key_env;
        if len(env) == 0 {
            env = "API_KEY";
        }
        warn_text = _trunc(
            f"  Missing API key: {env}  (/settings to configure)", inner_w
        );
        buf.drawText("│", 0, warn_row, br, bg, 0);
        buf.drawText(warn_text, 2, warn_row, rgb(255, 80, 80), bg, 0);
        buf.drawText("│", cols - 1, warn_row, br, bg, 0);
    }

    # ── Input divider ──────────────────────────────────────────────────────
    buf.drawText(div_line, 0, input_div, br, bg, 0);

    # ── Input row ──────────────────────────────────────────────────────────
    buf.drawText("│", 0, input_row, br, bg, 0);
    buf.drawText("│", cols - 1, input_row, br, bg, 0);
    if state.status == "running" {
        buf.drawText("›", 2, input_row, rgb(120, 120, 120), bg, ATTR_DIM);
    } else {
        buf.drawText("›", 2, input_row, rgb(255, 255, 255), bg, ATTR_BOLD);
    }
    visible = _trunc(state.input_buf, inner_w - 2);
    buf.drawText(visible, 4, input_row, rgb(220, 220, 220), bg, 0);
}
