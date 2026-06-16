"""Project Event objects into wrapped DisplayRows for the transcript panel.

This is the single event-to-display seam: build_rows() turns events + width into
the cached display_rows the renderer consumes. Wrapping uses only separate while
loops (never the nested-for-reassigning-locals shape that segfaults in NA
codegen) and is append-only.
"""

import from .state { Event, DisplayRow, TuiState }

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

"""Project one event into wrapped rows: split on explicit newlines, then wrap
each logical line. Continuation rows are indented under the gutter."""
def wrap_event(ev: Event, width: int, out: list[DisplayRow]) {
    pre = event_prefix(ev);
    cont = "    ";
    body = event_text(ev);
    parts = body.split("\n");
    i: int = 0;
    np = len(parts);
    while i < np {
        _wrap_line(parts[i], width, pre, cont, ev.kind, out);
        i = i + 1;
    }
}

"""Rebuild state.display_rows from state.events at the current width.

Width matches the renderer's inner content width (term_cols - 4). Records the
width it built for in layout_cols and clears layout_dirty so render skips the
rebuild until text or width changes again.
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
        wrap_event(state.events[i], width, rows);
        i = i + 1;
    }
    state.display_rows = rows;
    state.layout_cols = state.term_cols;
    state.layout_dirty = False;
}
