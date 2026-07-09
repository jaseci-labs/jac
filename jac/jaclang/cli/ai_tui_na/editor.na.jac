"""Multiline input editor: EditorState and its editing, wrap-math, and history ops."""
import from .width { idiv }

glob HISTORY_MAX: int = 100;

# --- wrap math helpers ---

"""Visual (wrapped) line count of a logical line of line_len bytes at width."""
def _vl_count(line_len: int, width: int) -> int {
    if width <= 0 {
        return 1;
    }
    if line_len == 0 {
        return 1;
    }
    return idiv(line_len + width - 1, width);
}

"""Total visual lines occupied by lines[0:before_idx] at width."""
def _total_vlines_before(lines: list[str], before_idx: int, width: int) -> int {
    total: int = 0;
    for line in lines[:before_idx] {
        total += _vl_count(len(line), width);
    }
    return total;
}

"""Total visual lines occupied by all of lines at width."""
def _total_vlines(lines: list[str], width: int) -> int {
    return _total_vlines_before(lines, len(lines), width);
}

"""Multiline editor buffer: cursor, wrap-aware movement/scroll, and a
HISTORY_MAX-entry submit-history ring with draft save/restore."""
obj EditorState {
    has lines: list[str] = [""],
        cursor_line: int = 0,
        cursor_col: int = 0,
        scroll_offset: int = 0,
        history: list[str] = [],
        history_idx: int = -1,
        history_draft_lines: list[str] = [""],
        history_draft_line: int = 0,
        history_draft_col: int = 0;

    """Buffer contents as one newline-joined string."""
    def get_text -> str {
        return "\n".join(self.lines);
    }

    """Byte length of get_text() without building the joined string."""
    def text_len -> int {
        return sum(len(line) for line in self.lines) + max(0, len(self.lines) - 1);
    }

    """Reset to an empty buffer and leave history browsing."""
    def clear {
        self.lines = [""];
        self.cursor_line = 0;
        self.cursor_col = 0;
        self.scroll_offset = 0;
        self.history_idx = -1;
    }

    # --- wrap math ---

    """Global visual-line index of the cursor at width."""
    def _cursor_global_vl(width: int) -> int {
        before = _total_vlines_before(self.lines, self.cursor_line, width);
        return before + idiv(self.cursor_col, width);
    }

    """Keep the cursor's visual line within the max_rows viewport."""
    def update_scroll(width: int, max_rows: int) {
        if max_rows <= 0 {
            return;
        }
        gvl = self._cursor_global_vl(width);
        if gvl < self.scroll_offset {
            self.scroll_offset = gvl;
        }
        if gvl >= self.scroll_offset + max_rows {
            self.scroll_offset = gvl - max_rows + 1;
        }
        max_scroll = max(0, _total_vlines(self.lines, width) - max_rows);
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll));
    }

    """True when the cursor sits on the first visual line of the buffer."""
    def is_on_first_vline(width: int) -> bool {
        if self.cursor_line > 0 {
            return False;
        }
        if width <= 0 {
            return True;
        }
        return idiv(self.cursor_col, width) == 0;
    }

    """True when the cursor sits on the last visual line of the buffer."""
    def is_on_last_vline(width: int) -> bool {
        if self.cursor_line < len(self.lines) - 1 {
            return False;
        }
        if width <= 0 {
            return True;
        }
        last_len = len(self.lines[self.cursor_line]);
        last_vsubline = _vl_count(last_len, width) - 1;
        return idiv(self.cursor_col, width) >= last_vsubline;
    }

    # --- editing ---

    """Join lines[idx] and lines[idx + 1] into a single line at idx."""
    def _merge_with_next(idx: int) {
        merged = self.lines[idx] + self.lines[idx + 1];
        self.lines = self.lines[:idx] + [merged] + self.lines[idx + 2:];
    }

    """Merge the cursor line into the previous one, cursor at the join point."""
    def _merge_into_prev {
        prev_len = len(self.lines[self.cursor_line - 1]);
        self._merge_with_next(self.cursor_line - 1);
        self.cursor_line -= 1;
        self.cursor_col = prev_len;
    }

    """Insert one input byte at the cursor (byte-oriented, like all cursor math)."""
    def insert(ch: str) {
        self.insert_text(ch);
    }

    """Insert text at the cursor, advancing by its byte length."""
    def insert_text(text: str) {
        line = self.lines[self.cursor_line];
        self.lines[self.cursor_line] = line[:self.cursor_col] + text + line[self.cursor_col:];
        self.cursor_col += len(text);
    }

    """Delete the byte before the cursor, joining lines at column 0."""
    def backspace {
        if self.cursor_col > 0 {
            line = self.lines[self.cursor_line];
            self.lines[self.cursor_line] = line[:self.cursor_col - 1] + line[self.cursor_col:];
            self.cursor_col -= 1;
            return;
        }
        if self.cursor_line == 0 {
            return;
        }
        self._merge_into_prev();
    }

    """Delete the byte under the cursor, joining lines at line end."""
    def forward_delete {
        line = self.lines[self.cursor_line];
        if self.cursor_col < len(line) {
            self.lines[self.cursor_line] = line[:self.cursor_col] + line[self.cursor_col + 1:];
            return;
        }
        if self.cursor_line >= len(self.lines) - 1 {
            return;
        }
        self._merge_with_next(self.cursor_line);
    }

    """Split the current line at the cursor, moving to the new line's start."""
    def newline {
        line = self.lines[self.cursor_line];
        before = line[:self.cursor_col];
        after = line[self.cursor_col:];
        idx = self.cursor_line;
        self.lines = self.lines[:idx] + [before, after] + self.lines[idx + 1:];
        self.cursor_line += 1;
        self.cursor_col = 0;
    }

    """Delete cursor-to-end of line; at line end, join with the next line."""
    def delete_to_line_end {
        line = self.lines[self.cursor_line];
        if self.cursor_col < len(line) {
            self.lines[self.cursor_line] = line[:self.cursor_col];
            return;
        }
        if self.cursor_line >= len(self.lines) - 1 {
            return;
        }
        self._merge_with_next(self.cursor_line);
    }

    """Delete start of line-to-cursor; at column 0, join with the previous line."""
    def delete_to_line_start {
        if self.cursor_col > 0 {
            line = self.lines[self.cursor_line];
            self.lines[self.cursor_line] = line[self.cursor_col:];
            self.cursor_col = 0;
            return;
        }
        if self.cursor_line == 0 {
            return;
        }
        self._merge_into_prev();
    }

    """Delete from the previous word boundary to the cursor."""
    def delete_word_back {
        old_col = self.cursor_col;
        self.word_left();
        new_col = self.cursor_col;
        if new_col == old_col {
            return;
        }
        line = self.lines[self.cursor_line];
        self.lines[self.cursor_line] = line[:new_col] + line[old_col:];
    }

    # --- movement ---

    """Move one byte left, wrapping to the previous line's end."""
    def move_left {
        if self.cursor_col > 0 {
            self.cursor_col -= 1;
            return;
        }
        if self.cursor_line > 0 {
            self.cursor_line -= 1;
            self.cursor_col = len(self.lines[self.cursor_line]);
        }
    }

    """Move one byte right, wrapping to the next line's start."""
    def move_right {
        if self.cursor_col < len(self.lines[self.cursor_line]) {
            self.cursor_col += 1;
            return;
        }
        if self.cursor_line < len(self.lines) - 1 {
            self.cursor_line += 1;
            self.cursor_col = 0;
        }
    }

    """Move one visual line up, preserving the visual column where possible."""
    def move_up(width: int) {
        if width <= 0 {
            return;
        }
        cur_vsubline = idiv(self.cursor_col, width);
        cur_vcol = self.cursor_col % width;

        if cur_vsubline > 0 {
            new_col = (cur_vsubline - 1) * width + cur_vcol;
            self.cursor_col = min(new_col, len(self.lines[self.cursor_line]));
            return;
        }

        if self.cursor_line == 0 {
            return;
        }
        self.cursor_line -= 1;
        prev_len = len(self.lines[self.cursor_line]);
        last_vsubline = _vl_count(prev_len, width) - 1;
        self.cursor_col = min(last_vsubline * width + cur_vcol, prev_len);
    }

    """Move one visual line down, preserving the visual column where possible."""
    def move_down(width: int) {
        if width <= 0 {
            return;
        }
        cur_len = len(self.lines[self.cursor_line]);
        cur_vsubline = idiv(self.cursor_col, width);
        cur_vcol = self.cursor_col % width;

        if cur_vsubline < _vl_count(cur_len, width) - 1 {
            new_col = (cur_vsubline + 1) * width + cur_vcol;
            self.cursor_col = min(new_col, cur_len);
            return;
        }

        if self.cursor_line >= len(self.lines) - 1 {
            return;
        }
        self.cursor_line += 1;
        self.cursor_col = min(cur_vcol, len(self.lines[self.cursor_line]));
    }

    """Move to column 0 of the current logical line."""
    def move_line_start {
        self.cursor_col = 0;
    }

    """Move past the last byte of the current logical line."""
    def move_line_end {
        self.cursor_col = len(self.lines[self.cursor_line]);
    }

    """Move to the start of the previous space-delimited word (spaces only)."""
    def word_left {
        line = self.lines[self.cursor_line];
        col = self.cursor_col;
        while col > 0 and line[col - 1] == " " {
            col -= 1;
        }
        while col > 0 and line[col - 1] != " " {
            col -= 1;
        }
        self.cursor_col = col;
    }

    """Move past the end of the current space-delimited word (spaces only)."""
    def word_right {
        line = self.lines[self.cursor_line];
        col = self.cursor_col;
        llen = len(line);
        while col < llen and line[col] != " " {
            col += 1;
        }
        while col < llen and line[col] == " " {
            col += 1;
        }
        self.cursor_col = col;
    }

    # --- history ---

    """Replace the buffer with text, cursor at the end."""
    def _set_text(text: str) {
        if not text {
            self.lines = [""];
            self.cursor_line = 0;
            self.cursor_col = 0;
            return;
        }
        self.lines = text.split("\n");
        self.cursor_line = len(self.lines) - 1;
        self.cursor_col = len(self.lines[self.cursor_line]);
    }

    """Load history[history_idx] into the buffer, scrolled to the top."""
    def _show_history_entry {
        self._set_text(self.history[self.history_idx]);
        self.scroll_offset = 0;
    }

    """Step back to an older entry, saving the live draft on first step."""
    def _history_older -> bool {
        if self.history_idx == -1 {
            self.history_draft_lines = self.lines;
            self.history_draft_line = self.cursor_line;
            self.history_draft_col = self.cursor_col;
            self.history_idx = 0;
        } elif self.history_idx < len(self.history) - 1 {
            self.history_idx += 1;
        } else {
            return False;
        }
        self._show_history_entry();
        return True;
    }

    """Step forward to a newer entry, restoring the draft past the newest."""
    def _history_newer -> bool {
        if self.history_idx == -1 {
            return False;
        }
        if self.history_idx > 0 {
            self.history_idx -= 1;
            self._show_history_entry();
            return True;
        }
        self.lines = self.history_draft_lines;
        self.cursor_line = self.history_draft_line;
        self.cursor_col = self.history_draft_col;
        self.history_idx = -1;
        self.history_draft_lines = [""];
        self.scroll_offset = 0;
        return True;
    }

    """Step through submit history (direction < 0 = older); the in-progress
    draft is saved on first step back and restored when stepping past newest."""
    def nav_history(direction: int) -> bool {
        if not self.history {
            return False;
        }
        if direction < 0 {
            return self._history_older();
        }
        return self._history_newer();
    }

    """Prepend text to history (deduping an immediate repeat), capped at HISTORY_MAX."""
    def add_history(text: str) {
        trimmed = text.strip();
        if not trimmed {
            return;
        }
        if self.history and self.history[0] == trimmed {
            return;
        }
        keep = min(len(self.history), HISTORY_MAX - 1);
        self.history = [trimmed] + self.history[:keep];
    }

    """Take the buffer contents: record history, clear, and return the text."""
    def submit -> str {
        text = self.get_text().strip();
        if text {
            self.add_history(text);
        }
        self.clear();
        return text;
    }
}
