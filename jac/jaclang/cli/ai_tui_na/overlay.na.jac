import from .state { TuiState, OverlayKind }
import from .keys { Key }
import from .commands {
    palette_commands,
    model_items,
    file_items,
    command_dispatch,
    apply_model,
    CmdResult
}
import from .runtime { TuiRuntime }
import from .select_list { SelectItem, SelectAction }
import from .width { visible_width, ansi_trunc, ansi_pad }
import from .terminal { ansi_reset, term_spaces, term_dashes }
import from .theme { TH_SGR_BORDER, TH_SGR_BORDER_DIM, TH_SGR_TITLE }

glob _LIST_ROWS: int = 8,
     _LIST_ROWS_SMALL: int = 5,
     _SMALL_TERM_ROWS: int = 20;
glob _MODAL_MAX_W: int = 64,
     _MODAL_COMFORT_W: int = 24,
     _MODAL_MIN_W: int = 16,
     _MODAL_INNER_MIN_W: int = 8;

def overlay_is_active(state: TuiState) -> bool {
    return state.overlay_active;
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
    state.overlay_kind = kind;
    state.overlay_filter = initial_filter;
    state.overlay_title = title;
    state.overlay_active = True;
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
    if not state.overlay_active {
        return;
    }
    state.overlay_active = False;
    state.overlay_kind = OverlayKind.PALETTE;
    state.overlay_filter = "";
    state.overlay_title = "";
    state.overlay_full_redraw = True;
    state.dirty = True;
}

def overlay_handle_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    sl = state.select_list;
    action = sl.handle_key(k);
    if action == SelectAction.CANCEL {
        overlay_close(state);
        return False;
    }
    if action == SelectAction.CHANGED {
        state.overlay_filter = sl.filter_text;
        state.dirty = True;
        return False;
    }
    if action == SelectAction.SELECT {
        item = sl.current();
        if item is None {
            return False;
        }
        kind = state.overlay_kind;

        if kind == OverlayKind.MODEL {
            apply_model(item.value, rt);
            overlay_close(state);
            return False;
        }

        if kind == OverlayKind.FILE {
            state.editor.insert_text(f"@{item.value} ");
            overlay_close(state);
            return False;
        }

        result = command_dispatch(item.value, rt);
        if result == CmdResult.OPEN_MODEL {
            overlay_open_model(state);
            return False;
        }
        if result == CmdResult.OPEN_FILE {
            overlay_open_file(state);
            return False;
        }
        should_quit = result == CmdResult.QUIT;
        overlay_close(state);
        return should_quit;
    }
    return False;
}

def _modal_width(cols: int) -> int {
    w = min(cols - 4, _MODAL_MAX_W);
    if w < _MODAL_COMFORT_W {
        w = max(cols - 2, _MODAL_MIN_W);
    }
    return w;
}

def _modal_content(state: TuiState, inner_w: int) -> list[str] {
    content = state.select_list.render(inner_w);
    if not state.overlay_filter {
        return content;
    }
    filt = ansi_trunc(f"filter: {state.overlay_filter}", inner_w);
    header = ansi_pad(TH_SGR_BORDER_DIM + filt + ansi_reset(), inner_w);
    return [header] + content;
}

def _frame_box(
    content: list[str], title: str, modal_w: int, inner_w: int
) -> list[str] {
    title_disp = ansi_trunc(title, max(1, inner_w - 2));
    top_fill = max(0, inner_w - visible_width(title_disp));
    border = TH_SGR_BORDER;
    reset = ansi_reset();

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

def _center_rows(boxed: list[str], modal_w: int, cols: int, rows: int) -> list[str] {
    pad_left = term_spaces(max(0, (cols - modal_w) // 2));
    padded = [ansi_pad(pad_left + row, cols) for row in boxed];
    modal_h = len(padded);
    start_row = max(1, (rows - modal_h) // 2);

    placed: list[str] = [];
    for ri in range(rows) {
        if ri >= start_row and ri < start_row + modal_h {
            placed.append(padded[ri - start_row]);
        } else {
            placed.append("");
        }
    }
    return placed;
}

def overlay_build_modal(state: TuiState, cols: int, rows: int) -> list[str] {
    modal_w = _modal_width(cols);
    inner_w = max(_MODAL_INNER_MIN_W, modal_w - 4);
    content = _modal_content(state, inner_w);
    title = state.overlay_title if state.overlay_title else "Commands";
    boxed = _frame_box(content, title, modal_w, inner_w);
    return _center_rows(boxed, modal_w, cols, rows);
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
