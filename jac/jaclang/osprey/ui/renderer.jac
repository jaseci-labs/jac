def create_renderer(columns: int = 80, rows: int = 24) -> Renderer;


def set_node_contract(renderer: Renderer, n: UiNode, spec: LayoutSpec);


def set_node_content(renderer: Renderer, n: UiNode, lines: list[str]);


def set_node_spans(
    renderer: Renderer,
    n: UiNode,
    rows: list[list[TextSpan]],
    fill: StyleAttrs | None = None,
);


def set_node_fill(renderer: Renderer, n: UiNode, fill: StyleAttrs | None);


def mark_semantic_dirty(renderer: Renderer, n: UiNode);


def mark_layout_dirty(renderer: Renderer, n: UiNode);


def request_cursor(
    renderer: Renderer, n: UiNode, row_offset: int = 0, col_offset: int = 0,
);


def clear_cursor(renderer: Renderer);


def detach_node(renderer: Renderer, n: UiNode);

def relayout(renderer: Renderer, layout_root: UiNode) -> LayoutResult;


def desired_cells(renderer: Renderer, layout_root: UiNode) -> list[str];


def render_frame(
    renderer: Renderer, layout_root: UiNode, term: Terminal,
) -> FrameResult;


def frame_used_full_clear(writes: list[str]) -> bool;


def damage_cell_count(damage: list[DamageRect]) -> int;

impl create_renderer(columns: int = 80, rows: int = 24) -> Renderer {
    return Renderer(layout=create_layout_state(columns, rows));
}


impl set_node_contract(renderer: Renderer, n: UiNode, spec: LayoutSpec) {
    set_spec(renderer.layout, n, spec);
}


impl set_node_content(renderer: Renderer, n: UiNode, lines: list[str]) {
    nid = node_id(n);
    renderer.styled.pop(nid, None);
    rev = renderer.content_revisions.get(nid, 0) + 1;
    renderer.content_revisions[nid] = rev;
    set_content(renderer.layout, n, lines, rev);
}


impl mark_semantic_dirty(renderer: Renderer, n: UiNode) {
    renderer.pending_semantic.add(node_id(n));
}


impl mark_layout_dirty(renderer: Renderer, n: UiNode) {
    renderer.pending_layout.add(node_id(n));
}


impl request_cursor(
    renderer: Renderer, n: UiNode, row_offset: int = 0, col_offset: int = 0,
) {
    renderer.cursor_node_id = node_id(n);
    renderer.cursor_row_offset = row_offset;
    renderer.cursor_col_offset = col_offset;
}


impl clear_cursor(renderer: Renderer) {
    renderer.cursor_node_id = "";
    renderer.cursor_row_offset = 0;
    renderer.cursor_col_offset = 0;
}


impl detach_node(renderer: Renderer, n: UiNode) {
    ent = frame_entry_of(renderer.layout, n);
    if ent is not None and not ent.rect.is_empty() {
        renderer.damage.append(DamageRect(rect=ent.rect.copy(), reason="detach"));
    }
    if renderer.cursor_node_id == node_id(n) {
        clear_cursor(renderer);
    }
    renderer.content_revisions.pop(node_id(n), None);
    clear_node(renderer.layout, n);
}

impl relayout(renderer: Renderer, layout_root: UiNode) -> LayoutResult {
    return _run_layout(renderer, layout_root);
}


impl desired_cells(renderer: Renderer, layout_root: UiNode) -> list[str] {
    _run_layout(renderer, layout_root);
    buf = _paint_frame_buffer(renderer, layout_root);
    return buffer_to_plain_rows(buf);
}


impl render_frame(
    renderer: Renderer, layout_root: UiNode, term: Terminal,
) -> FrameResult {
    state = renderer.layout;
    cols = term.columns if term.columns > 0 else state.viewport.columns;
    rows_n = term.rows if term.rows > 0 else state.viewport.rows;
    state.viewport.columns = cols;
    state.viewport.rows = rows_n;

    resized = (
        renderer.previous is not None
        and (cols != renderer.last_frame_columns or rows_n != renderer.last_frame_rows)
    );
    if resized {
        renderer.damage.append(
            DamageRect(rect=Rect(x=0, y=0, width=cols, height=rows_n), reason="resize",)
        );
        renderer.previous = None;
    }

    _run_layout(renderer, layout_root);
    damage = compute_damage(renderer, layout_root);
    desired = _paint_frame_buffer(renderer, layout_root);
    patch_rects = _merge_damage(damage);

    diff = _diff_ansi(
        renderer.previous,
        desired,
        patch_rects,
        cols,
        rows_n,
        force=(renderer.previous is None),
    );
    cursor = _resolve_cursor(renderer);
    cursor_visible = cursor.row >= 0 and cursor.col >= 0;
    ansi = diff.text;
    if cursor_visible {
        if not term.cursor_visible {
            term.show_cursor();
        }
        ansi = ansi + f"\x1b[{cursor.row + 1};{cursor.col + 1}H";
    } else {
        if term.cursor_visible {
            term.hide_cursor();
        }
    }
    synchronized_write(term, ansi);
    used_full_clear = "\x1b[2J" in ansi or "\x1b[3J" in ansi;
    renderer.last_frame_columns = cols;
    renderer.last_frame_rows = rows_n;
    renderer.previous = desired;
    renderer.damage = [];
    renderer.pending_semantic = set();
    renderer.pending_layout = set();
    _snapshot_rects(renderer);
    renderer.last_cursor_row = cursor.row;
    renderer.last_cursor_col = cursor.col;
    renderer.last_cursor_visible = cursor_visible;
    return FrameResult(
        damage=damage,
        cells_written=diff.cells_written,
        used_full_clear=used_full_clear,
        patch_rects=patch_rects,
        cursor_row=cursor.row,
        cursor_col=cursor.col,
        cursor_visible=cursor_visible,
        sync_wrapped=True,
    );
}


impl frame_used_full_clear(writes: list[str]) -> bool {
    joined = "".join(writes);
    return "\x1b[2J" in joined or "\x1b[3J" in joined;
}


impl damage_cell_count(damage: list[DamageRect]) -> int {
    total = 0;
    for d in damage {
        if not d.rect.is_empty() {
            total += d.rect.width * d.rect.height;
        }
    }
    return total;
}


impl set_node_spans(
    renderer: Renderer,
    n: UiNode,
    rows: list[list[TextSpan]],
    fill: StyleAttrs | None = None,
) {
    set_node_content(renderer, n, ["".join([s.text for s in row]) for row in rows]);
    nid = node_id(n);
    renderer.styled[nid] = rows;
    if fill is not None {
        renderer.fills[nid] = fill;
    }
    renderer.pending_semantic.add(nid);
}


impl set_node_fill(renderer: Renderer, n: UiNode, fill: StyleAttrs | None) {
    nid = node_id(n);
    if fill is None {
        renderer.fills.pop(nid, None);
    } else {
        renderer.fills[nid] = fill;
    }
    renderer.pending_semantic.add(nid);
}
