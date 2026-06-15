"""Convert Event objects to display rows for the transcript panel."""

import from .state { Event }

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

def event_color_open(ev: Event) -> str {
    kind = ev.kind;
    if kind == "user" {
        return "\033[1;37m";
    }
    if kind == "answer" {
        return "\033[0m";
    }
    if kind == "reasoning" {
        return "\033[2;37m";
    }
    if kind == "system" {
        return "\033[36m";
    }
    if kind == "error" {
        return "\033[31m";
    }
    if kind == "phase" {
        return "\033[33m";
    }
    if kind == "call" {
        return "\033[35m";
    }
    if kind == "tool_result" {
        return "\033[2;37m";
    }
    return "\033[0m";
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

def _trunc_line(s: str, width: int) -> str {
    if len(s) <= width {
        return s;
    }
    if width < 2 {
        return s[:width];
    }
    return s[:width - 1] + "~";
}

def events_to_rows(events: list[Event], term_cols: int) -> list[str] {
    rows: list[str] = [];
    max_w = term_cols - 4;
    if max_w < 20 {
        max_w = 20;
    }
    for ev in events {
        prefix = event_prefix(ev);
        color_open = event_color_open(ev);
        body = event_text(ev);
        # NA codegen bug: nested `for` loops that reassign locals in the old
        # word-wrap path segfault at runtime — one truncated row per event.
        flat = body.replace("\n", " ");
        line = prefix + flat;
        rows.append(f"{color_open}{_trunc_line(line, max_w)}\033[0m");
    }
    return rows;
}
