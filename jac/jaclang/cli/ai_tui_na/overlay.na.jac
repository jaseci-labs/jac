"""Modal overlay: command palette, model picker, and @file picker.

Overlay state is the overlay_* scalar quintet on TuiState plus the shared
select list. This module owns opening/closing that state, routing keys
while a modal is up, and painting the boxed modal as a full-screen row
list. Compositing contract: a modal row of "" is transparent —
overlay_composite keeps the base frame line there.
"""

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

# --- layout constants ---

glob _LIST_ROWS: int = 8,
     _LIST_ROWS_SMALL: int = 5,
     _SMALL_TERM_ROWS: int = 20;
glob _MODAL_MAX_W: int = 64,
     _MODAL_COMFORT_W: int = 24,
     _MODAL_MIN_W: int = 16,
     _MODAL_INNER_MIN_W: int = 8;

# --- open / close ---

"""True while a modal overlay is consuming key input."""
def overlay_is_active(state: TuiState) -> bool {
    return state.overlay_active;
}

"""Populate the shared select list and flip the overlay state on."""
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
    sl.max_visible = _LIST_ROWS_SMALL if state.term_rows < _SMALL_TERM_ROWS else _LIST_ROWS;
    state.overlay_kind = kind;
    state.overlay_filter = initial_filter;
    state.overlay_title = title;
    state.overlay_active = True;
    state.overlay_full_redraw = True;
    state.dirty = True;
}

"""Open the command palette, optionally pre-seeded with a filter string."""
def overlay_open_palette(state: TuiState, initial_filter: str) {
    _overlay_show(
        state, OverlayKind.PALETTE, "Commands", palette_commands(state), initial_filter
    );
}

"""Open the model picker."""
def overlay_open_model(state: TuiState) {
    _overlay_show(state, OverlayKind.MODEL, "Select model", model_items(state), "");
}

"""Open the @file insert picker."""
def overlay_open_file(state: TuiState) {
    _overlay_show(state, OverlayKind.FILE, "Insert file", file_items(state), "");
}

"""Dismiss the overlay and reset its state scalars to their defaults."""
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

# --- key routing ---

"""Route a key to the active modal; returns True only when the app should quit.

CANCEL closes, CHANGED syncs the filter text, SELECT dispatches by overlay
kind: model apply, @file insert into the editor, or palette command — which
may chain into the model/file pickers instead of closing.
"""
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

# --- rendering ---

"""Pick the modal box width: cap at _MODAL_MAX_W, and if the capped width
falls below the comfortable minimum, widen to near-full-screen instead
(never below _MODAL_MIN_W)."""
def _modal_width(cols: int) -> int {
    w = min(cols - 4, _MODAL_MAX_W);
    if w < _MODAL_COMFORT_W {
        w = max(cols - 2, _MODAL_MIN_W);
    }
    return w;
}

"""Select-list rows plus an optional dim 'filter: ...' header, inner_w wide."""
def _modal_content(state: TuiState, inner_w: int) -> list[str] {
    content = state.select_list.render(inner_w);
    if not state.overlay_filter {
        return content;
    }
    filt = ansi_trunc(f"filter: {state.overlay_filter}", inner_w);
    header = ansi_pad(TH_SGR_BORDER_DIM + filt + ansi_reset(), inner_w);
    return [header] + content;
}

"""Wrap content rows in a box-drawing frame with a styled title bar.
Rows come back modal_w wide (concat assembly on purpose: ANSI rows can
outgrow the f-string buffer)."""
def _frame_box(content: list[str], title: str, modal_w: int, inner_w: int) -> list[str] {
    title_disp = ansi_trunc(title, max(1, inner_w - 2));
    top_fill = max(0, inner_w - visible_width(title_disp));
    border = TH_SGR_BORDER;
    reset = ansi_reset();

    top = (
        border + "┌─ " + TH_SGR_TITLE + title_disp + border
        + term_dashes(top_fill) + "┐" + reset
    );
    boxed: list[str] = [ansi_pad(top, modal_w)];
    for line in content {
        row = border + "│ " + line;
        boxed.append(ansi_pad(row, modal_w - 1) + border + "│" + reset);
    }
    boxed.append(border + "└" + term_dashes(modal_w - 2) + "┘" + reset);
    return boxed;
}

"""Center boxed rows on a cols x rows screen; rows outside the modal are ""
(transparent to overlay_composite)."""
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

"""Render the active overlay as a fresh full-screen row list (rows entries)."""
def overlay_build_modal(state: TuiState, cols: int, rows: int) -> list[str] {
    modal_w = _modal_width(cols);
    inner_w = max(_MODAL_INNER_MIN_W, modal_w - 4);
    content = _modal_content(state, inner_w);
    title = state.overlay_title if state.overlay_title else "Commands";
    boxed = _frame_box(content, title, modal_w, inner_w);
    return _center_rows(boxed, modal_w, cols, rows);
}

"""Merge modal rows over the base frame; empty modal rows are transparent."""
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
