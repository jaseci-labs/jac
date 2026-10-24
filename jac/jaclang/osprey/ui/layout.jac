def _fail(diagnostics: list[LayoutDiagnostic]) -> LayoutResult;


def _overflow_warning(node_ids: list[str]) -> LayoutDiagnostic;


def _child_ids(scope_order: list[_ScopedNode], parent_id: str) -> list[str];


def _place_axis(
    result: CompileResult,
    values: dict[int, float],
    order: list[_ScopedNode],
    parent_id: str,
    p_start: int,
    p_end: int,
    infos: dict[str, PartitionInfo],
    starts: dict[str, int],
    ends: dict[str, int],
    warnings: list[LayoutDiagnostic],
    horizontal: bool,
) -> None;


def _structural_naturals(
    order: list[_ScopedNode], state: LayoutState, wrap_widths: dict[str, int],
) -> dict[str, Size];


def compute_layout(
    state: LayoutState, layout_root: UiNode, viewport: Viewport,
) -> LayoutResult;


impl _fail(diagnostics: list[LayoutDiagnostic]) -> LayoutResult {
    return LayoutResult(ok=False, frame=None, diagnostics=diagnostics);
}


impl _overflow_warning(node_ids: list[str]) -> LayoutDiagnostic {
    return LayoutDiagnostic(
        code=LayoutError.OVERFLOW,
        severity=LayoutSeverity.WARNING,
        message="partition exceeded span; quantized clip-aware",
        node_ids=node_ids,
    );
}


impl _child_ids(scope_order: list[_ScopedNode], parent_id: str) -> list[str] {
    out: list[str] = [];
    for scoped in scope_order {
        if scoped.parent_id == parent_id and not scoped.is_overlay {
            out.append(scoped.id_str);
        }
    }
    return out;
}


impl _place_axis(
    result: CompileResult,
    values: dict[int, float],
    order: list[_ScopedNode],
    parent_id: str,
    p_start: int,
    p_end: int,
    infos: dict[str, PartitionInfo],
    starts: dict[str, int],
    ends: dict[str, int],
    warnings: list[LayoutDiagnostic],
    horizontal: bool,
) -> None {
    kids = _child_ids(order, parent_id);
    if len(kids) == 0 {
        return;
    }

    placed = False;
    info = infos.get(parent_id);
    aligned = False;
    if info is not None and len(info.child_ids) == len(kids) {
        aligned = True;
        for i in range(len(kids)) {
            if info.child_ids[i] != kids[i] {
                aligned = False;
            }
        }
        if not aligned {
            warnings.append(
                LayoutDiagnostic(
                    code=LayoutError.INTERNAL_INVARIANT,
                    severity=LayoutSeverity.ERROR,
                    message="partition child order misaligned with scope walk",
                    node_ids=[parent_id],
                )
            );
        }
    }
    if info is not None and aligned {
        req = PartitionRequest(
            span=p_end - p_start,
            targets=info.targets,
            fixed=info.fixed,
            minimums=info.minimums,
            maximums=info.maximums,
        );
        qr = quantize_partition(req);
        if qr.ok {
            pos = p_start;
            for i in range(len(kids)) {
                kid = kids[i];
                starts[kid] = pos;
                ends[kid] = pos + qr.sizes[i];
                pos += qr.sizes[i];
            }
            placed = True;
        } else {
            warnings.append(_overflow_warning([parent_id]));
        }
    }

    if not placed {
        for kid in kids {
            e = result.nodes[kid];
            if horizontal {
                starts[kid] = snap_edge(values[e.left.id]);
                ends[kid] = snap_edge(values[e.right.id]);
            } else {
                starts[kid] = snap_edge(values[e.top.id]);
                ends[kid] = snap_edge(values[e.bottom.id]);
            }
        }
    }

    for kid in kids {
        _place_axis(
            result,
            values,
            order,
            kid,
            starts[kid],
            ends[kid],
            infos,
            starts,
            ends,
            warnings,
            horizontal,
        );
    }
}


