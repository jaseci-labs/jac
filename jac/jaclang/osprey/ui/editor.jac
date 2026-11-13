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
