# Reducer — sole normal mutator of application state (no terminal/embed I/O).

import from .state { TuiState, AcKind, OverlayKind }
import from .keys { Key, KeyKind }
import from .input_types {
    UiAction,
    UiActionKind,
    Effect,
    EffectKind,
    FocusTarget,
    effect_quit,
    effect_stop,
    effect_reset,
    effect_send,
    effect_render
}
import from .focus { effective_focus }
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file,
    overlay_close
}
import from .commands {
    slash_submit_effects,
    command_dispatch_effects,
    apply_model_effects,
    CmdResult
}
import from .select_list { SelectAction }

glob _EDITOR_CHROME_COLS: int = 6,
     _EDITOR_CHROME_ROWS: int = 6,
     _INPUT_EDITOR_MAX_ROWS: int = 10,
     _PAGE_CHROME_ROWS: int = 4,
     _MOUSE_SCROLL_LINES: int = 3,
     _MAX_INPUT_LEN: int = 4096;

obj ReduceResult {
    has effects: list[Effect] = [],
        quit: bool = False;
}

def _extend(res: ReduceResult, effects: list[Effect]) {
    for e in effects {
        res.effects.append(e);
        if e.kind == EffectKind.QUIT {
            res.quit = True;
        }
    }
}

def _editor_width(state: TuiState) -> int {
    return max(1, state.term_cols - _EDITOR_CHROME_COLS);
}

def _editor_max_rows(state: TuiState) -> int {
    return max(1, min(_INPUT_EDITOR_MAX_ROWS, state.term_rows - _EDITOR_CHROME_ROWS));
}

def _sync_editor_view(state: TuiState) {
    state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
    state.mark_layout_dirty();
}

def _pending_continuation(state: TuiState) -> bool {
    ed = state.editor;
    if not ed.lines {
        return False;
    }
    if ed.cursor_col <= 0 {
        return False;
    }
    cur_line = ed.lines[ed.cursor_line];
    return cur_line[ed.cursor_col - 1] == "\\";
}

def _handle_submit(state: TuiState, res: ReduceResult) {
    ed = state.editor;
    if _pending_continuation(state) {
        ed.backspace();
        ed.newline();
        state.mark_layout_dirty();
        return;
    }
    text = ed.get_text().strip();
    if not text {
        return;
    }
    (cmd_res, effects) = slash_submit_effects(text, state);
    if cmd_res == CmdResult.QUIT {
        ed.submit();
        _extend(res, effects);
        res.quit = True;
        return;
    }
    if cmd_res == CmdResult.OPEN_MODEL {
        ed.submit();
        overlay_open_model(state);
        return;
    }
    if cmd_res == CmdResult.OPEN_FILE {
        ed.submit();
        overlay_open_file(state);
        return;
    }
    if cmd_res == CmdResult.HANDLED {
        ed.submit();
        _extend(res, effects);
        return;
    }
    if state.status_blocks_prompt() {
        return;
    }
    state.pending_submission.active = True;
    state.pending_submission.text = text;
    res.effects.append(effect_send(text));
}

def _handle_global(state: TuiState, k: Key, res: ReduceResult) -> bool {
    if k.kind != KeyKind.CTRL {
        return False;
    }
    ch = chr(k.code);
    if ch == "c" or ch == "q" {
        res.quit = True;
        res.effects.append(effect_quit());
        return True;
    }
    if ch == "g" {
        res.effects.append(effect_stop());
        state.mark_layout_dirty();
        return True;
    }
    if ch == "r" {
        res.effects.append(effect_reset());
        state.reset_events();
        state.mark_layout_dirty();
        return True;
    }
    if ch == "o" {
        overlay_open_palette(state, "");
        return True;
    }
    return False;
}

def _handle_overlay_key(state: TuiState, k: Key, res: ReduceResult) {
    if not state.overlay_stack.is_active() {
        return;
    }
    sl = state.select_list;
    action = sl.handle_key(k);
    if action == SelectAction.CANCEL {
        overlay_close(state);
        return;
    }
    if action == SelectAction.CHANGED {
        state.dirty = True;
        return;
    }
    if action == SelectAction.SELECT {
        item = sl.current();
        if item is None {
            return;
        }
        kind = state.overlay_stack.active_spec().role;
        if kind == OverlayKind.MODEL {
            _extend(res, apply_model_effects(item.value, state));
            overlay_close(state);
            return;
        }
        if kind == OverlayKind.FILE {
            state.editor.insert_text(f"@{item.value} ");
            overlay_close(state);
            return;
        }
        (cmd_res, effects) = command_dispatch_effects(item.value, state);
        if cmd_res == CmdResult.OPEN_MODEL {
            overlay_open_model(state);
            return;
        }
        if cmd_res == CmdResult.OPEN_FILE {
            overlay_open_file(state);
            return;
        }
        _extend(res, effects);
        if cmd_res == CmdResult.QUIT {
            res.quit = True;
        }
        overlay_close(state);
    }
}

def _handle_ac_key(state: TuiState, k: Key, res: ReduceResult) {
    if k.kind == KeyKind.TAB {
        ac_apply(state);
        _sync_editor_view(state);
        return;
    }
    did_nav = True;
    if k.kind == KeyKind.ESCAPE {
        state.ac.dismiss();
    } elif k.kind == KeyKind.UP {
        state.ac.nav_up();
    } elif k.kind == KeyKind.DOWN {
        state.ac.nav_down();
    } else {
        did_nav = False;
    }
    if did_nav {
        state.mark_layout_dirty();
        return;
    }
    if k.kind == KeyKind.ENTER {
        ac_kind = state.ac.kind;
        ac_apply(state);
        state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
        if ac_kind == AcKind.SLASH {
            _handle_submit(state, res);
        }
        return;
    }
    state.ac.dismiss();
    _handle_edit_key(state, k, res);
}