impl _structural_naturals(
    order: list[_ScopedNode], state: LayoutState, wrap_widths: dict[str, int],
) -> dict[str, Size] {
    out: dict[str, Size] = {};
    rev: list[_ScopedNode] = [];
    for i in range(len(order)) {
        rev.insert(0, order[i]);
    }
    for scoped in rev {
        id_str = scoped.id_str;
        spec = state.specs.get(id_str);
        lines: list[str] = [];
        ent = state.content.get(id_str);
        if ent is not None {
            lines = ent.lines;
        }
        w_cols = wrap_widths.get(id_str, 80);
        if w_cols < 1 {
            w_cols = 1;
        }
        leaf_h = 0;
        for line in lines {
            leaf_h += wrap_text_joined(line, w_cols).count("\n") + 1;
        }

        kids = _child_ids(order, id_str);
        if spec is None or len(kids) == 0 {
            out[id_str] = Size(width=natural_width(lines), height=leaf_h,);
            continue;
        }
        flow_horiz = False;
        if spec.flow_axis == Axis.HORIZONTAL {
            flow_horiz = True;
        }
        sum_flow = 0.0;
        max_cross = 0.0;
        for kid_id in kids {
            nat = out[kid_id];
            kid_w: float = float(nat.width);
            kid_h: float = float(nat.height);
            kspec = state.specs.get(kid_id);
            if kspec is not None {
                if kspec.width.mode == SizeMode.FIXED
                    and kspec.width.preferred is not None {
                    kid_w = kspec.width.preferred;
                }
                if kspec.height.mode == SizeMode.FIXED
                    and kspec.height.preferred is not None {
                    kid_h = kspec.height.preferred;
                }
            }
            if flow_horiz {
                sum_flow += kid_w;
                if kid_h > max_cross {
                    max_cross = kid_h;
                }
            } else {
                sum_flow += kid_h;
                if kid_w > max_cross {
                    max_cross = kid_w;
                }
            }
        }
        if flow_horiz {
            out[id_str] = Size(width=int(sum_flow), height=int(max_cross),);
        } else {
            out[id_str] = Size(width=int(max_cross), height=int(sum_flow),);
        }
    }
    return out;
}


