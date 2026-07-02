import from .select_list { SelectList }

obj AcItem {
    has value: str = "",
        label: str = "",
        description: str = "";
}

obj AcState {
    has active: bool = False,
        kind: str = "",
        items: list[AcItem] = [],
        selected_idx: int = 0,
        prefix: str = "",
        query: str = "";

    def dismiss {
        self.active = False;
        self.kind = "";
        self.items = [];
        self.selected_idx = 0;
        self.prefix = "";
        self.query = "";
    }

    def nav_up {
        n = len(self.items);
        if n == 0 {
            return;
        }
        if self.selected_idx > 0 {
            self.selected_idx = self.selected_idx - 1;
        } else {
            self.selected_idx = n - 1;
        }
    }

    def nav_down {
        n = len(self.items);
        if n == 0 {
            return;
        }
        if self.selected_idx < n - 1 {
            self.selected_idx = self.selected_idx + 1;
        } else {
            self.selected_idx = 0;
        }
    }
}

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

    def get_text -> str {
        result: str = "";
        i: int = 0;
        n = len(self.lines);
        while i < n {
            if i > 0 {
                result = result + "\n";
            }
            result = result + self.lines[i];
            i = i + 1;
        }
        return result;
    }

    def clear {
        self.lines = [""];
        self.cursor_line = 0;
        self.cursor_col = 0;
        self.scroll_offset = 0;
        self.history_idx = -1;
    }
}

obj DisplayRow {
    has text: str = "",
        kind: str = "",
        is_continuation: bool = False,
        pre_styled: bool = False;
}

obj Event {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        node: str = "",
        cache_text_len: int = -1,
        cache_width: int = -1,
        cached_rows: list[DisplayRow] = [];
}

obj TuiState {
    has status: str = "idle",
        active: str = "",
        model_name: str = "",
        needs_key: bool = False,
        key_env: str = "",
        cwd: str = "",
        events: list[Event] = [],
        dirty: bool = True,
        editor: EditorState = EditorState(),
        viewport_top: int = 0,
        term_rows: int = 24,
        term_cols: int = 80,
        quit_flag: bool = False,
        render_fd: int = -1,
        ipc_fd: int = -1,
        display_rows: list[DisplayRow] = [],
        layout_cols: int = -1,
        layout_dirty: bool = True,
        follow_tail: bool = True,
        overlay_active: bool = False,
        overlay_kind: str = "palette",
        overlay_title: str = "",
        overlay_filter: str = "",
        overlay_full_redraw: bool = False,
        select_list: SelectList = SelectList(),
        files: list[str] = [],
        model_presets: list[str] = [],
        ac: AcState = AcState();

    def mark_layout_dirty {
        self.dirty = True;
        self.layout_dirty = True;
    }

    def reset_events {
        self.events = [];
        self.display_rows = [];
        self.mark_layout_dirty();
        self.follow_tail = True;
        self.viewport_top = 0;
        self.ac.dismiss();
    }

    def upsert_event(ev_id: int, kind: str, text: str, node_name: str) -> None {
        if kind == "user" and ev_id >= 0 {
            for ev in self.events {
                if ev.id == -1 and ev.kind == "user" and ev.text == text {
                    ev.id = ev_id;
                    if len(node_name) > 0 {
                        ev.node = node_name;
                    }
                    self.mark_layout_dirty();
                    return;
                }
            }
        }

        for ev in self.events {
            if ev.id == ev_id {
                ev.text = text;
                ev.kind = kind;
                if len(node_name) > 0 {
                    ev.node = node_name;
                }

                ev.cache_text_len = -1;
                self.mark_layout_dirty();
                return;
            }
        }
        new_ev = Event(id=ev_id, kind=kind, text=text, node=node_name);
        self.events.append(new_ev);
        n = len(self.events);
        if n > 2000 {
            self.events = self.events[n - 2000:];
        }
        self.mark_layout_dirty();
    }

    def append_to_event(ev_id: int, delta: str) -> None {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = ev.text + delta;
                self.mark_layout_dirty();
                return;
            }
        }
    }

    def scroll_up(n: int) {
        if self.viewport_top > n {
            self.viewport_top = self.viewport_top - n;
        } else {
            self.viewport_top = 0;
        }

        self.follow_tail = False;
        self.dirty = True;
    }

    def scroll_down(n: int) {
        self.viewport_top = self.viewport_top + n;
        self.dirty = True;
    }

    def scroll_to_bottom {
        self.follow_tail = True;
        self.dirty = True;
    }
}
