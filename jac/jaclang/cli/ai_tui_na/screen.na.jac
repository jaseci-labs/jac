import from .state { TuiState, DisplayRow, EventKind, TuiStatus, kind_style }
import from .editor { EditorState }
import from .feed { build_rows }
import from .overlay { overlay_build_modal, overlay_composite }
import from .terminal { ANSI_INVERSE, ANSI_RESET, ansi_sgr, term_spaces, term_dashes }
import from .width { visible_width, ansi_trunc, ansi_pad, idiv }
import from .theme {
    TH_BG,
    TH_SGR_BORDER,
    TH_SGR_CWD,
    TH_SGR_MODEL_DIM,
    TH_SGR_USER_PROMPT,
    TH_SGR_USER_MSG,
    TH_SGR_ANSWER,
    TH_SGR_PHASE,
    TH_SGR_ERROR,
    TH_SGR_RESULT,
    TH_SGR_AC_SEL,
    TH_SGR_AC_SEL_DESC,
    TH_SGR_AC_DESC_DIM
}

glob _MIN_COLS: int = 10,
     _MIN_ROWS: int = 6,
     _EDITOR_MAX_ROWS: int = 10,
     _AC_MAX_VISIBLE: int = 8,
     _AC_LABEL_MAX: int = 20;

def _framed_row(body: str) -> str {
    return TH_SGR_BORDER + "│ " + body + " " + TH_SGR_BORDER + "│" + ANSI_RESET;
}

def _framed_row_border_gap(body: str) -> str {
    return TH_SGR_BORDER + "│ " + body + TH_SGR_BORDER + " │" + ANSI_RESET;
}

def _empty_border_row(cols: int) -> str {
    return TH_SGR_BORDER + "│" + term_spaces(cols - 2) + "│" + ANSI_RESET;
}

def _divider_row(left: str, right: str, cols: int) -> str {
    return TH_SGR_BORDER + left + term_dashes(max(0, cols - 2)) + right + ANSI_RESET;
}

def _kind_sgr(kind: EventKind) -> str {
    s = kind_style(kind);
    return ansi_sgr(s.color, TH_BG, s.attrs);
}

def _transcript_row(dr: DisplayRow, cols: int) -> str {
    if dr.kind == EventKind.SEP {
        return _empty_border_row(cols);
    }
    if dr.pre_styled {
        return _framed_row_border_gap(dr.text);
    }
    inner_w = cols - 4;
    if dr.kind == EventKind.USER {
        content_w = inner_w - 1;
        padded = ansi_pad(ansi_trunc(dr.text, content_w), content_w);
        return _framed_row(TH_SGR_USER_MSG + padded);
    }
    return _framed_row(_kind_sgr(dr.kind) + ansi_trunc(dr.text, inner_w));
}

def _warn_row(env: str, cols: int) -> str {
    warn_text = ansi_trunc(
        f"  Missing API key: {env}  (/settings to configure)", cols - 4
    );
    return _framed_row(TH_SGR_ERROR + warn_text);
}

def _sync_display_rows(state: TuiState, cols: int) {
    if state.layout_dirty or state.layout_cols != cols {
        build_rows(state);
    }
}

def _clamp_viewport(state: TuiState, t_draw_h: int) {
    max_top = max(0, len(state.display_rows) - t_draw_h);
    if state.follow_tail {
        state.viewport_top = max_top;
    }
    state.viewport_top = max(0, min(state.viewport_top, max_top));
    if not state.follow_tail and state.viewport_top >= max_top {
        state.follow_tail = True;
    }
}

def _transcript_section(state: TuiState, t_draw_h: int, cols: int) -> list[str] {
    drows = state.display_rows;
    total = len(drows);
    rows: list[str] = [];
    for k in range(t_draw_h) {
        idx = state.viewport_top + k;
        if idx < total {
            rows.append(_transcript_row(drows[idx], cols));
        } else {
            rows.append(_empty_border_row(cols));
        }
    }
    return rows;
}

