import from .state { Event, DisplayRow, TuiState, EventKind, kind_style, RenderMode }
import from .markdown { md_render }
import from .tool_block { tool_call_rows, tool_result_rows }
import from .terminal_image { image_rows, image_fallback }

def event_text(ev: Event) -> str {
    kind = ev.kind;
    if kind == EventKind.PHASE {
        if len(ev.node) > 0 {
            return ev.node;
        }
    }
    return ev.text;
}

def _wrap_line(
    text: str,
    width: int,
    first_pre: str,
    cont_pre: str,
    kind: EventKind,
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

def wrap_event(ev: Event, width: int, out: list[DisplayRow]) {
    kind = ev.kind;
    style = kind_style(kind);
    body = event_text(ev);

    if style.mode == RenderMode.MARKDOWN {
        md_rows = md_render(body, width, style.r, style.g, style.b, style.attrs);
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

    if style.mode == RenderMode.TOOL_CALL {
        tool_call_rows(ev.node, body, width, out);
        return;
    }
    if style.mode == RenderMode.TOOL_RESULT {
        tool_result_rows(ev.node, body, width, out);
        return;
    }

    if style.mode == RenderMode.IMAGE {
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

    pre = style.prefix;
    cont = "    ";
    parts = body.split("\n");
    i: int = 0;
    np = len(parts);
    while i < np {
        _wrap_line(parts[i], width, pre, cont, kind, out);
        i = i + 1;
    }
}

def build_rows(state: TuiState) {
    width = state.term_cols - 4;
    if width < 20 {
        width = 20;
    }
    rows: list[DisplayRow] = [];
    i: int = 0;
    n = len(state.events);
    while i < n {
        if i > 0 {
            rows.append(DisplayRow(text="", kind=EventKind.SEP, is_continuation=False));
        }
        ev = state.events[i];

        if ev.cache_text_len == len(ev.text) and ev.cache_width == width {
            j: int = 0;
            nc = len(ev.cached_rows);
            while j < nc {
                rows.append(ev.cached_rows[j]);
                j = j + 1;
            }
        } else {
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
