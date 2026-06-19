"""TUI state: one Event per agent bus emit, one TuiState for the whole session."""

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

"""One wrapped transcript line: composed text plus the source event's kind so the
renderer can derive its color/attr without reaching back into `events`.
pre_styled: text already contains ANSI SGR codes and is padded to inner_w;
the renderer skips _kind_sgr and emits the text directly."""
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
        # Per-event render cache: skip md_render for events whose text and
        # terminal width haven't changed since the last build_rows call.
        # cache_text_len = -1 means "not cached" (initial / after text change).
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
        # Top visible DISPLAY-ROW index (not an event index).
        viewport_top: int = 0,
        term_rows: int = 24,
        term_cols: int = 80,
        quit_flag: bool = False,
        # Command sink fd. >= 0: write commands to this pipe fd (subprocess
        # transport). -1: enqueue into the in-process CmdQueue (ipc.na.jac),
        # drained by the sv host. Set by tui_setup (tui_core.na.jac).
        ipc_fd: int = -1,
        # Derived layout cache: display_rows is rebuilt from events+width by
        # build_rows() whenever layout_dirty is set or layout_cols drifts from
        # term_cols. follow_tail pins the viewport to the last row (streaming).
        display_rows: list[DisplayRow] = [],
        layout_cols: int = -1,
        layout_dirty: bool = True,
        follow_tail: bool = True,
        # Overlay stack (phase 6): command palette / model / file pickers via
        # SelectList. overlay_kind selects the on-select behavior in overlay.na.jac
        # ("palette" | "model" | "file").
        overlay_active: bool = False,
        overlay_kind: str = "palette",
        overlay_title: str = "",
        overlay_filter: str = "",
        overlay_full_redraw: bool = False,
        select_list: SelectList = SelectList(),
        # Project file list, read once at startup from JAC_AI_UI_FILES; the file
        # picker filters this cache.
        files: list[str] = [],
        # Quick-pick model names from JAC_AI_UI_MODEL_PRESETS (control plane
        # copies ai_agent._MODEL_PRESETS); the model picker filters this cache.
        model_presets: list[str] = [],
        # Inline autocomplete state (phase 7). Managed by autocomplete.na.jac.
        ac: AcState = AcState();

    # A transcript/layout change is always a visible change, so it must both
    # rebuild the display-row cache (layout_dirty, consumed by build_rows) AND
    # repaint (dirty, the render gate). Funnelling both through one method keeps
    # them in lockstep: a mutator can never mark the layout stale without also
    # asking for a paint, which is the bug class this invariant removes.
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
        # Special case: if backend sends the user message we added locally with ID -1,
        # replace it with the real backend-assigned ID instead of creating a duplicate
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
                # Text replaced entirely — invalidate render cache.
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

    # Append delta text to an existing streaming event (EVA IPC line). Avoids
    # shipping the full accumulated body on every token; ipc.na.jac calls this.
    def append_to_event(ev_id: int, delta: str) -> None {
        for ev in self.events {
            if ev.id == ev_id {
                ev.text = ev.text + delta;
                self.mark_layout_dirty();
                return;
            }
        }
    }

    # Scrolling operates on display-row indices; clamping against the live
    # transcript height happens in render (which knows the visible height).
    def scroll_up(n: int) {
        if self.viewport_top > n {
            self.viewport_top = self.viewport_top - n;
        } else {
            self.viewport_top = 0;
        }
        # Detaching from the bottom: stop auto-following new rows.
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
