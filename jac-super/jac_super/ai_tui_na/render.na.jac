"""OpenTUI renderer: paints the full screen from TuiState each dirty cycle.

Layout (0-indexed rows):
  0        ┌─ jac.ai ─ cwd ─────────────────── model ─┐
  1        │ status  phase  [key hints right-aligned]   │
  2        ├─────────────────────────────────────────────┤
  3..R-3   │ transcript events                           │
  R-2      ├─────────────────────────────────────────────┤
  R-1      │ › input text                                │
"""

import from .state { TuiState }
import from .feed { event_prefix, event_text }

import from .opentui_helpers {
    def otui_begin -> None;  def otui_draw_text(
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
    ) -> None;  def otui_fill_rect(
        x: i32, y: i32, w: i32, h: i32, bg_r: i32, bg_g: i32, bg_b: i32
    ) -> None;  def otui_flush -> None;
}

glob BG_R: i32 = 18,
     BG_G: i32 = 18,
     BG_B: i32 = 28,
     BR_R: i32 = 70,
     BR_G: i32 = 70,
     BR_B: i32 = 100,
     ATTR_BOLD: i32 = 1,
     ATTR_DIM: i32 = 2,
     ATTR_ITAL: i32 = 4;

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

def _cwd_short(cwd: str) -> str {
    slen = len(cwd);
    last: int = -1;
    i: int = slen - 1;
    while i >= 0 {
        if cwd[i] == "/" {
            last = i;
            break;
        }
        i = i - 1;
    }
    if last <= 0 {
        return cwd;
    }
    prev: int = -1;
    j: int = last - 1;
    while j >= 0 {
        if cwd[j] == "/" {
            prev = j;
            break;
        }
        j = j - 1;
    }
    if prev < 0 {
        return cwd;
    }
    return "~" + cwd[prev:];
}

def render_full(state: TuiState) -> None {
    cols = state.term_cols;
    rows = state.term_rows;
    if cols < 10 or rows < 5 {
        return;
    }

    otui_begin();

    otui_fill_rect(0, 0, cols, rows, BG_R, BG_G, BG_B);

    # inner content width: col 0 = border, col 1 = space, cols-2 = space, cols-1 = border
    inner_w = cols - 4;
    if inner_w < 4 {
        inner_w = 4;
    }

    # ── Row 0: Top border with title ──────────────────────────────────────
    top_line = _hline("┌", "─", "┐", cols);
    otui_draw_text(0, 0, top_line, BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
    otui_draw_text(2, 0, " jac.ai ", 204, 0, 204, BG_R, BG_G, BG_B, ATTR_BOLD);

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
        otui_draw_text(
            cwd_start, 0, _trunc(cwd_d, cwd_avail), 86, 182, 194, BG_R, BG_G, BG_B, 0
        );
    }
    if model_start > cwd_start {
        otui_draw_text(
            model_start, 0, model, 120, 120, 120, BG_R, BG_G, BG_B, ATTR_DIM
        );
    }

    # ── Row 1: Status bar ─────────────────────────────────────────────────
    otui_draw_text(0, 1, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
    otui_draw_text(cols - 1, 1, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);

    st_text: str = "○ idle";
    st_r: i32 = 140;
    st_g: i32 = 140;
    st_b: i32 = 140;
    st_a: i32 = ATTR_DIM;
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
    otui_draw_text(2, 1, st_text, st_r, st_g, st_b, BG_R, BG_G, BG_B, st_a);
    if len(state.active) > 0 {
        act_x = len(st_text) + 4;
        otui_draw_text(
            act_x,
            1,
            _trunc(state.active, inner_w - act_x),
            255,
            210,
            60,
            BG_R,
            BG_G,
            BG_B,
            0
        );
    }
    hints = "^G stop  ^R reset  ^C quit";
    hints_x = cols - len(hints) - 2;
    if hints_x > len(st_text) + 8 {
        otui_draw_text(hints_x, 1, hints, BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, ATTR_DIM);
    }

    # ── Row 2: Content divider ────────────────────────────────────────────
    div_line = _hline("├", "─", "┤", cols);
    otui_draw_text(0, 2, div_line, BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);

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
    events = state.events;
    total = len(events);
    t_draw_h = t_draw_end - transcript_start + 1;
    if t_draw_h < 0 {
        t_draw_h = 0;
    }
    max_top = total - t_draw_h;
    if max_top < 0 {
        max_top = 0;
    }
    if state.viewport_top > max_top {
        state.viewport_top = max_top;
    }

    ev_idx: int = state.viewport_top;
    screen_row: int = transcript_start;

    while ev_idx < total and screen_row <= t_draw_end {
        ev = events[ev_idx];
        prefix = event_prefix(ev);
        body = event_text(ev);
        flat = body.replace("\n", " ");
        line = prefix + flat;
        display = _trunc(line, inner_w);

        kind = ev.kind;
        ev_r: i32 = 200;
        ev_g: i32 = 200;
        ev_b: i32 = 200;
        ev_a: i32 = 0;
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

        otui_draw_text(0, screen_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
        otui_draw_text(
            2, screen_row, display, ev_r, ev_g, ev_b, BG_R, BG_G, BG_B, ev_a
        );
        otui_draw_text(
            cols - 1, screen_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0
        );

        ev_idx = ev_idx + 1;
        screen_row = screen_row + 1;
    }

    # Empty transcript rows — borders only
    while screen_row <= t_draw_end {
        otui_draw_text(0, screen_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
        otui_draw_text(
            cols - 1, screen_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0
        );
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
        otui_draw_text(0, warn_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
        otui_draw_text(2, warn_row, warn_text, 255, 80, 80, BG_R, BG_G, BG_B, 0);
        otui_draw_text(cols - 1, warn_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
    }

    # ── Input divider ──────────────────────────────────────────────────────
    otui_draw_text(0, input_div, div_line, BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);

    # ── Input row ──────────────────────────────────────────────────────────
    otui_draw_text(0, input_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
    otui_draw_text(cols - 1, input_row, "│", BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, 0);
    if state.status == "running" {
        otui_draw_text(2, input_row, "›", 120, 120, 120, BG_R, BG_G, BG_B, ATTR_DIM);
    } else {
        otui_draw_text(2, input_row, "›", 255, 255, 255, BG_R, BG_G, BG_B, ATTR_BOLD);
    }
    visible = _trunc(state.input_buf, inner_w - 2);
    otui_draw_text(4, input_row, visible, 220, 220, 220, BG_R, BG_G, BG_B, 0);

    otui_flush();
}
