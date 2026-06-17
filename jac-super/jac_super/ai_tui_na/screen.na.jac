"""Screen renderer: TuiState -> list[str] (one ANSI string per terminal row).

Row strings carry SGR color codes but no cursor-positioning sequences.
The DiffEngine (diff.na.jac) owns cursor movement and paints changed rows.

Layout (0-indexed rows):
  0        ┌─ jac.ai ─ cwd ─────────────── model ─┐
  1        │ status  active  [hints right-aligned]  │
  2        ├────────────────────────────────────────┤
  3..R-3   │ transcript events                      │
  R-2      ├────────────────────────────────────────┤
  R-1      │ › input text                           │
"""

import from .state { TuiState, DisplayRow, EditorState }
import from .feed { build_rows }
import from .terminal { ansi_sgr, ansi_reset }
import from .width { visible_width, ansi_trunc, ansi_pad }

# ── Palette (hardcoded SGR strings — avoids calling functions at glob-init) ───
# Format: ESC[0[;attrs];38;2;R;G;Bm;48;2;R;G;Bm   bg=(18,18,28)
glob _SB: str = "\033[0;38;2;70;70;100;48;2;18;18;28m";  # border/chrome
glob _ST: str = "\033[0;1;38;2;204;0;204;48;2;18;18;28m";  # title bold
glob _SC: str = "\033[0;38;2;86;182;194;48;2;18;18;28m";  # cwd cyan
glob _SM: str = "\033[0;2;38;2;120;120;120;48;2;18;18;28m";  # model dim
glob _SR: str = "\033[0m";  # reset

# User message: white bold on indigo-tinted bg (26,26,46) for visual contrast
glob _USER_MSG: str = "\033[0;1;38;2;255;255;255;48;2;26;26;46m";
# Reasoning: italic+dim gray (theme DIM_ITALIC=6 → ;2;3 in SGR)
glob _REASON_MSG: str = "\033[0;2;3;38;2;160;160;160;48;2;18;18;28m";

# Background and attribute constants used by ansi_sgr() calls in functions below.
# See theme.na.jac for the canonical named values.
glob BG_R: int = 18,
     BG_G: int = 18,
     BG_B: int = 28;
glob BR_R: int = 70,
     BR_G: int = 70,
     BR_B: int = 100;
glob ATTR_BOLD: int = 1,
     ATTR_DIM: int = 2,
     ATTR_ITALIC: int = 4;

# ── String helpers ────────────────────────────────────────────────────────────
def _spaces(n: int) -> str {
    s: str = "";
    i: int = 0;
    while i < n {
        s = s + " ";
        i = i + 1;
    }
    return s;
}