def _ac_item_row(label: str, desc: str, selected: bool, cols: int) -> str {
    inner_w = cols - 4;
    if inner_w < 4 {
        return _empty_border_row(cols);
    }
    label_max = max(1, min(_AC_LABEL_MAX, inner_w - 6));
    label_trunc = ansi_trunc(label, label_max);
    label_len = visible_width(label_trunc);
    pad_after = max(0, label_max - label_len);
    desc_avail = max(0, inner_w - 2 - label_max - 2);
    desc_trunc = ansi_trunc(desc, desc_avail);
    total_len = 2 + label_len + pad_after + 2 + visible_width(desc_trunc);
    trail = max(0, inner_w - total_len);

    item_sgr = TH_SGR_AC_SEL if selected else TH_SGR_RESULT;
    marker = "▸ " if selected else "  ";
    desc_sgr = TH_SGR_AC_SEL_DESC if selected else TH_SGR_AC_DESC_DIM;

    body = item_sgr + marker + label_trunc + term_spaces(pad_after) + "  " + desc_sgr + desc_trunc + term_spaces(
        trail
    );
    return _framed_row_border_gap(body);
}

def _ac_section(state: TuiState, ac_h: int, cols: int) -> list[str] {
    shown = state.ac.items[:ac_h];
    rows: list[str] = [];
    for (idx, item) in enumerate(shown) {
        is_sel = idx == state.ac.selected_idx;
        rows.append(_ac_item_row(item.label, item.description, is_sel, cols));
    }
    return rows;
}

def _ed_vl_count(line_len: int, width: int) -> int {
    if width <= 0 or line_len == 0 {
        return 1;
    }
    return idiv(line_len + width - 1, width);
}

def _ed_total_vlines(ed: EditorState, width: int) -> int {
    return sum(_ed_vl_count(len(line), width) for line in ed.lines);
}

def _editor_text_width(cols: int) -> int {
    return max(1, cols - 6);
}

def _wrap_editor_lines(ed: EditorState, text_w: int) -> list[str] {
    chunks: list[str] = [];
    for line in ed.lines {
        llen = len(line);
        for j in range(_ed_vl_count(llen, text_w)) {
            chunk_start = j * text_w;
            chunk_end = min(chunk_start + text_w, llen);
            chunks.append(line[chunk_start:chunk_end]);
        }
    }
    return chunks;
}

def _cursor_vline_col(ed: EditorState, text_w: int) -> tuple[int, int] {
    if ed.cursor_line < 0 or ed.cursor_line >= len(ed.lines) {
        return (-1, -1);
    }
    sub = idiv(ed.cursor_col, text_w);
    if sub >= _ed_vl_count(len(ed.lines[ed.cursor_line]), text_w) {
        return (-1, -1);
    }
    vline = sub;
    for i in range(ed.cursor_line) {
        vline += _ed_vl_count(len(ed.lines[i]), text_w);
    }
    return (vline, ed.cursor_col - sub * text_w);
}

def _render_cursor(chunk: str, vcol: int) -> str {
    before = chunk[:vcol];
    if vcol < len(chunk) {
        cur_char = chunk[vcol];
        after = chunk[vcol + 1:];
        return before + ANSI_INVERSE + cur_char + ANSI_RESET + after;
    }
    return before + ANSI_INVERSE + " " + ANSI_RESET;
}

