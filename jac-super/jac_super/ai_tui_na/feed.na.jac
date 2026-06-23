"""Project Event objects into wrapped DisplayRows for the transcript panel.

This is the single event-to-display seam: build_rows() turns events + width into
the cached display_rows the renderer consumes. Wrapping uses only separate while
loops (never the nested-for-reassigning-locals shape that segfaults in NA
codegen) and is append-only.
"""

import from .state { Event, DisplayRow, TuiState }
import from .markdown { md_render }
import from .tool_block { tool_call_rows, tool_result_rows }
import from .terminal_image { image_rows, image_fallback }

def event_prefix(ev: Event) -> str {
    kind = ev.kind;
    if kind == "user" {
        return "> ";
    }
    if kind == "answer" {
        return "  ";
    }
    if kind == "reasoning" {
        return "~ ";
    }
    if kind == "system" {
        return "* ";
    }
    if kind == "logo" {
        return "";
    }
    if kind == "error" {
        return "! ";
    }
    if kind == "phase" {
        return "> ";
    }
    if kind == "call" {
        return "# ";
    }
    if kind == "tool_result" {
        return "  | ";
    }
    if kind == "img" {
        return "  ";
    }
    return "  ";
}

def event_text(ev: Event) -> str {
    kind = ev.kind;
    if kind == "phase" {
        if len(ev.node) > 0 {
            return ev.node;
        }
    }
    return ev.text;
}

"""Wrap one newline-free logical line to `width`, emitting DisplayRows.

The first row carries `first_pre`; every wrapped continuation carries
`cont_pre`. A single while loop slices the text in fixed chunks (hard character
wrap), so there is no nested control flow to trip the NA codegen bug.
"""
def _wrap_line(
    text: str,
    width: int,
    first_pre: str,
    cont_pre: str,
    kind: str,
    out: list[DisplayRow]
) -> None {
    af = width - len(first_pre);
    if af < 1 {
        af = 1;
    }
    ac = width - len(cont_pre);
    if ac < 1 {
        ac = 1;
    }
    n = len(text);
    if n == 0 {
        # Preserve blank lines as an empty (prefixed) row.
        out.append(DisplayRow(text=first_pre, kind=kind, is_continuation=False));
        return;
    }
    pos: int = 0;
    first: bool = True;
    while pos < n {
        take = af;
        if not first {
            take = ac;
        }
        chunk = text[pos:pos + take];
        row_text = first_pre + chunk;
        if not first {
            row_text = cont_pre + chunk;
        }
        out.append(DisplayRow(text=row_text, kind=kind, is_continuation=not first));
        pos = pos + take;
        first = False;
    }
}

"""Project one event into wrapped rows.

answer and reasoning events are rendered as markdown (pre-styled ANSI rows).
All other events use plain prefix-wrap.
"""
def wrap_event(ev: Event, width: int, out: list[DisplayRow]) {
    kind = ev.kind;
    body = event_text(ev);

    # Markdown rendering for assistant answer and reasoning
    if kind == "answer" {
        md_rows = md_render(body, width, 220, 220, 220, 0);
        i: int = 0;
        n = len(md_rows);
        while i < n {
            out.append(
                DisplayRow(
                    text=md_rows[i], kind=kind, is_continuation=i > 0, pre_styled=True
                )
            );
            i = i + 1;
        }
        return;
    }
    if kind == "reasoning" {
        # attrs=6: dim(2)+italic(4)
        md_rows = md_render(body, width, 160, 160, 160, 6);
        i: int = 0;
        n = len(md_rows);
        while i < n {
            out.append(
                DisplayRow(
                    text=md_rows[i], kind=kind, is_continuation=i > 0, pre_styled=True
                )
            );
            i = i + 1;
        }
        return;
    }

    # ToolBlock rendering for tool call and result events (pi tool-execution.ts patterns)
    if kind == "call" {
        tool_call_rows(ev.node, body, width, out);
        return;
    }
    if kind == "tool_result" {
        tool_result_rows(ev.node, body, width, out);
        return;
    }

    # Image events: node = "mime:width_px:height_px", text = base64 data
    if kind == "img" {
        img_mime: str = "image/png";
        img_w: int = 0;
        img_h: int = 0;
        colon1 = ev.node.find(":");
        if colon1 >= 0 {
            img_mime = ev.node[:colon1];
            rest_node = ev.node[colon1 + 1:];
            colon2 = rest_node.find(":");
            if colon2 >= 0 {
                w_str = rest_node[:colon2];
                h_str = rest_node[colon2 + 1:];
                try {
                    img_w = int(w_str);
                } except Exception { }
                try {
                    img_h = int(h_str);
                } except Exception { }
            }
        }
        img_row_list = image_rows(body, img_mime, img_w, img_h, width);
        ni = len(img_row_list);
        ii: int = 0;
        while ii < ni {
            out.append(
                DisplayRow(
                    text=img_row_list[ii],
                    kind=kind,
                    is_continuation=ii > 0,
                    pre_styled=True
                )
            );
            ii = ii + 1;
        }
        return;
    }

    # Plain prefix-wrap for all other event kinds
    pre = event_prefix(ev);
    cont = "    ";
    parts = body.split("\n");
    i: int = 0;
    np = len(parts);
    while i < np {
        _wrap_line(parts[i], width, pre, cont, kind, out);
        i = i + 1;
    }
}

"""Rebuild state.display_rows from state.events at the current width.

Width matches the renderer's inner content width (term_cols - 4). Records the
width it built for in layout_cols and clears layout_dirty so render skips the
rebuild until text or width changes again.

Per-event render cache: events carry cache_text_len / cache_width / cached_rows
so that only the event(s) whose text actually changed are re-rendered. On a
streaming answer this means only the tail event is processed on each token —
O(1) per token instead of O(N × L) — eliminating the GC-pressure blowup.
"""
def build_rows(state: TuiState) {
    width = state.term_cols - 4;
    if width < 20 {
        width = 20;
    }
    rows: list[DisplayRow] = [];
    i: int = 0;
    n = len(state.events);
    while i < n {
        # Blank separator row between events for visual breathing room.
        if i > 0 {
            rows.append(DisplayRow(text="", kind="sep", is_continuation=False));
        }
        ev = state.events[i];
        # Cache hit: event text and terminal width unchanged — reuse stored rows.
        if ev.cache_text_len == len(ev.text) and ev.cache_width == width {
            j: int = 0;
            nc = len(ev.cached_rows);
            while j < nc {
                rows.append(ev.cached_rows[j]);
                j = j + 1;
            }
        } else {
            # Cache miss: render fresh, update the per-event cache.
            event_rows: list[DisplayRow] = [];
            wrap_event(ev, width, event_rows);
            ev.cache_text_len = len(ev.text);
            ev.cache_width = width;
            ev.cached_rows = event_rows;
            j: int = 0;
            nc = len(event_rows);
            while j < nc {
                rows.append(event_rows[j]);
                j = j + 1;
            }
        }
        i = i + 1;
    }
    state.display_rows = rows;
    state.layout_cols = state.term_cols;
    state.layout_dirty = False;
}
