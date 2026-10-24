def _rects_equal(a: Rect, b: Rect) -> bool;


def _walk_damage(renderer: Renderer, n: UiNode, out: list[DamageRect],);


def compute_damage(renderer: Renderer, layout_root: UiNode) -> list[DamageRect];


def _merge_damage(damage: list[DamageRect]) -> list[Rect];


def _diff_ansi(
    previous: CellBuffer | None,
    desired: CellBuffer,
    patch_rects: list[Rect],
    columns: int,
    rows_n: int,
    force: bool = False,
) -> AnsiDiff;


def _resolve_cursor(renderer: Renderer) -> CursorPos;


def _run_layout(renderer: Renderer, layout_root: UiNode) -> LayoutResult;


def _snapshot_rects(renderer: Renderer);

impl _rects_equal(a: Rect, b: Rect) -> bool {
    return (a.x == b.x and a.y == b.y and a.width == b.width and a.height == b.height);
}


impl _walk_damage(renderer: Renderer, n: UiNode, out: list[DamageRect],) {
    state = renderer.layout;
    frame = state.last_frame;
    nid = node_id(n);
    ent = frame.entries.get(nid) if frame is not None else None;
    prev = renderer.prev_rects.get(nid, Rect());
    if ent is not None {
        cur = ent.rect;
        if prev.is_empty() and not cur.is_empty() {
            out.append(DamageRect(rect=cur.copy(), reason="appear"));
        } elif not prev.is_empty() and cur.is_empty() {
            out.append(DamageRect(rect=prev.copy(), reason="disappear"));
        } elif not _rects_equal(prev, cur) {
            out.append(DamageRect(rect=rect_union(prev, cur), reason="bounds"));
        } elif (nid in renderer.pending_semantic or nid in renderer.pending_layout) {
            if not cur.is_empty() {
                out.append(DamageRect(rect=cur.copy(), reason="semantic"));
            }
        }
    }
    if isinstance(n, UiContainer) {
        for child in ordered_children(n) {
            _walk_damage(renderer, child, out);
        }
        if isinstance(n, Screen) {
            for overlay in _layered_overlays(n) {
                _walk_damage(renderer, overlay, out);
            }
        }
    }
}


impl compute_damage(renderer: Renderer, layout_root: UiNode) -> list[DamageRect] {
    out: list[DamageRect] = [];
    for d in renderer.damage {
        out.append(d);
    }
    _walk_damage(renderer, layout_root, out);
    if renderer.previous is None {
        out.append(
            DamageRect(
                rect=Rect(
                    x=0,
                    y=0,
                    width=renderer.layout.viewport.columns,
                    height=renderer.layout.viewport.rows,
                ),
                reason="first_frame",
            )
        );
    }
    return out;
}


impl _merge_damage(damage: list[DamageRect]) -> list[Rect] {
    rects: list[Rect] = [];
    for d in damage {
        if not d.rect.is_empty() {
            rects.append(d.rect.copy());
        }
    }
    changed = True;
    while changed {
        changed = False;
        out: list[Rect] = [];
        for r in rects {
            hit = -1;
            for i in range(len(out)) {
                if out[i].intersects(r) {
                    hit = i;
                    break;
                }
            }
            if hit >= 0 {
                out[hit] = rect_union(out[hit], r);
                changed = True;
            } else {
                out.append(r);
            }
        }
        rects = out;
    }
    return rects;
}


impl _diff_ansi(
    previous: CellBuffer | None,
    desired: CellBuffer,
    patch_rects: list[Rect],
    columns: int,
    rows_n: int,
    force: bool = False,
) -> AnsiDiff {
    _ = (columns, rows_n);
    diff = diff_buffers_ansi(previous, desired, patch_rects, force=force);
    return AnsiDiff(text=diff.text, cells_written=diff.cells_written);
}


impl _resolve_cursor(renderer: Renderer) -> CursorPos {
    if not renderer.cursor_node_id {
        return CursorPos();
    }
    frame = renderer.layout.last_frame;
    ent = frame.entries.get(renderer.cursor_node_id) if frame is not None else None;
    if ent is None or ent.rect.is_empty() {
        return CursorPos();
    }
    row = ent.rect.y + renderer.cursor_row_offset;
    col = ent.rect.x + renderer.cursor_col_offset;
    if row < 0 or col < 0 {
        return CursorPos();
    }
    if row >= renderer.layout.viewport.rows
        or col >= renderer.layout.viewport.columns {
        return CursorPos();
    }
    return CursorPos(row=row, col=col);
}


impl _run_layout(renderer: Renderer, layout_root: UiNode) -> LayoutResult {
    state = renderer.layout;
    vp = state.viewport;
    return compute_layout(
        state, layout_root, Viewport(columns=vp.columns, rows=vp.rows),
    );
}


impl _snapshot_rects(renderer: Renderer) {
    fresh: dict[str, Rect] = {};
    frame = renderer.layout.last_frame;
    if frame is not None {
        for (nid, e) in frame.entries.items() {
            fresh[nid] = e.rect.copy();
        }
    }
    renderer.prev_rects = fresh;
}