def _editor_rows(
    ed: EditorState, cols: int, max_rows: int, is_running: bool
) -> list[str] {
    text_w = _editor_text_width(cols);
    prompt_sgr = TH_SGR_MODEL_DIM if is_running else TH_SGR_USER_PROMPT;

    chunks = _wrap_editor_lines(ed, text_w);
    total_vl = len(chunks);
    (cur_vline, cur_vcol) = _cursor_vline_col(ed, text_w);
    scroll = max(0, min(ed.scroll_offset, total_vl - 1));

    result: list[str] = [];
    for k in range(max_rows) {
        row_vi = scroll + k;
        chunk = chunks[row_vi] if row_vi < total_vl else "";
        display = chunk;
        if row_vi == cur_vline and cur_vcol >= 0 {
            display = _render_cursor(chunk, cur_vcol);
        }
        display = ansi_pad(display, text_w);
        prefix = (prompt_sgr + "› " + TH_SGR_ANSWER)
            if k == 0
            else (TH_SGR_ANSWER + "  ");
        result.append(_framed_row(prefix + display));
    }
    return result;
}

def _editor_height(ed: EditorState, cols: int, rows: int) -> int {
    total_vl = max(1, _ed_total_vlines(ed, _editor_text_width(cols)));
    max_h = min(_EDITOR_MAX_ROWS, max(1, rows - 3));
    return min(total_vl, max_h);
}

def _cwd_short(cwd: str) -> str {
    last = cwd.rfind("/");
    if last <= 0 {
        return cwd;
    }
    head = cwd[0:last];
    prev = head.rfind("/");
    if prev < 0 {
        return cwd;
    }
    return "~" + cwd[prev:];
}

def _status_footer_row(state: TuiState, cols: int) -> str {
    inner_w = cols - 4;

    act_disp: str = "";
    act_len: int = 0;
    if state.active {
        act_max = inner_w - 3;
        if act_max > 0 {
            act_disp = ansi_trunc(state.active, act_max);
            act_len = visible_width(act_disp);
        }
    }

    model_s = state.model_name if visible_width(state.model_name) > 0 else "no model";
    model_len = visible_width(model_s);

    cwd_avail = max(0, inner_w - act_len - model_len - 3);
    cwd_disp = ansi_trunc(_cwd_short(state.cwd), cwd_avail);
    cwd_len = visible_width(cwd_disp);

    right_len = cwd_len + model_len;
    if cwd_len > 0 {
        right_len += 1;
    }
    total_dashes = max(1, inner_w - act_len - right_len);

    parts: list[str] = [TH_SGR_BORDER + "│ "];
    if act_len > 0 {
        parts.append(TH_SGR_PHASE + act_disp);
    }
    parts.append(TH_SGR_BORDER + term_dashes(total_dashes));
    if cwd_len > 0 {
        parts.append(TH_SGR_CWD + cwd_disp + " ");
    }
    parts.append(TH_SGR_MODEL_DIM + model_s + " " + TH_SGR_BORDER + "│" + ANSI_RESET);
    return "".join(parts);
}

def screen_render(state: TuiState, cols: int, rows: int) -> list[str] {
    if cols < _MIN_COLS or rows < _MIN_ROWS {
        return ["" for _ in range(rows)];
    }

    ed = state.editor;
    editor_h = _editor_height(ed, cols, rows);
    is_running = state.status == TuiStatus.RUNNING;
    ac_h = min(_AC_MAX_VISIBLE, len(state.ac.items)) if state.ac.active else 0;

    transcript_h = max(0, rows - 1 - editor_h - ac_h - 1);
    show_warn = state.needs_key;
    t_draw_h = max(0, transcript_h - 1) if show_warn else transcript_h;

    _sync_display_rows(state, cols);
    _clamp_viewport(state, t_draw_h);

    out: list[str] = [];
    out.extend(_transcript_section(state, t_draw_h, cols));

    if show_warn {
        env = state.key_env or "API_KEY";
        out.append(_warn_row(env, cols));
    }

    if state.ac.active and ac_h > 0 {
        out.extend(_ac_section(state, ac_h, cols));
    }

    out.append(_divider_row("├", "┤", cols));
    out.extend(_editor_rows(ed, cols, editor_h, is_running));
    out.append(_status_footer_row(state, cols));

    if state.overlay_active {
        modal = overlay_build_modal(state, cols, rows);
        out = overlay_composite(out, modal, cols, rows);
    }

    return out;
}
