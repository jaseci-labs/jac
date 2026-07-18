import from .state { Event, DisplayRow, TuiState, EventKind, kind_style, RenderMode }
import from .markdown { md_render }
import from .tool_block { tool_call_rows, tool_result_rows }
import from .terminal_image { image_rows }
import from .util { parse_int_or, split_kv }

glob _FEED_MARGIN_COLS: int = 4,
     _MIN_FEED_WIDTH: int = 20,
     _DEFAULT_IMAGE_MIME: str = "image/png",
     _CONT_PREFIX: str = "    ";

def event_text(ev: Event) -> str {
    if ev.kind == EventKind.PHASE and ev.node {
        return ev.node;
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
    first_avail = max(1, width - len(first_pre));
    cont_avail = max(1, width - len(cont_pre));
    if not text {
        out.append(DisplayRow(text=first_pre, kind=kind, is_continuation=False));
        return;
    }
    n = len(text);
    pos: int = 0;
    first: bool = True;
    while pos < n {
        take = first_avail if first else cont_avail;
        chunk = text[pos:pos + take];
        prefix = first_pre if first else cont_pre;
        out.append(
            DisplayRow(text=prefix + chunk, kind=kind, is_continuation=not first)
        );
        pos += take;
        first = False;
    }
}

def _append_styled_rows(rows: list[str], kind: EventKind, out: list[DisplayRow]) {
    for i in range(len(rows)) {
        out.append(
            DisplayRow(text=rows[i], kind=kind, is_continuation=i > 0, pre_styled=True)
        );
    }
}

def _image_event_rows(
    meta: str, body: str, width: int, kind: EventKind, out: list[DisplayRow]
) {
    mime: str = _DEFAULT_IMAGE_MIME;
    img_w: int = 0;
    img_h: int = 0;
    if ":" in meta {
        (mime_part, dims) = split_kv(meta, ":");
        mime = mime_part;
        if ":" in dims {
            (w_str, h_str) = split_kv(dims, ":");
            img_w = parse_int_or(w_str, 0);
            img_h = parse_int_or(h_str, 0);
        }
    }
    _append_styled_rows(image_rows(body, mime, img_w, img_h, width), kind, out);
}

def wrap_event(ev: Event, width: int, out: list[DisplayRow]) {
    kind = ev.kind;
    style = kind_style(kind);
    body = event_text(ev);

    if style.mode == RenderMode.MARKDOWN {
        md_rows = md_render(body, width, style.color, style.attrs);
        _append_styled_rows(md_rows, kind, out);
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
        _image_event_rows(ev.node, body, width, kind, out);
        return;
    }

    for part in body.split("\n") {
        _wrap_line(part, width, style.prefix, _CONT_PREFIX, kind, out);
    }
}

def _refresh_row_cache(ev: Event, width: int) -> None {
    if ev.cache_text_len == len(ev.text) and ev.cache_width == width {
        return;
    }
    event_rows: list[DisplayRow] = [];
    wrap_event(ev, width, event_rows);
    ev.cache_text_len = len(ev.text);
    ev.cache_width = width;
    ev.cached_rows = event_rows;
}

def build_rows(state: TuiState) {
    width = max(_MIN_FEED_WIDTH, state.term_cols - _FEED_MARGIN_COLS);
    rows: list[DisplayRow] = [];
    for (i, ev) in enumerate(state.events) {
        if i > 0 {
            rows.append(DisplayRow(text="", kind=EventKind.SEP, is_continuation=False));
        }
        _refresh_row_cache(ev, width);
        rows.extend(ev.cached_rows);
    }
    state.display_rows = rows;
    state.layout_cols = state.term_cols;
    state.layout_dirty = False;
}
