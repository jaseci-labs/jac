node AblePrompt(Prompt) {
    can on_insert with InsertText entry;
    can on_submit with Submit entry;
    can on_cancel with Cancel entry;
}


def _clamp(n: int, lo: int, hi: int) -> int;


def editor_has_selection(prompt: Prompt) -> bool;


def editor_clear_selection(prompt: Prompt);


def _delete_selection(prompt: Prompt);


def editor_insert(prompt: Prompt, text: str);


def editor_backspace(prompt: Prompt);


def editor_delete_forward(prompt: Prompt);


def editor_move_left(prompt: Prompt);


def editor_move_right(prompt: Prompt);


def editor_move_left_display(prompt: Prompt);


def editor_move_right_display(prompt: Prompt);


def editor_move_home(prompt: Prompt);


def editor_move_end(prompt: Prompt);


def editor_move_up(prompt: Prompt);


def editor_move_down(prompt: Prompt);


def editor_caret_display_col(prompt: Prompt) -> int;


def editor_history_prev(prompt: Prompt);


def editor_history_next(prompt: Prompt);


def editor_submit(prompt: Prompt) -> str;


def editor_set_selection(prompt: Prompt, anchor: int, end: int);

impl AblePrompt.on_insert with InsertText entry {
    editor_insert(self, visitor.text);
    visitor.handled = True;
}

impl AblePrompt.on_submit with Submit entry {
    text = editor_submit(self);
    visitor.effects.append(SendPrompt(text=text));
    visitor.default_prevented = True;
    visitor.handled = True;
}

impl AblePrompt.on_cancel with Cancel entry {
    self.draft = "";
    self.caret = 0;
    self.sel_anchor = -1;
    self.sel_end = -1;
    visitor.handled = True;
}


impl _clamp(n: int, lo: int, hi: int) -> int {
    if n < lo {
        return lo;
    }
    if n > hi {
        return hi;
    }
    return n;
}


impl editor_has_selection(prompt: Prompt) -> bool {
    return (
        prompt.sel_anchor >= 0
        and prompt.sel_end >= 0
        and prompt.sel_anchor != prompt.sel_end
    );
}


impl editor_clear_selection(prompt: Prompt) {
    prompt.sel_anchor = -1;
    prompt.sel_end = -1;
}


impl _delete_selection(prompt: Prompt) {
    if not editor_has_selection(prompt) {
        return;
    }
    a = min(prompt.sel_anchor, prompt.sel_end);
    b = max(prompt.sel_anchor, prompt.sel_end);
    prompt.draft = prompt.draft[:a] + prompt.draft[b:];
    prompt.caret = a;
    editor_clear_selection(prompt);
}


impl editor_insert(prompt: Prompt, text: str) {
    if not text {
        return;
    }
    if editor_has_selection(prompt) {
        _delete_selection(prompt);
    }
    i = _clamp(prompt.caret, 0, len(prompt.draft));
    prompt.draft = prompt.draft[:i] + text + prompt.draft[i:];
    prompt.caret = i + len(text);
    prompt.history_index = -1;
}


impl editor_backspace(prompt: Prompt) {
    if editor_has_selection(prompt) {
        _delete_selection(prompt);
        return;
    }
    if prompt.caret <= 0 {
        return;
    }
    i = prompt.caret;
    prompt.draft = prompt.draft[:i - 1] + prompt.draft[i:];
    prompt.caret = i - 1;
}


impl editor_delete_forward(prompt: Prompt) {
    if editor_has_selection(prompt) {
        _delete_selection(prompt);
        return;
    }
    if prompt.caret >= len(prompt.draft) {
        return;
    }
    i = prompt.caret;
    prompt.draft = prompt.draft[:i] + prompt.draft[i + 1:];
}


impl editor_move_left(prompt: Prompt) {
    editor_clear_selection(prompt);
    prompt.caret = _clamp(prompt.caret - 1, 0, len(prompt.draft));
}


impl editor_move_right(prompt: Prompt) {
    editor_clear_selection(prompt);
    prompt.caret = _clamp(prompt.caret + 1, 0, len(prompt.draft));
}


