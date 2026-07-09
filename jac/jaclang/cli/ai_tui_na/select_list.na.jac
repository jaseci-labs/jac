"""Filterable pick list driven by TUI overlays (command palette, model/file pickers).

SelectList owns the item set, an incrementally filtered view of it, and the
selection cursor. overlay.na.jac feeds keys through handle_key and interprets
the returned SelectAction: SELECT accepts current(), CANCEL dismisses the
overlay, CHANGED requests a redraw.
"""

import from .width { visible_width, ansi_trunc }
import from .terminal { ansi_reset, term_spaces }
import from .keys { Key, KeyKind }
import from .theme { TH_SGR_TITLE, TH_SGR_BORDER_DIM }

glob _TWO_COL_MIN_W: int = 40,
     _PRIMARY_COL_W: int = 24,
     _PRIMARY_COL_RESERVE: int = 16,
     _PRIMARY_COL_MIN_W: int = 8,
     _ROW_RIGHT_MARGIN: int = 2,
     _DESC_MIN_W: int = 10;

"""Verdict handle_key hands back to the overlay driver."""
enum SelectAction { NONE = 0, CHANGED = 1, SELECT = 2, CANCEL = 3, }

"""One selectable entry: value is what SELECT yields, label is what renders."""
obj SelectItem {
    has value: str = "",
        label: str = "",
        description: str = "";
}

"""Scrollable pick list with prefix/substring filtering and wrap-around cursor."""
obj SelectList {
    has items: list[SelectItem] = [],
        filtered: list[SelectItem] = [],
        selected: int = 0,
        max_visible: int = 8,
        filter_text: str = "";

    """Replace the item set and clear filter and cursor state."""
    def reset_items(items: list[SelectItem]) {
        self.items = items;
        self.filtered = items;
        self.selected = 0;
        self.filter_text = "";
    }

    """Label if present, else the raw value."""
    def _display_value(item: SelectItem) -> str {
        return item.label if item.label else item.value;
    }

    """True when prefix hits item's value or label (slash-stripped or plain
    prefix match first, then substring)."""
    def _matches(item: SelectItem, prefix: str) -> bool {
        if not prefix {
            return True;
        }
        val = item.value;
        if val.startswith("/") {
            rest = val[1:];
            if rest.startswith(prefix) {
                return True;
            }
        }
        if val.startswith(prefix) or item.label.startswith(prefix) {
            return True;
        }
        if prefix in val {
            return True;
        }
        return prefix in item.label;
    }

    """Refilter items against prefix and reset the cursor to the top."""
    def set_filter(prefix: str) {
        self.filter_text = prefix;
        self.filtered = [
            item for item in self.items if self._matches(item, prefix)
        ];
        self.selected = 0;
    }

    """Move the cursor up one row, wrapping to the bottom."""
    def move_up {
        n = len(self.filtered);
        if n == 0 {
            return;
        }
        self.selected = n - 1 if self.selected == 0 else self.selected - 1;
    }

    """Move the cursor down one row, wrapping to the top."""
    def move_down {
        n = len(self.filtered);
        if n == 0 {
            return;
        }
        self.selected = 0 if self.selected >= n - 1 else self.selected + 1;
    }

    """Item under the cursor, or None when the filtered view is empty."""
    def current -> SelectItem | None {
        if self.selected < 0 or self.selected >= len(self.filtered) {
            return None;
        }
        return self.filtered[self.selected];
    }

    """Two-column row (value column, gap, dimmed description); "" when the
    description column would be too narrow and the caller must fall back."""
    def _render_two_col(
        prefix: str,
        val: str,
        desc: str,
        is_selected: bool,
        inner_w: int
    ) -> str {
        primary_w = max(
            _PRIMARY_COL_MIN_W,
            min(_PRIMARY_COL_W, inner_w - _PRIMARY_COL_RESERVE)
        );
        val_disp = ansi_trunc(val, primary_w);
        val_w = visible_width(val_disp);
        gap = max(1, primary_w - val_w);
        desc_max = inner_w - visible_width(prefix) - val_w - gap
            - _ROW_RIGHT_MARGIN;
        if desc_max <= _DESC_MIN_W {
            return "";
        }
        desc_disp = ansi_trunc(desc, desc_max);
        sp = term_spaces(gap);
        if is_selected {
            return TH_SGR_TITLE + prefix + val_disp + sp + desc_disp
                + ansi_reset();
        }
        return prefix + val_disp + TH_SGR_BORDER_DIM + sp + desc_disp
            + ansi_reset();
    }

    """Render one row, preferring the two-column layout when it fits."""
    def _render_item(item: SelectItem, is_selected: bool, inner_w: int) -> str {
        prefix = "→ " if is_selected else "  ";
        val = self._display_value(item);
        if item.description and inner_w > _TWO_COL_MIN_W {
            row = self._render_two_col(
                prefix,
                val,
                item.description,
                is_selected,
                inner_w
            );
            if row {
                return row;
            }
        }
        max_val = max(1, inner_w - visible_width(prefix) - _ROW_RIGHT_MARGIN);
        line = prefix + ansi_trunc(val, max_val);
        if is_selected {
            return TH_SGR_TITLE + line + ansi_reset();
        }
        return line;
    }

    """Render the window of rows around the cursor as a fresh list, plus a
    dim "(n/m)" indicator row whenever some items are scrolled out of view."""
    def render(inner_w: int) -> list[str] {
        n = len(self.filtered);
        if n == 0 {
            return [TH_SGR_BORDER_DIM + "  No matches" + ansi_reset()];
        }
        mv = max(1, self.max_visible);
        start = max(0, self.selected - mv // 2);
        start = min(start, max(0, n - mv));
        end = min(start + mv, n);

        lines: list[str] = [];
        for idx in range(start, end) {
            is_sel = idx == self.selected;
            lines.append(self._render_item(self.filtered[idx], is_sel, inner_w));
        }
        if start > 0 or end < n {
            info = f"  ({self.selected + 1}/{n})";
            lines.append(TH_SGR_BORDER_DIM + ansi_trunc(info, inner_w) + ansi_reset());
        }
        return lines;
    }

    """Map a key to a SelectAction; CHAR and BACKSPACE edit the filter text."""
    def handle_key(k: Key) -> SelectAction {
        if k.kind == KeyKind.UP {
            self.move_up();
            return SelectAction.CHANGED;
        }
        if k.kind == KeyKind.DOWN {
            self.move_down();
            return SelectAction.CHANGED;
        }
        if k.kind == KeyKind.ENTER {
            return SelectAction.SELECT if self.filtered else SelectAction.NONE;
        }
        if k.kind == KeyKind.ESCAPE {
            return SelectAction.CANCEL;
        }
        if k.kind == KeyKind.CTRL {
            ch = chr(k.code);
            return SelectAction.CANCEL if ch in "cq" else SelectAction.NONE;
        }
        if k.kind == KeyKind.BACKSPACE {
            if not self.filter_text {
                return SelectAction.NONE;
            }
            trimmed = self.filter_text[:len(self.filter_text) - 1];
            self.set_filter(trimmed);
            return SelectAction.CHANGED;
        }
        if k.kind == KeyKind.CHAR {
            self.set_filter(self.filter_text + chr(k.code));
            return SelectAction.CHANGED;
        }
        return SelectAction.NONE;
    }
}
