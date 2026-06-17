"""Pi-style SelectList: filtered picker with keyboard navigation.

SelectList.render(inner_w) returns content lines (no outer border).
handle_key(key) returns: "none", "changed", "select", or "cancel".
"""

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

obj SelectItem {
    has value: str = "",
        label: str = "",
        description: str = "";
}

obj SelectList {
    has items: list[SelectItem] = [],
        filtered: list[SelectItem] = [],
        selected: int = 0,
        max_visible: int = 8,
        filter_text: str = "";

    def reset_items(items: list[SelectItem]) {
        self.items = items;
        self.filtered = items;
        self.selected = 0;
        self.filter_text = "";
    }

    def _display_value(item: SelectItem) -> str {
        if len(item.label) > 0 {
            return item.label;
        }
        return item.value;
    }

    def _matches(item: SelectItem, prefix: str) -> bool {
        if len(prefix) == 0 {
            return True;
        }
        val = item.value;
        if val.startswith("/") {
            rest = val[1:];
            if rest.startswith(prefix) {
                return True;
            }
        }
        if val.startswith(prefix) {
            return True;
        }
        lbl = item.label;
        if lbl.startswith(prefix) {
            return True;
        }
        # Substring match: model names ("anthropic/claude-opus") and file paths
        # ("src/foo.jac") are best filtered by any contained run, not just prefix.
        if val.find(prefix) >= 0 {
            return True;
        }
        if lbl.find(prefix) >= 0 {
            return True;
        }
        return False;
    }

    def set_filter(prefix: str) {
        self.filter_text = prefix;
        next_filtered: list[SelectItem] = [];
        i: int = 0;
        n = len(self.items);
        while i < n {
            item = self.items[i];
            if self._matches(item, prefix) {
                next_filtered.append(item);
            }
            i = i + 1;
        }
        self.filtered = next_filtered;
        self.selected = 0;
    }

    def move_up {
        n = len(self.filtered);
        if n == 0 {
            return;
        }
        if self.selected == 0 {
            self.selected = n - 1;
        } else {
            self.selected = self.selected - 1;
        }
    }

    def move_down {
        n = len(self.filtered);
        if n == 0 {
            return;
        }
        if self.selected >= n - 1 {
            self.selected = 0;
        } else {
            self.selected = self.selected + 1;
        }
    }

    def current -> SelectItem | None {
        n = len(self.filtered);
        if n == 0 {
            return None;
        }
        if self.selected < 0 or self.selected >= n {
            return None;
        }
        return self.filtered[self.selected];
    }

    def _render_item(item: SelectItem, is_selected: bool, inner_w: int) -> str {
        prefix: str = "  ";
        if is_selected {
            prefix = "→ ";
        }
        prefix_w = visible_width(prefix);
        desc = item.description;
        desc_len = len(desc);
        val = self._display_value(item);

        if desc_len > 0 and inner_w > 40 {
            primary_w: int = 24;
            if primary_w > inner_w - 16 {
                primary_w = inner_w - 16;
            }
            if primary_w < 8 {
                primary_w = 8;
            }
            val_disp = ansi_trunc(val, primary_w);
            val_w = visible_width(val_disp);
            gap = primary_w - val_w;
            if gap < 1 {
                gap = 1;
            }
            sp: str = "";
            gi: int = 0;
            while gi < gap {
                sp = sp + " ";
                gi = gi + 1;
            }
            desc_max = inner_w - prefix_w - val_w - gap - 2;
            if desc_max > 10 {
                desc_disp = ansi_trunc(desc, desc_max);
                line = prefix + val_disp + sp + desc_disp;
                if is_selected {
                    return ansi_sgr(
                        TH_TITLE_R,
                        TH_TITLE_G,
                        TH_TITLE_B,
                        TH_BG_R,
                        TH_BG_G,
                        TH_BG_B,
                        TH_BOLD
                    ) + line + ansi_reset();
                }
                return prefix + val_disp + ansi_sgr(
                    TH_BORDER_R,
                    TH_BORDER_G,
                    TH_BORDER_B,
                    TH_BG_R,
                    TH_BG_G,
                    TH_BG_B,
                    TH_DIM
                ) + sp + desc_disp + ansi_reset();
            }
        }

        max_val = inner_w - prefix_w - 2;
        if max_val < 1 {
            max_val = 1;
        }
        val_disp = ansi_trunc(val, max_val);
        line = prefix + val_disp;
        if is_selected {
            return ansi_sgr(
                TH_TITLE_R, TH_TITLE_G, TH_TITLE_B, TH_BG_R, TH_BG_G, TH_BG_B, TH_BOLD
            ) + line + ansi_reset();
        }
        return line;
    }

    def render(inner_w: int) -> list[str] {
        lines: list[str] = [];
        n = len(self.filtered);
        if n == 0 {
            msg = "  No matches";
            lines.append(
                ansi_sgr(
                    TH_BORDER_R,
                    TH_BORDER_G,
                    TH_BORDER_B,
                    TH_BG_R,
                    TH_BG_G,
                    TH_BG_B,
                    TH_DIM
                ) + msg + ansi_reset()
            );
            return lines;
        }

        mv = self.max_visible;
        if mv < 1 {
            mv = 1;
        }
        start: int = self.selected - mv // 2;
        if start < 0 {
            start = 0;
        }
        max_start = n - mv;
        if max_start < 0 {
            max_start = 0;
        }
        if start > max_start {
            start = max_start;
        }
        end = start + mv;
        if end > n {
            end = n;
        }

        idx = start;
        while idx < end {
            item = self.filtered[idx];
            is_sel: bool = False;
            if idx == self.selected {
                is_sel = True;
            }
            lines.append(self._render_item(item, is_sel, inner_w));
            idx = idx + 1;
        }

        if start > 0 or end < n {
            info = f"  ({self.selected + 1}/{n})";
            info = ansi_trunc(info, inner_w);
            lines.append(
                ansi_sgr(
                    TH_BORDER_R,
                    TH_BORDER_G,
                    TH_BORDER_B,
                    TH_BG_R,
                    TH_BG_G,
                    TH_BG_B,
                    TH_DIM
                ) + info + ansi_reset()
            );
        }
        return lines;
    }

    def handle_key(key: str) -> str {
        if len(key) == 0 {
            return "none";
        }
        first = key[0];
        code = ord(first);

        if code == 27 and len(key) > 1 {
            if key == "\033[A" or key == "\033OA" {
                self.move_up();
                return "changed";
            }
            if key == "\033[B" or key == "\033OB" {
                self.move_down();
                return "changed";
            }
            return "none";
        }

        if code == 13 or code == 10 {
            if len(self.filtered) > 0 {
                return "select";
            }
            return "none";
        }

        if code == 27 and len(key) == 1 {
            return "cancel";
        }
        if code == 3 or code == 17 {
            return "cancel";
        }

        if code == 127 or code == 8 {
            if len(self.filter_text) > 0 {
                self.filter_text = self.filter_text[:len(self.filter_text) - 1];
                self.set_filter(self.filter_text);
                return "changed";
            }
            return "none";
        }

        if code >= 32 and code <= 126 and len(key) == 1 {
            self.filter_text = self.filter_text + first;
            self.set_filter(self.filter_text);
            return "changed";
        }

        return "none";
    }
}