def _handle_editor_ctrl(state: TuiState, k: Key) {
    ed = state.editor;
    ch = chr(k.code);
    did_edit = True;
    if ch == "a" {
        ed.move_line_start();
    } elif ch == "e" {
        ed.move_line_end();
    } elif ch == "k" {
        ed.delete_to_line_end();
    } elif ch == "u" {
        ed.delete_to_line_start();
    } elif ch == "w" {
        ed.delete_word_back();
    } else {
        did_edit = False;
    }
    if did_edit {
        _sync_editor_view(state);
    }
}

def _handle_movement(state: TuiState, k: Key) -> bool {
    ed = state.editor;
    ew = _editor_width(state);
    if k.kind == KeyKind.UP {
        if ed.is_on_first_vline(ew) {
            navigated = ed.nav_history(-1);
            if not navigated {
                ed.move_line_start();
            }
        } else {
            ed.move_up(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.DOWN {
        if ed.is_on_last_vline(ew) {
            navigated = ed.nav_history(1);
            if not navigated {
                ed.move_line_end();
            }
        } else {
            ed.move_down(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    moved = True;
    if k.kind == KeyKind.LEFT {
        ed.move_left();
    } elif k.kind == KeyKind.RIGHT {
        ed.move_right();
    } elif k.kind == KeyKind.HOME {
        ed.move_line_start();
    } elif k.kind == KeyKind.END {
        ed.move_line_end();
    } elif k.kind == KeyKind.WORD_LEFT {
        ed.word_left();
    } elif k.kind == KeyKind.WORD_RIGHT {
        ed.word_right();
    } else {
        moved = False;
    }
    if moved {
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.PAGE_UP {
        state.scroll_up(state.term_rows - _PAGE_CHROME_ROWS);
        return True;
    }
    if k.kind == KeyKind.PAGE_DOWN {
        state.scroll_down(state.term_rows - _PAGE_CHROME_ROWS);
        return True;
    }
    return False;
}

def _handle_edit_key(state: TuiState, k: Key, res: ReduceResult) {
    ed = state.editor;
    if k.kind == KeyKind.TAB {
        ed_text = ed.get_text();
        if ed_text.startswith("/") {
            overlay_open_palette(state, ed_text[1:]);
        }
        return;
    }
    if k.kind == KeyKind.SHIFT_ENTER {
        ed.newline();
        _sync_editor_view(state);
        return;
    }
    if k.kind == KeyKind.ENTER {
        _handle_submit(state, res);
        return;
    }
    if k.kind == KeyKind.BACKSPACE {
        ed.backspace();
        _sync_editor_view(state);
        ac_update(state);
        return;
    }
    if k.kind == KeyKind.MOUSE_SCROLL_UP {
        state.scroll_up(_MOUSE_SCROLL_LINES);
        return;
    }
    if k.kind == KeyKind.MOUSE_SCROLL_DOWN {
        state.scroll_down(_MOUSE_SCROLL_LINES);
        return;
    }
    if k.kind == KeyKind.DELETE {
        ed.forward_delete();
        _sync_editor_view(state);
        return;
    }
    if k.kind == KeyKind.CHAR {
        if ed.text_len() >= _MAX_INPUT_LEN {
            return;
        }
        ed.insert(chr(k.code));
        _sync_editor_view(state);
        ac_update(state);
    }
}

def _handle_transcript_key(state: TuiState, k: Key) {
    if k.kind == KeyKind.PAGE_UP {
        state.scroll_up(state.term_rows - _PAGE_CHROME_ROWS);
    } elif k.kind == KeyKind.PAGE_DOWN {
        state.scroll_down(state.term_rows - _PAGE_CHROME_ROWS);
    } elif k.kind == KeyKind.MOUSE_SCROLL_UP {
        state.scroll_up(_MOUSE_SCROLL_LINES);
    } elif k.kind == KeyKind.MOUSE_SCROLL_DOWN {
        state.scroll_down(_MOUSE_SCROLL_LINES);
    }
}

def reduce_input(model: TuiState, action: UiAction) -> ReduceResult {
    res = ReduceResult();
    if action.kind == UiActionKind.SET_FOCUS {
        model.set_focus(action.focus);
        return res;
    }
    if action.kind != UiActionKind.KEY {
        return res;
    }
    k = action.key;
    if k.kind == KeyKind.UNKNOWN {
        return res;
    }
    if _handle_global(model, k, res) {
        return res;
    }
    f = effective_focus(model);
    if f == FocusTarget.OVERLAY {
        _handle_overlay_key(model, k, res);
        return res;
    }
    if f == FocusTarget.AUTOCOMPLETE {
        _handle_ac_key(model, k, res);
        return res;
    }
    if f == FocusTarget.TRANSCRIPT {
        _handle_transcript_key(model, k);
        return res;
    }
    if k.kind == KeyKind.CTRL {
        _handle_editor_ctrl(model, k);
        return res;
    }
    if _handle_movement(model, k) {
        return res;
    }
    _handle_edit_key(model, k, res);
    return res;
}

def reduce_session(model: TuiState, dirty: bool) -> ReduceResult {
    res = ReduceResult();
    if dirty {
        model.dirty = True;
        res.effects.append(effect_render());
    }
    return res;
}
