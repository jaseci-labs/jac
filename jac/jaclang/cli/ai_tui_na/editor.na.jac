import from .state { EditorState }

def _idiv(a: int, b: int) -> int {
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

def _vl_count(line_len: int, width: int) -> int {
    if width <= 0 {
        return 1;
    }
    if line_len == 0 {
        return 1;
    }
    return _idiv(line_len + width - 1, width);
}

def _total_vlines_before(lines: list[str], before_idx: int, width: int) -> int {
    total: int = 0;
    i: int = 0;
    while i < before_idx {
        total = total + _vl_count(len(lines[i]), width);
        i = i + 1;
    }
    return total;
}

def _cursor_global_vl(ed: EditorState, width: int) -> int {
    before = _total_vlines_before(ed.lines, ed.cursor_line, width);
    return before + _idiv(ed.cursor_col, width);
}

def _total_vlines(lines: list[str], width: int) -> int {
    return _total_vlines_before(lines, len(lines), width);
}

def editor_update_scroll(ed: EditorState, width: int, max_rows: int) {
    if max_rows <= 0 {
        return;
    }
    gvl = _cursor_global_vl(ed, width);
    if gvl < ed.scroll_offset {
        ed.scroll_offset = gvl;
    }
    if gvl >= ed.scroll_offset + max_rows {
        ed.scroll_offset = gvl - max_rows + 1;
    }
    total = _total_vlines(ed.lines, width);
    max_scroll = total - max_rows;
    if max_scroll < 0 {
        max_scroll = 0;
    }
    if ed.scroll_offset > max_scroll {
        ed.scroll_offset = max_scroll;
    }
    if ed.scroll_offset < 0 {
        ed.scroll_offset = 0;
    }
}

def editor_is_on_first_vline(ed: EditorState, width: int) -> bool {
    if ed.cursor_line > 0 {
        return False;
    }
    if width <= 0 {
        return True;
    }
    return _idiv(ed.cursor_col, width) == 0;
}

def editor_is_on_last_vline(ed: EditorState, width: int) -> bool {
    n = len(ed.lines);
    if ed.cursor_line < n - 1 {
        return False;
    }
    last_line = ed.lines[ed.cursor_line];
    last_len = len(last_line);
    if width <= 0 {
        return True;
    }
    last_vsubline = _vl_count(last_len, width) - 1;
    cur_vsubline = _idiv(ed.cursor_col, width);
    return cur_vsubline >= last_vsubline;
}

def editor_get_text(ed: EditorState) -> str {
    return ed.get_text();
}

def editor_insert(ed: EditorState, ch: str) {
    line = ed.lines[ed.cursor_line];
    ed.lines[ed.cursor_line] = line[:ed.cursor_col] + ch + line[ed.cursor_col:];
    ed.cursor_col = ed.cursor_col + 1;
}

def editor_insert_text(ed: EditorState, text: str) {
    line = ed.lines[ed.cursor_line];
    ed.lines[ed.cursor_line] = line[:ed.cursor_col] + text + line[ed.cursor_col:];
    ed.cursor_col = ed.cursor_col + len(text);
}

def editor_backspace(ed: EditorState) {
    if ed.cursor_col > 0 {
        line = ed.lines[ed.cursor_line];
        ed.lines[ed.cursor_line] = line[:ed.cursor_col - 1] + line[ed.cursor_col:];
        ed.cursor_col = ed.cursor_col - 1;
        return;
    }

    if ed.cursor_line == 0 {
        return;
    }
    prev_line = ed.lines[ed.cursor_line - 1];
    cur_line = ed.lines[ed.cursor_line];
    merged = prev_line + cur_line;
    new_lines: list[str] = [];
    i: int = 0;
    n = len(ed.lines);
    while i < n {
        if i == ed.cursor_line - 1 {
            new_lines.append(merged);
        } elif i != ed.cursor_line {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
    ed.cursor_line = ed.cursor_line - 1;
    ed.cursor_col = len(prev_line);
}

def editor_forward_delete(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    if ed.cursor_col < len(line) {
        ed.lines[ed.cursor_line] = line[:ed.cursor_col] + line[ed.cursor_col + 1:];
        return;
    }

    n = len(ed.lines);
    if ed.cursor_line >= n - 1 {
        return;
    }
    cur_line = ed.lines[ed.cursor_line];
    next_line = ed.lines[ed.cursor_line + 1];
    merged = cur_line + next_line;
    new_lines: list[str] = [];
    i: int = 0;
    while i < n {
        if i == ed.cursor_line {
            new_lines.append(merged);
        } elif i != ed.cursor_line + 1 {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
}

def editor_newline(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    before = line[:ed.cursor_col];
    after = line[ed.cursor_col:];
    new_lines: list[str] = [];
    i: int = 0;
    n = len(ed.lines);
    while i < n {
        if i == ed.cursor_line {
            new_lines.append(before);
            new_lines.append(after);
        } else {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
    ed.cursor_line = ed.cursor_line + 1;
    ed.cursor_col = 0;
}

def editor_move_left(ed: EditorState) {
    if ed.cursor_col > 0 {
        ed.cursor_col = ed.cursor_col - 1;
        return;
    }
    if ed.cursor_line > 0 {
        ed.cursor_line = ed.cursor_line - 1;
        ed.cursor_col = len(ed.lines[ed.cursor_line]);
    }
}

def editor_move_right(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    if ed.cursor_col < len(line) {
        ed.cursor_col = ed.cursor_col + 1;
        return;
    }
    n = len(ed.lines);
    if ed.cursor_line < n - 1 {
        ed.cursor_line = ed.cursor_line + 1;
        ed.cursor_col = 0;
    }
}

def editor_move_up(ed: EditorState, width: int) {
    if width <= 0 {
        return;
    }
    cur_vsubline = _idiv(ed.cursor_col, width);
    cur_vcol = ed.cursor_col - cur_vsubline * width;

    if cur_vsubline > 0 {
        new_col = (cur_vsubline - 1) * width + cur_vcol;
        cur_line = ed.lines[ed.cursor_line];
        if new_col > len(cur_line) {
            new_col = len(cur_line);
        }
        ed.cursor_col = new_col;
        return;
    }

    if ed.cursor_line == 0 {
        return;
    }
    ed.cursor_line = ed.cursor_line - 1;
    prev_line = ed.lines[ed.cursor_line];
    prev_len = len(prev_line);

    last_vsubline = _vl_count(prev_len, width) - 1;
    new_col = last_vsubline * width + cur_vcol;
    if new_col > prev_len {
        new_col = prev_len;
    }
    ed.cursor_col = new_col;
}

def editor_move_down(ed: EditorState, width: int) {
    if width <= 0 {
        return;
    }
    cur_line = ed.lines[ed.cursor_line];
    cur_len = len(cur_line);
    cur_vsubline = _idiv(ed.cursor_col, width);
    cur_vcol = ed.cursor_col - cur_vsubline * width;
    total_vsublines = _vl_count(cur_len, width);

    if cur_vsubline < total_vsublines - 1 {
        new_col = (cur_vsubline + 1) * width + cur_vcol;
        if new_col > cur_len {
            new_col = cur_len;
        }
        ed.cursor_col = new_col;
        return;
    }

    n = len(ed.lines);
    if ed.cursor_line >= n - 1 {
        return;
    }
    ed.cursor_line = ed.cursor_line + 1;
    next_line = ed.lines[ed.cursor_line];
    next_len = len(next_line);
    new_col = cur_vcol;
    if new_col > next_len {
        new_col = next_len;
    }
    ed.cursor_col = new_col;
}

def editor_move_line_start(ed: EditorState) {
    ed.cursor_col = 0;
}

def editor_move_line_end(ed: EditorState) {
    ed.cursor_col = len(ed.lines[ed.cursor_line]);
}

def editor_delete_to_line_end(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    col = ed.cursor_col;
    if col < len(line) {
        ed.lines[ed.cursor_line] = line[:col];
        return;
    }

    n = len(ed.lines);
    if ed.cursor_line >= n - 1 {
        return;
    }
    next_line = ed.lines[ed.cursor_line + 1];
    merged = line + next_line;
    new_lines: list[str] = [];
    i: int = 0;
    while i < n {
        if i == ed.cursor_line {
            new_lines.append(merged);
        } elif i != ed.cursor_line + 1 {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
}

def editor_delete_to_line_start(ed: EditorState) {
    col = ed.cursor_col;
    if col > 0 {
        line = ed.lines[ed.cursor_line];
        ed.lines[ed.cursor_line] = line[col:];
        ed.cursor_col = 0;
        return;
    }

    if ed.cursor_line == 0 {
        return;
    }
    prev_line = ed.lines[ed.cursor_line - 1];
    cur_line = ed.lines[ed.cursor_line];
    merged = prev_line + cur_line;
    new_lines: list[str] = [];
    i: int = 0;
    n = len(ed.lines);
    while i < n {
        if i == ed.cursor_line - 1 {
            new_lines.append(merged);
        } elif i != ed.cursor_line {
            new_lines.append(ed.lines[i]);
        }
        i = i + 1;
    }
    ed.lines = new_lines;
    ed.cursor_line = ed.cursor_line - 1;
    ed.cursor_col = len(prev_line);
}

def editor_word_left(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    col = ed.cursor_col;

    while col > 0 and line[col - 1] == " " {
        col = col - 1;
    }

    while col > 0 and line[col - 1] != " " {
        col = col - 1;
    }
    ed.cursor_col = col;
}

def editor_word_right(ed: EditorState) {
    line = ed.lines[ed.cursor_line];
    col = ed.cursor_col;
    llen = len(line);

    while col < llen and line[col] != " " {
        col = col + 1;
    }

    while col < llen and line[col] == " " {
        col = col + 1;
    }
    ed.cursor_col = col;
}

def editor_delete_word_back(ed: EditorState) {
    old_col = ed.cursor_col;
    editor_word_left(ed);
    new_col = ed.cursor_col;
    if new_col == old_col {
        return;
    }
    line = ed.lines[ed.cursor_line];
    ed.lines[ed.cursor_line] = line[:new_col] + line[old_col:];
}

def _ed_set_text(ed: EditorState, text: str) {
    if len(text) == 0 {
        ed.lines = [""];
        ed.cursor_line = 0;
        ed.cursor_col = 0;
        return;
    }
    new_lines: list[str] = [];
    current: str = "";
    i: int = 0;
    n = len(text);
    while i < n {
        c = text[i];
        if c == "\n" {
            new_lines.append(current);
            current = "";
        } else {
            current = current + c;
        }
        i = i + 1;
    }
    new_lines.append(current);
    ed.lines = new_lines;
    ed.cursor_line = len(ed.lines) - 1;
    ed.cursor_col = len(ed.lines[ed.cursor_line]);
}

def editor_nav_history(ed: EditorState, direction: int) -> bool {
    hist_len = len(ed.history);
    if hist_len == 0 {
        return False;
    }

    if direction < 0 {
        if ed.history_idx == -1 {
            ed.history_draft_lines = ed.lines;
            ed.history_draft_line = ed.cursor_line;
            ed.history_draft_col = ed.cursor_col;
            ed.history_idx = 0;
        } elif ed.history_idx < hist_len - 1 {
            ed.history_idx = ed.history_idx + 1;
        } else {
            return False;
        }
        _ed_set_text(ed, ed.history[ed.history_idx]);
        ed.scroll_offset = 0;
        return True;
    }

    if ed.history_idx == -1 {
        return False;
    }
    if ed.history_idx > 0 {
        ed.history_idx = ed.history_idx - 1;
        _ed_set_text(ed, ed.history[ed.history_idx]);
        ed.scroll_offset = 0;
        return True;
    }

    ed.lines = ed.history_draft_lines;
    ed.cursor_line = ed.history_draft_line;
    ed.cursor_col = ed.history_draft_col;
    ed.history_idx = -1;
    ed.history_draft_lines = [""];
    ed.scroll_offset = 0;
    return True;
}

def editor_add_history(ed: EditorState, text: str) {
    trimmed = text.strip();
    if len(trimmed) == 0 {
        return;
    }

    if len(ed.history) > 0 and ed.history[0] == trimmed {
        return;
    }
    new_hist: list[str] = [trimmed];
    i: int = 0;
    n = len(ed.history);
    limit: int = 99;
    while i < n and i < limit {
        new_hist.append(ed.history[i]);
        i = i + 1;
    }
    ed.history = new_hist;
}

def editor_submit(ed: EditorState) -> str {
    text = ed.get_text().strip();
    if len(text) > 0 {
        editor_add_history(ed, text);
    }
    ed.clear();
    return text;
}