impl compute_layout(
    state: LayoutState, layout_root: UiNode, viewport: Viewport,
) -> LayoutResult {
    scope = _collect_scope(layout_root);
    if scope.error is not None {
        return _fail([scope.error]);
    }
    order = scope.order;
    root_id = node_id(layout_root);

    hint_all: dict[str, int] = {};
    for scoped in order {
        hint_all[scoped.id_str] = viewport.columns;
    }
    naturals_w = _structural_naturals(order, state, hint_all);

    ch = compile_layout(state, layout_root, viewport, naturals_w, "h");
    if not ch.ok or ch.solver is None {
        return _fail(ch.diagnostics);
    }
    hv = ch.solver.snapshot().values;

    L: dict[str, int] = {};
    R: dict[str, int] = {};
    L[root_id] = 0;
    R[root_id] = viewport.columns;
    hinfos: dict[str, PartitionInfo] = {};
    for info in ch.partitions {
        if info.horizontal {
            hinfos[info.parent_id] = info;
        }
    }
    warnings: list[LayoutDiagnostic] = [];
    _place_axis(
        ch, hv, order, root_id, 0, viewport.columns, hinfos, L, R, warnings, True,
    );

    for scoped in order {
        if not scoped.is_overlay {
            continue;
        }
        id_str = scoped.id_str;
        eh = ch.nodes[id_str];
        L[id_str] = snap_edge(hv[eh.left.id]);
        R[id_str] = snap_edge(hv[eh.right.id]);
    }

    widths: dict[str, int] = {};
    wrapped_by_node: dict[str, list[str]] = {};
    for scoped in order {
        id_str = scoped.id_str;
        w = R[id_str] - L[id_str];
        if w < 0 {
            return _fail(
                [
                    LayoutDiagnostic(
                        code=LayoutError.INTERNAL_INVARIANT,
                        severity=LayoutSeverity.ERROR,
                        message="negative derived width",
                        node_ids=[id_str],
                    )
                ]
            );
        }
        widths[id_str] = w;
        ent_w = state.content.get(id_str);
        if ent_w is not None {
            wrapped_by_node[id_str] = list(
                wrapped_lines_at(
                    ent_w.lines, ent_w.content_revision, ent_w.style_revision, id_str, w
                )
            );
        } else {
            wrapped_by_node[id_str] = [];
        }
    }

    naturals_h = _structural_naturals(order, state, widths);

    cv = compile_layout(state, layout_root, viewport, naturals_h, "v");
    if not cv.ok or cv.solver is None {
        return _fail(cv.diagnostics);
    }
    vv = cv.solver.snapshot().values;

    T: dict[str, int] = {};
    B: dict[str, int] = {};
    T[root_id] = 0;
    B[root_id] = viewport.rows;
    vinfos: dict[str, PartitionInfo] = {};
    for info in cv.partitions {
        if not info.horizontal {
            vinfos[info.parent_id] = info;
        }
    }
    _place_axis(
        cv, vv, order, root_id, 0, viewport.rows, vinfos, T, B, warnings, False,
    );
    for scoped in order {
        if not scoped.is_overlay {
            continue;
        }
        id_str = scoped.id_str;
        ev = cv.nodes[id_str];
        T[id_str] = snap_edge(vv[ev.top.id]);
        B[id_str] = snap_edge(vv[ev.bottom.id]);
    }

    entries: dict[str, FrameEntry] = {};
    clips: dict[str, Rect] = {};

    for scoped in order {
        id_str = scoped.id_str;
        l = L[id_str];
        r = R[id_str];
        t = T[id_str];
        b = B[id_str];

        w = r - l;
        h = b - t;
        if scoped.is_overlay {
            if l < 0 {
                l = 0;
            }
            if t < 0 {
                t = 0;
            }
        }
        if w < 0 or h < 0 {
            return _fail(
                [
                    LayoutDiagnostic(
                        code=LayoutError.INTERNAL_INVARIANT,
                        severity=LayoutSeverity.ERROR,
                        message="negative derived size",
                        node_ids=[id_str],
                    )
                ]
            );
        }
        rect = Rect(x=l, y=t, width=w, height=h);

        if scoped.parent_id == "" {
            clip = _copy_rect(rect);
        } else {
            pclip = clips[scoped.parent_id];
            if pclip.width <= 0 or pclip.height <= 0 or w <= 0 or h <= 0 {
                clip = Rect(x=0, y=0, width=0, height=0);
            } else {
                x0 = pclip.x if pclip.x > l else l;
                y0 = pclip.y if pclip.y > t else t;
                pr_end = pclip.x + pclip.width;
                pb_end = pclip.y + pclip.height;
                x1 = pr_end if pr_end < r else r;
                y1 = pb_end if pb_end < b else b;
                cw = x1 - x0;
                chh = y1 - y0;
                if cw <= 0 or chh <= 0 {
                    clip = Rect(x=0, y=0, width=0, height=0);
                } else {
                    clip = Rect(x=x0, y=y0, width=cw, height=chh);
                }
            }
        }
        clips[id_str] = clip;

        wrapped = wrapped_by_node[id_str];
        requested = 0;
        spec = state.specs.get(id_str);
        if spec is not None and spec.scroll_vertical {
            requested = state.scroll_requests.get(id_str, 0);
        }
        max_off = max(0, len(wrapped) - max(1, h));
        off = min(max(requested, 0), max_off);

        entries[id_str] = FrameEntry(
            measured=Size(width=w, height=h),
            rect=_copy_rect(rect),
            clip=clip,
            wrapped_lines=list(wrapped),
            requested_scroll_offset=requested,
            scroll_offset=off,
            max_scroll_offset=max_off,
        );
    }

    overlay_ids: list[str] = [];
    for scoped in order {
        if scoped.is_overlay {
            overlay_ids.append(scoped.id_str);
        }
    }

    prev_gen = 0;
    if state.last_frame is not None {
        prev_gen = state.last_frame.generation;
    }
    frame = LayoutFrame(
        generation=prev_gen + 1,
        viewport=Viewport(columns=viewport.columns, rows=viewport.rows),
        entries=entries,
        overlay_ids=overlay_ids,
    );
    state.last_frame = frame;

    diags: list[LayoutDiagnostic] = [];
    for d in warnings {
        diags.append(d);
    }
    return LayoutResult(ok=True, frame=frame, diagnostics=diags);
}