def _dashes(n: int) -> str {
    s: str = "";
    i: int = 0;
    while i < n {
        s = s + "─";
        i = i + 1;
    }
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

def _kind_sgr(kind: str) -> str {
    if kind == "user" {
        return ansi_sgr(255, 255, 255, BG_R, BG_G, BG_B, ATTR_BOLD);
    }
    if kind == "answer" {
        return ansi_sgr(220, 220, 220, BG_R, BG_G, BG_B, 0);
    }
    if kind == "reasoning" {
        return _REASON_MSG;
    }
    if kind == "system" {
        return ansi_sgr(86, 182, 194, BG_R, BG_G, BG_B, 0);
    }
    if kind == "error" {
        return ansi_sgr(255, 80, 80, BG_R, BG_G, BG_B, ATTR_BOLD);
    }
    if kind == "phase" {
        return ansi_sgr(255, 210, 60, BG_R, BG_G, BG_B, 0);
    }
    if kind == "call" {
        return ansi_sgr(204, 119, 255, BG_R, BG_G, BG_B, 0);
    }
    if kind == "tool_result" {
        return ansi_sgr(140, 140, 140, BG_R, BG_G, BG_B, ATTR_DIM);
    }
    return ansi_sgr(200, 200, 200, BG_R, BG_G, BG_B, 0);
}

# ── Row builders ─────────────────────────────────────────────────────────────
def _header_row(cwd: str, model: str, cols: int) -> str {
    # Row 0: ┌─ jac.ai ── cwd ──── model ─┐
    # Fixed left = 12 vis cols ("┌─" + " jac.ai " + "──"), right = 2 ("─┐").
    # Remaining space: cwd + dashes (min 2) + model.
    model_s: str = model;
    if visible_width(model_s) == 0 {
        model_s = "no model";
    }
    model_len = visible_width(model_s);

    cwd_d = _cwd_short(cwd);
    cwd_avail = cols - 16 - model_len;
    if cwd_avail < 0 {
        cwd_avail = 0;
    }
    cwd_disp = ansi_trunc(cwd_d, cwd_avail);
    cwd_len = visible_width(cwd_disp);

    total_dashes = cols - 14 - cwd_len - model_len;
    if total_dashes < 2 {
        total_dashes = 2;
    }

    row: str = _SB + "┌─";
    row = row + _ST + " jac.ai ";
    row = row + _SB + "──";
    if cwd_len > 0 {
        row = row + _SC + cwd_disp;
    }
    row = row + _SB + _dashes(total_dashes);
    if model_len > 0 {
        row = row + _SM + model_s;
    }
    row = row + _SB + "─┐" + _SR;
    return row;
}

def _status_row(state: TuiState, cols: int) -> str {
    # Row 1: │ status  active          hints │
    inner_w = cols - 4;

    st_text: str = "○ idle";
    st_sgr = ansi_sgr(140, 140, 140, BG_R, BG_G, BG_B, ATTR_DIM);
    if state.status == "running" {
        st_text = "● running";
        st_sgr = ansi_sgr(255, 200, 50, BG_R, BG_G, BG_B, 0);
    }
    if state.status == "done" {
        st_text = "✓ done";
        st_sgr = ansi_sgr(80, 200, 80, BG_R, BG_G, BG_B, 0);
    }
    if state.status == "stopping" {
        st_text = "○ stopping";
        st_sgr = ansi_sgr(255, 80, 80, BG_R, BG_G, BG_B, 0);
    }
    # Use visible_width: "○", "●", "✓" are 3-byte UTF-8 but 1 visible column each.
    st_len = visible_width(st_text);

    act_disp: str = "";
    act_len: int = 0;
    if len(state.active) > 0 {
        act_max = inner_w - st_len - 3;
        if act_max > 0 {
            act_disp = ansi_trunc(state.active, act_max);
            act_len = visible_width(act_disp);
        }
    }

    hints: str = "^G stop  ^R reset  ^C quit";
    hints_len = len(hints);  # pure ASCII: len() == visible_width()

    left_len = st_len + 1;
    if act_len > 0 {
        left_len = left_len + 1 + act_len;
    }
    right_len = hints_len + 1;
    gap = inner_w - left_len - right_len;
    if gap < 1 {
        gap = 1;
    }

    row: str = _SB + "│ " + st_sgr + st_text;
    if act_len > 0 {
        row = row + " " + ansi_sgr(255, 210, 60, BG_R, BG_G, BG_B, 0) + act_disp;
    }
    if gap >= 1 and hints_len <= inner_w - left_len - 2 {
        row = row + _spaces(gap);
        row = row + ansi_sgr(BR_R, BR_G, BR_B, BG_R, BG_G, BG_B, ATTR_DIM) + hints;
    }
    row = row + " " + _SB + "│" + _SR;
    return row;
}

def _divider_row(left: str, right: str, cols: int) -> str {
    # Horizontal rule: left + ─*n + right.
    fill = cols - 2;
    if fill < 0 {
        fill = 0;
    }
    return _SB + left + _dashes(fill) + right + _SR;
}

def _transcript_row(dr: DisplayRow, cols: int) -> str {
    # Separator between events: render as an empty border row.
    if dr.kind == "sep" {
        return _SB + "│" + _spaces(cols - 2) + "│" + _SR;
    }

    inner_w = cols - 4;

    # Pre-styled rows (markdown-rendered answer/reasoning): text is already ANSI-coded
    # and padded to inner_w columns. Embed directly without _kind_sgr override.
    if dr.pre_styled {
        return _SB + "│ " + dr.text + _SB + " │" + _SR;
    }

    # User message: fill the entire inner area with a tinted background so
    # the message stands out visually (pi-tui userMessageBg treatment).
    if dr.kind == "user" {
        content_w = inner_w - 1;  # one column reserved for trailing border space
        display = ansi_trunc(dr.text, content_w);
        padded = ansi_pad(display, content_w);
        return _SB + "│ " + _USER_MSG + padded + " " + _SB + "│" + _SR;
    }

    display = ansi_trunc(dr.text, inner_w);
    row: str = _SB + "│ " + _kind_sgr(dr.kind) + display + " " + _SB + "│" + _SR;
    return row;
}

def _empty_border_row(cols: int) -> str {
    return _SB + "│" + _spaces(cols - 2) + "│" + _SR;
}

def _warn_row(env: str, cols: int) -> str {
    inner_w = cols - 4;
    warn_text = ansi_trunc(
        f"  Missing API key: {env}  (/settings to configure)", inner_w
    );
    return _SB + "│ " + ansi_sgr(255, 80, 80, BG_R, BG_G, BG_B, 0) + warn_text + " " + _SB + "│" + _SR;
}

def _idiv_s(a: int, b: int) -> int {
    # Integer floor division (screen-local helper).
    if b <= 0 {
        return 0;
    }
    result: int = 0;
    rem: int = a;
    while rem >= b {
        rem = rem - b;
        result = result + 1;
    }
    return result;
}

def _ed_vl_count(line_len: int, width: int) -> int {
    # Visual line count for one logical line.
    if width <= 0 or line_len == 0 {
        return 1;
    }
    return _idiv_s(line_len + width - 1, width);
}

def _ed_total_vlines(ed: EditorState, width: int) -> int {
    total: int = 0;
    i: int = 0;
    n = len(ed.lines);
    while i < n {
        total = total + _ed_vl_count(len(ed.lines[i]), width);
        i = i + 1;
    }
    return total;
}

def _editor_rows(
    ed: EditorState, cols: int, max_rows: int, is_running: bool
) -> list[str] {
    # Render the editor into content rows, bordered by the box walls.
    # text_width: space left after "│ › " (prefix) and " │" (suffix) = cols - 6
    # All editor lines use 2-char indent: "› " for first, "  " for rest.
    text_w = cols - 6;
    if text_w < 1 {
        text_w = 1;
    }

    if is_running {
        prompt_sgr = ansi_sgr(120, 120, 120, BG_R, BG_G, BG_B, ATTR_DIM);
    } else {
        prompt_sgr = ansi_sgr(255, 255, 255, BG_R, BG_G, BG_B, ATTR_BOLD);
    }
    text_sgr = ansi_sgr(220, 220, 220, BG_R, BG_G, BG_B, 0);
    cursor_sgr: str = "\033[7m";  # reverse video for cursor

    # Build list of (visual_line_text, cursor_vis_col) pairs.
    # cursor_vis_col = -1 means no cursor on this visual line.
    vis_texts: list[str] = [];
    vis_cursor_cols: list[int] = [];

    n_lines = len(ed.lines);
    i: int = 0;

    while i < n_lines {
        line = ed.lines[i];
        llen = len(line);
        vl_count = _ed_vl_count(llen, text_w);

        j: int = 0;
        while j < vl_count {
            chunk_start = j * text_w;
            chunk_end = chunk_start + text_w;
            if chunk_end > llen {
                chunk_end = llen;
            }
            chunk = line[chunk_start:chunk_end];
            vis_texts.append(chunk);

            # Determine cursor position on this visual line.
            if i == ed.cursor_line {
                cur_vsubline = _idiv_s(ed.cursor_col, text_w);
                if cur_vsubline == j {
                    vcol = ed.cursor_col - j * text_w;
                    vis_cursor_cols.append(vcol);
                } else {
                    vis_cursor_cols.append(-1);
                }
            } else {
                vis_cursor_cols.append(-1);
            }

            j = j + 1;
        }
        i = i + 1;
    }

    # Apply scroll: show [scroll_offset .. scroll_offset + max_rows).
    scroll = ed.scroll_offset;
    total_vl = len(vis_texts);
    if scroll < 0 {
        scroll = 0;
    }
    if scroll > total_vl - 1 {
        scroll = total_vl - 1;
    }
    if scroll < 0 {
        scroll = 0;
    }

    result: list[str] = [];
    row_vi: int = scroll;
    rows_emitted: int = 0;
    is_first_row: bool = True;

    while rows_emitted < max_rows {
        if row_vi < total_vl {
            chunk = vis_texts[row_vi];
            vcol = vis_cursor_cols[row_vi];
        } else {
            chunk = "";
            vcol = -1;
        }

        # Build display text with cursor.
        if vcol >= 0 {
            # Cursor is on this visual line.
            before = chunk[:vcol];
            if vcol < len(chunk) {
                cur_char = chunk[vcol];
                after = chunk[vcol + 1:];
                display = before + cursor_sgr + cur_char + "\033[0m" + after;
            } else {
                # Cursor at end: show inverted space.
                display = before + cursor_sgr + " " + "\033[0m";
            }
        } else {
            display = chunk;
        }

        # Pad to text_w visible columns.
        dw = visible_width(display);
        if dw < text_w {
            display = display + _spaces(text_w - dw);
        }

        # Build full row with box borders.
        if is_first_row {
            prefix = prompt_sgr + "› " + text_sgr;
            is_first_row = False;
        } else {
            prefix = text_sgr + "  ";
        }

        row: str = _SB + "│ " + prefix + display + " " + _SB + "│" + _SR;
        result.append(row);
        row_vi = row_vi + 1;
        rows_emitted = rows_emitted + 1;
    }

    return result;
}

def _editor_height(ed: EditorState, cols: int, rows: int) -> int {
    # Number of editor content rows to emit (1 <= h <= max).
    text_w = cols - 6;
    if text_w < 1 {
        text_w = 1;
    }
    total_vl = _ed_total_vlines(ed, text_w);
    max_h: int = rows - 6;  # leave room for header+status+divider+sep+at_least_1_transcript
    if max_h < 1 {
        max_h = 1;
    }
    if max_h > 10 {
        max_h = 10;
    }
    if total_vl < 1 {
        total_vl = 1;
    }
    if total_vl < max_h {
        return total_vl;
    }
    return max_h;
}

# ── Main render entry ─────────────────────────────────────────────────────────
def screen_render(state: TuiState, cols: int, rows: int) -> list[str] {
    # Return one row string per terminal row. Called every dirty cycle.
    out: list[str] = [];

    if cols < 10 or rows < 5 {
        i: int = 0;
        while i < rows {
            out.append("");
            i = i + 1;
        }
        return out;
    }

    # Row 0: header
    out.append(_header_row(state.cwd, state.model_name, cols));

    # Row 1: status bar
    out.append(_status_row(state, cols));

    # Row 2: content divider
    out.append(_divider_row("├", "┤", cols));

    # Editor height is variable: compute it now so transcript area is sized correctly.
    # Layout: rows 0-2 = header/status/divider; 1 separator before editor; editor_h rows.
    ed = state.editor;
    editor_h = _editor_height(ed, cols, rows);
    is_running = state.status == "running";

    # Transcript occupies rows 3 .. (rows - 2 - editor_h).
    # 1 separator row above editor, then editor_h content rows at bottom.
    transcript_h = rows - 3 - 1 - editor_h;
    if transcript_h < 0 {
        transcript_h = 0;
    }

    # Last transcript row reserved for key-missing warning when needed.
    t_draw_h = transcript_h;
    show_warn: bool = False;
    if state.needs_key {
        show_warn = True;
        t_draw_h = transcript_h - 1;
        if t_draw_h < 0 {
            t_draw_h = 0;
        }
    }

    # Rebuild display-row cache if layout changed.
    if state.layout_dirty or state.layout_cols != cols {
        build_rows(state);
    }

    drows = state.display_rows;
    total = len(drows);

    max_top = total - t_draw_h;
    if max_top < 0 {
        max_top = 0;
    }
    if state.follow_tail {
        state.viewport_top = max_top;
    }
    if state.viewport_top > max_top {
        state.viewport_top = max_top;
    }
    if state.viewport_top < 0 {
        state.viewport_top = 0;
    }

    # Emit transcript rows.
    row_idx = state.viewport_top;
    t_shown: int = 0;
    while t_shown < t_draw_h {
        if row_idx < total {
            out.append(_transcript_row(drows[row_idx], cols));
            row_idx = row_idx + 1;
        } else {
            out.append(_empty_border_row(cols));
        }
        t_shown = t_shown + 1;
    }

    # Optional key-warning row.
    if show_warn {
        env = state.key_env;
        if len(env) == 0 {
            env = "API_KEY";
        }
        out.append(_warn_row(env, cols));
    }

    # Render editor rows (ed/editor_h/is_running already computed above).
    editor_rows = _editor_rows(ed, cols, editor_h, is_running);

    # Input divider (above editor).
    out.append(_divider_row("├", "┤", cols));

    # Editor content rows.
    ri: int = 0;
    while ri < editor_h {
        out.append(editor_rows[ri]);
        ri = ri + 1;
    }

    return out;
}
