"""Modal overlays composited on top of the base screen.

Phase 6: center-anchored command palette using SelectList.
"""

import from .state { TuiState }
import from .commands { palette_commands, run_command }
import from .width { visible_width, ansi_trunc, ansi_pad }
import from .terminal { ansi_sgr, ansi_reset }
import from .theme {
    TH_BG_R,
    TH_BG_G,
    TH_BG_B,
    TH_BORDER_R,
    TH_BORDER_G,
    TH_BORDER_B,
    TH_TITLE_R,
    TH_TITLE_G,
    TH_TITLE_B,
    TH_BOLD,
    TH_DIM
}

def _ov_spaces(n: int) -> str {
    s: str = "";
    i: int = 0;
    while i < n {
        s = s + " ";
        i = i + 1;
    }
    return s;
}

def _ov_dashes(n: int) -> str {
    s: str = "";
    i: int = 0;
    while i < n {
        s = s + "─";
        i = i + 1;
    }
    return s;
}

def overlay_is_active(state: TuiState) -> bool {
    return state.overlay_active;
}

def overlay_open_palette(state: TuiState, initial_filter: str) {
    items = palette_commands(state);
    sl = state.select_list;
    sl.reset_items(items);
    sl.set_filter(initial_filter);
    sl.max_visible = 8;
    if state.term_rows < 20 {
        sl.max_visible = 5;
    }
    state.overlay_filter = initial_filter;
    state.overlay_title = "Commands";
    state.overlay_active = True;
    state.overlay_full_redraw = True;
    state.dirty = True;
}

def overlay_close(state: TuiState) {
    if not state.overlay_active {
        return;
    }
    state.overlay_active = False;
    state.overlay_filter = "";
    state.overlay_title = "";
    state.overlay_full_redraw = True;
    state.dirty = True;
}

def overlay_handle_key(key: str, state: TuiState, ipc_fd: int) -> bool {
    sl = state.select_list;
    action = sl.handle_key(key);
    if action == "cancel" {
        overlay_close(state);
        return False;
    }
    if action == "changed" {
        state.overlay_filter = sl.filter_text;
        state.dirty = True;
        return False;
    }
    if action == "select" {
        item = sl.current();
        if item is None {
            return False;
        }
        should_quit = run_command(item.value, state, ipc_fd);
        overlay_close(state);
        return should_quit;
    }
    return False;
}

def _border_sgr -> str {
    return ansi_sgr(
        TH_BORDER_R, TH_BORDER_G, TH_BORDER_B, TH_BG_R, TH_BG_G, TH_BG_B, 0
    );
}

def _title_sgr -> str {
    return ansi_sgr(
        TH_TITLE_R, TH_TITLE_G, TH_TITLE_B, TH_BG_R, TH_BG_G, TH_BG_B, TH_BOLD
    );
}

def _dim_sgr -> str {
    return ansi_sgr(
        TH_BORDER_R, TH_BORDER_G, TH_BORDER_B, TH_BG_R, TH_BG_G, TH_BG_B, TH_DIM
    );
}

def _modal_width(cols: int) -> int {
    w = cols - 4;
    if w > 64 {
        w = 64;
    }
    if w < 24 {
        w = cols - 2;
    }
    if w < 16 {
        w = 16;
    }
    return w;
}

def overlay_build_modal(state: TuiState, cols: int, rows: int) -> list[str] {
    modal_w = _modal_width(cols);
    inner_w = modal_w - 4;
    if inner_w < 8 {
        inner_w = 8;
    }

    sl = state.select_list;
    content = sl.render(inner_w);

    # Optional filter hint row.
    if len(state.overlay_filter) > 0 {
        filt = f"filter: {state.overlay_filter}";
        filt = ansi_trunc(filt, inner_w);
        content = [ansi_pad(_dim_sgr() + filt + ansi_reset(), inner_w)] + content;
    }

    title = state.overlay_title;
    if len(title) == 0 {
        title = "Commands";
    }
    title_max = inner_w - 2;
    if title_max < 1 {
        title_max = 1;
    }
    title_disp = ansi_trunc(title, title_max);
    title_len = visible_width(title_disp);
    top_fill = inner_w - title_len;
    if top_fill < 0 {
        top_fill = 0;
    }

    border = _border_sgr();
    reset = ansi_reset();
    modal: list[str] = [];

    top: str = border + "┌─ " + _title_sgr() + title_disp + border;
    top = top + _ov_dashes(top_fill) + "┐" + reset;
    modal.append(ansi_pad(top, modal_w));

    ci: int = 0;
    cn = len(content);
    while ci < cn {
        line = content[ci];
        row: str = border + "│ " + line;
        row = ansi_pad(row, modal_w - 1) + border + "│" + reset;
        modal.append(row);
        ci = ci + 1;
    }

    bottom: str = border + "└" + _ov_dashes(modal_w - 2) + "┘" + reset;
    modal.append(bottom);

    # Pad modal to center vertically: left/right margin on each row.
    margin = (cols - modal_w) // 2;
    if margin < 0 {
        margin = 0;
    }
    pad_left = _ov_spaces(margin);

    padded: list[str] = [];
    mi: int = 0;
    mn = len(modal);
    while mi < mn {
        padded.append(ansi_pad(pad_left + modal[mi], cols));
        mi = mi + 1;
    }

    # Center vertically within full terminal height.
    modal_h = len(padded);
    start_row = (rows - modal_h) // 2;
    if start_row < 1 {
        start_row = 1;
    }

    result: list[str] = [];
    ri: int = 0;
    while ri < rows {
        if ri >= start_row and ri < start_row + modal_h {
            result.append(padded[ri - start_row]);
        } else {
            result.append("");
        }
        ri = ri + 1;
    }
    return result;
}

def overlay_composite(
    base: list[str], modal_rows: list[str], cols: int, rows: int
) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < rows {
        base_line = "";
        if i < len(base) {
            base_line = base[i];
        }
        modal_line = "";
        if i < len(modal_rows) {
            modal_line = modal_rows[i];
        }
        if len(modal_line) > 0 {
            out.append(modal_line);
        } else {
            out.append(base_line);
        }
        i = i + 1;
    }
    return out;
}
