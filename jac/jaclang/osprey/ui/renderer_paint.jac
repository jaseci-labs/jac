def _blank_buffer(columns: int, rows: int) -> CellBuffer;


def _paint_text_into(
    buf: CellBuffer,
    text: str,
    row: int,
    col: int,
    max_width: int,
    attrs: StyleAttrs | None = None,
);


def _paint_entry_lines(
    buf: CellBuffer,
    layout_entry: FrameEntry,
    scrolls: bool,
    rows: list[list[TextSpan]] | None = None,
    fill: StyleAttrs | None = None,
);


def _with_fill(span: TextSpan, fill: StyleAttrs) -> TextSpan;


def _overlay_z_key(hit: _OverlayHit) -> int;


def _overlay_jid_key(hit: _OverlayHit) -> str;


def _layered_overlays(layout_root: UiNode) -> list[UiNode];


def _paint_node(
    state: LayoutState, n: UiNode, buf: CellBuffer, rend: Renderer | None = None
);


def _paint_tree(
    state: LayoutState, n: UiNode, buf: CellBuffer, rend: Renderer | None = None
);


def _paint_frame_buffer(renderer: Renderer, layout_root: UiNode) -> CellBuffer;

impl _blank_buffer(columns: int, rows: int) -> CellBuffer {
    return create_buffer(columns, rows);
}


impl _paint_text_into(
    buf: CellBuffer,
    text: str,
    row: int,
    col: int,
    max_width: int,
    attrs: StyleAttrs | None = None,
) {
    if max_width <= 0 {
        return;
    }
    buffer_blit_text(buf, row, col, text, attrs, max_width);
}


impl _paint_entry_lines(
    buf: CellBuffer,
    layout_entry: FrameEntry,
    scrolls: bool,
    rows: list[list[TextSpan]] | None = None,
    fill: StyleAttrs | None = None,
) {
    rect = layout_entry.rect;
    clip = layout_entry.clip if not layout_entry.clip.is_empty() else rect;
    if clip.is_empty() or rect.is_empty() {
        return;
    }
    lines = layout_entry.wrapped_lines;
    scroll = 0;
    if scrolls {
        scroll = layout_entry.scroll_offset;
    }
    for vis_i in range(clip.height) {
        src_i = vis_i + scroll;
        term_row = clip.y + vis_i;
        if term_row < 0 or term_row >= buf.rows {
            continue;
        }
        buffer_clear_rect(buf, clip.x, term_row, clip.width, 1, fill);
        if src_i < 0 or src_i >= len(lines) {
            continue;
        }
        if rows is not None and len(rows) == len(lines) {
            spans = rows[src_i];
            if fill is not None {
                spans = [_with_fill(sp, fill) for sp in spans];
            }
            buffer_blit_spans(buf, term_row, clip.x, spans, clip.width);
            continue;
        }
        _paint_text_into(buf, lines[src_i], term_row, clip.x, clip.width, fill,);
    }
}


impl _overlay_z_key(hit: _OverlayHit) -> int {
    return hit.z;
}


impl _overlay_jid_key(hit: _OverlayHit) -> str {
    return hit.id_str;
}


impl _layered_overlays(layout_root: UiNode) -> list[UiNode] {
    found: list[_OverlayHit] = [];
    if isinstance(layout_root, Screen) {
        for ov in [layout_root->:Layer:->] {
            z = 0;
            for e in [edge layout_root->:Layer:->ov] {
                z = e.z_index;
            }
            found.append(_OverlayHit(nd=ov, z=z, id_str=node_id(ov)));
        }
    }
    if not found {
        return [];
    }
    found.sort(key=_overlay_jid_key);
    found.sort(key=_overlay_z_key);
    return [hit.nd for hit in found];
}


impl _paint_node(
    state: LayoutState, n: UiNode, buf: CellBuffer, rend: Renderer | None = None
) {
    frame = state.last_frame;
    if frame is None {
        return;
    }
    nid = node_id(n);
    ent = frame.entries.get(nid);
    if ent is None {
        return;
    }
    if ent.wrapped_lines or nid in state.content {
        spec = state.specs.get(nid);
        scrolls = spec is not None and spec.scroll_vertical;
        rows = rend.styled.get(nid) if rend is not None else None;
        fill = rend.fills.get(nid) if rend is not None else None;
        _paint_entry_lines(buf, ent, scrolls, rows, fill);
    }
}


impl _paint_tree(
    state: LayoutState, n: UiNode, buf: CellBuffer, rend: Renderer | None = None
) {
    _paint_node(state, n, buf, rend);
    if isinstance(n, UiContainer) {
        for child in ordered_children(n) {
            if isinstance(child, Overlay) {
                continue;
            }
            _paint_tree(state, child, buf, rend);
        }
    }
}


impl _paint_frame_buffer(renderer: Renderer, layout_root: UiNode) -> CellBuffer {
    state = renderer.layout;
    buf = _blank_buffer(state.viewport.columns, state.viewport.rows);
    _paint_tree(state, layout_root, buf, renderer);
    for overlay in _layered_overlays(layout_root) {
        _paint_node(state, overlay, buf, renderer);
    }
    return buf;
}


impl _with_fill(span: TextSpan, fill: StyleAttrs) -> TextSpan {
    a = span.attrs;
    if a is None {
        return TextSpan(text=span.text, attrs=fill);
    }
    if a.bg is not None or fill.bg is None {
        return span;
    }
    return TextSpan(
        text=span.text,
        attrs=StyleAttrs(
            fg=a.fg,
            bg=fill.bg,
            bold=a.bold,
            dim=a.dim,
            italic=a.italic,
            underline=a.underline,
            reverse=a.reverse
        )
    );
}