impl editor_move_left_display(prompt: Prompt) {
    editor_clear_selection(prompt);
    if prompt.caret <= 0 {
        return;
    }

    prompt.caret = prompt.caret - 1;
}


impl editor_move_right_display(prompt: Prompt) {
    editor_clear_selection(prompt);
    if prompt.caret >= len(prompt.draft) {
        return;
    }
    prompt.caret = prompt.caret + 1;
}


impl editor_move_home(prompt: Prompt) {
    editor_clear_selection(prompt);

    i = prompt.caret;
    while i > 0 and prompt.draft[i - 1] != "\n" {
        i -= 1;
    }
    prompt.caret = i;
}


impl editor_move_end(prompt: Prompt) {
    editor_clear_selection(prompt);
    i = prompt.caret;
    n = len(prompt.draft);
    while i < n and prompt.draft[i] != "\n" {
        i += 1;
    }
    prompt.caret = i;
}


impl editor_move_up(prompt: Prompt) {
    editor_clear_selection(prompt);

    line_start = prompt.caret;
    while line_start > 0 and prompt.draft[line_start - 1] != "\n" {
        line_start -= 1;
    }
    col = prompt.caret - line_start;
    if line_start == 0 {
        prompt.caret = 0;
        return;
    }
    prev_end = line_start - 1;
    prev_start = prev_end;
    while prev_start > 0 and prompt.draft[prev_start - 1] != "\n" {
        prev_start -= 1;
    }
    prev_len = prev_end - prev_start;
    prompt.caret = prev_start + min(col, prev_len);
}


impl editor_move_down(prompt: Prompt) {
    editor_clear_selection(prompt);
    line_start = prompt.caret;
    while line_start > 0 and prompt.draft[line_start - 1] != "\n" {
        line_start -= 1;
    }
    col = prompt.caret - line_start;
    n = len(prompt.draft);
    line_end = prompt.caret;
    while line_end < n and prompt.draft[line_end] != "\n" {
        line_end += 1;
    }
    if line_end >= n {
        prompt.caret = n;
        return;
    }
    next_start = line_end + 1;
    next_end = next_start;
    while next_end < n and prompt.draft[next_end] != "\n" {
        next_end += 1;
    }
    next_len = next_end - next_start;
    prompt.caret = next_start + min(col, next_len);
}


impl editor_caret_display_col(prompt: Prompt) -> int {
    line_start = prompt.caret;
    while line_start > 0 and prompt.draft[line_start - 1] != "\n" {
        line_start -= 1;
    }
    prefix = prompt.draft[line_start:prompt.caret];
    return display_width(prefix);
}


impl editor_history_prev(prompt: Prompt) {
    if not prompt.history {
        return;
    }
    if prompt.history_index < 0 {
        prompt.history_index = len(prompt.history) - 1;
    } elif prompt.history_index > 0 {
        prompt.history_index -= 1;
    }
    prompt.draft = prompt.history[prompt.history_index];
    prompt.caret = len(prompt.draft);
    editor_clear_selection(prompt);
}


impl editor_history_next(prompt: Prompt) {
    if prompt.history_index < 0 {
        return;
    }
    if prompt.history_index >= len(prompt.history) - 1 {
        prompt.history_index = -1;
        prompt.draft = "";
        prompt.caret = 0;
        editor_clear_selection(prompt);
        return;
    }
    prompt.history_index += 1;
    prompt.draft = prompt.history[prompt.history_index];
    prompt.caret = len(prompt.draft);
    editor_clear_selection(prompt);
}


impl editor_submit(prompt: Prompt) -> str {
    text = prompt.draft;
    if text {
        prompt.history = prompt.history + [text];
    }
    prompt.draft = "";
    prompt.caret = 0;
    prompt.history_index = -1;
    editor_clear_selection(prompt);
    return text;
}


impl editor_set_selection(prompt: Prompt, anchor: int, end: int) {
    n = len(prompt.draft);
    prompt.sel_anchor = _clamp(anchor, 0, n);
    prompt.sel_end = _clamp(end, 0, n);
    prompt.caret = prompt.sel_end;
}
