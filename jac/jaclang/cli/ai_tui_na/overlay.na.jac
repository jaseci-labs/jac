import from .state { TuiState, OverlayKind, OverlayContent, OverlaySpec, Anchor }
import from .keys { Key }
import from .commands {
    palette_commands,
    model_items,
    file_items
}
import from .select_list { SelectItem }
import from .width { visible_width, ansi_trunc, ansi_pad }
import from .terminal { ANSI_RESET, term_spaces, term_dashes }
import from .theme { TH_SGR_BORDER, TH_SGR_BORDER_DIM, TH_SGR_TITLE }

glob _LIST_ROWS: int = 8,
     _LIST_ROWS_SMALL: int = 5,
     _SMALL_TERM_ROWS: int = 20;
glob _MODAL_MAX_W: int = 64,
     _MODAL_COMFORT_W: int = 24,
     _MODAL_MIN_W: int = 16,
     _MODAL_INNER_MIN_W: int = 8;

def overlay_is_active(state: TuiState) -> bool {
    return state.overlay_stack.is_active();
}

def _overlay_show(
    state: TuiState,
    kind: OverlayKind,
    title: str,
    items: list[SelectItem],
    initial_filter: str
) {
    sl = state.select_list;
    sl.reset_items(items);
    sl.set_filter(initial_filter);
    sl.max_visible = _LIST_ROWS_SMALL
        if state.term_rows < _SMALL_TERM_ROWS
        else _LIST_ROWS;
    st = state.overlay_stack;
    st.clear();
    st.push(OverlaySpec(content=OverlayContent.SELECT_LIST, role=kind, title=title));
    state.overlay_full_redraw = True;
    state.dirty = True;
}

def overlay_open_palette(state: TuiState, initial_filter: str) {
    _overlay_show(
        state, OverlayKind.PALETTE, "Commands", palette_commands(state), initial_filter
    );
}

def overlay_open_model(state: TuiState) {
    _overlay_show(state, OverlayKind.MODEL, "Select model", model_items(state), "");
}

def overlay_open_file(state: TuiState) {
    _overlay_show(state, OverlayKind.FILE, "Insert file", file_items(state), "");
}

def overlay_close(state: TuiState) {
    st = state.overlay_stack;
    if not st.is_active() {
        return;
    }
    st.pop();
    state.overlay_full_redraw = True;
    state.dirty = True;
}

# Key handling for overlays lives in reducer.reduce_input (Phase 5).
# overlay_handle_key retained as a no-op shim for older call sites.
def overlay_handle_key(k: Key, state: TuiState) -> bool {
    return False;
}

def _modal_width(cols: int, width_pct: int) -> int {
    if width_pct > 0 {
        w = cols * width_pct // 100;
        return max(_MODAL_MIN_W, min(w, cols - 2));
    }
    w = min(cols - 4, _MODAL_MAX_W);
    if w < _MODAL_COMFORT_W {
        w = max(cols - 2, _MODAL_MIN_W);
    }
    return w;
}

def _modal_content(state: TuiState, inner_w: int) -> list[str] {
    content = state.select_list.render(inner_w);
    ft = state.select_list.filter_text;
    if not ft {
        return content;
    }
    filt = ansi_trunc(f"filter: {ft}", inner_w);
    header = ansi_pad(TH_SGR_BORDER_DIM + filt + ANSI_RESET, inner_w);
    return [header] + content;
}

def _frame_box(
    content: list[str], title: str, modal_w: int, inner_w: int
) -> list[str] {
    title_disp = ansi_trunc(title, max(1, inner_w - 2));
    top_fill = max(0, inner_w - visible_width(title_disp));
    border = TH_SGR_BORDER;
    reset = ANSI_RESET;

    top = (
        border + "┌─ " + TH_SGR_TITLE + title_disp + border + term_dashes(top_fill) + "┐" + reset
    );
    boxed: list[str] = [ansi_pad(top, modal_w)];
    for line in content {
        row = border + "│ " + line;
        boxed.append(ansi_pad(row, modal_w - 1) + border + "│" + reset);
    }
    boxed.append(border + "└" + term_dashes(modal_w - 2) + "┘" + reset);
    return boxed;
}

def _anchor_left(anchor: Anchor, modal_w: int, cols: int, ox: int) -> int {
    left = (cols - modal_w) // 2;
    if anchor == Anchor.TOP_LEFT or anchor == Anchor.BOTTOM_LEFT or anchor == Anchor.LEFT {
        left = 0;
    }
    if anchor == Anchor.TOP_RIGHT or anchor == Anchor.BOTTOM_RIGHT or anchor == Anchor.RIGHT {
        left = cols - modal_w;
    }
    left = left + ox;
    if left < 0 {
        left = 0;
    }
    if left > cols - modal_w {
        left = max(0, cols - modal_w);
    }
    return left;
}

def _anchor_top(anchor: Anchor, modal_h: int, rows: int, oy: int) -> int {
    top = (rows - modal_h) // 2;
    if anchor == Anchor.TOP or anchor == Anchor.TOP_LEFT or anchor == Anchor.TOP_RIGHT {
        top = 0;
    }
    if anchor == Anchor.BOTTOM or anchor == Anchor.BOTTOM_LEFT or anchor == Anchor.BOTTOM_RIGHT {
        top = rows - modal_h;
    }
    top = top + oy;
    if top < 1 {
        top = 1;
    }
    if top > rows - modal_h {
        top = max(1, rows - modal_h);
    }
    return top;
}

def _anchor_place(
    boxed: list[str], anchor: Anchor, modal_w: int, cols: int, rows: int, ox: int, oy: int
) -> list[str] {
    modal_h = len(boxed);
    left = _anchor_left(anchor, modal_w, cols, ox);
    top = _anchor_top(anchor, modal_h, rows, oy);
    pad_left = term_spaces(left);

    placed: list[str] = [];
    for ri in range(rows) {
        if ri >= top and ri < top + modal_h {
            placed.append(ansi_pad(pad_left + boxed[ri - top], cols));
        } else {
            placed.append("");
        }
    }
    return placed;
}

def overlay_build_modal(state: TuiState, cols: int, rows: int) -> list[str] {
    spec = state.overlay_stack.active_spec();
    modal_w = _modal_width(cols, spec.width_pct);
    inner_w = max(_MODAL_INNER_MIN_W, modal_w - 4);
    content = _modal_content(state, inner_w);
    title = spec.title;
    if not title {
        title = "Commands";
    }
    boxed = _frame_box(content, title, modal_w, inner_w);
    return _anchor_place(boxed, spec.anchor, modal_w, cols, rows, spec.offset_x, spec.offset_y);
}

def overlay_composite(
    base: list[str], modal_rows: list[str], cols: int, rows: int
) -> list[str] {
    out: list[str] = [];
    for i in range(rows) {
        base_line = base[i] if i < len(base) else "";
        modal_line = modal_rows[i] if i < len(modal_rows) else "";
        out.append(modal_line if modal_line else base_line);
    }
    return out;
}
