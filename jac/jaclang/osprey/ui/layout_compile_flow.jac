def _flow_weight(size: AxisSize) -> float;


def _flow_hard_claim(size: AxisSize) -> float;


def _flow_soft_claim(size: AxisSize, natural: float | None) -> float;


def _allocate_span(children: list[_FlowChild], span: float) -> _Allocation;


def _emit_partition(
    result: CompileResult,
    owner: _Entry,
    entries_by_id: dict[str, _Entry],
    natural_sizes: dict[str, Size],
    span_w: float,
    span_h: float,
    phase: str,
) -> bool;


def _ordered_flow_children(
    owner: _Entry, entries_by_id: dict[str, _Entry],
) -> list[_Entry];

impl _flow_weight(size: AxisSize) -> float {
    if size.mode == SizeMode.GROW {
        return size.grow_weight;
    }
    if size.mode == SizeMode.FILL {
        return 1.0;
    }
    return 0.0;
}


impl _flow_hard_claim(size: AxisSize) -> float {
    if size.mode == SizeMode.FIXED {
        return _req(size.preferred);
    }
    return 0.0;
}


impl _flow_soft_claim(size: AxisSize, natural: float | None) -> float {
    if size.mode == SizeMode.FIXED {
        return _req(size.preferred);
    }
    if size.preferred is not None {
        return size.preferred;
    }
    if natural is not None {
        return natural;
    }
    if size.mode == SizeMode.BOUNDED {
        return size.minimum;
    }
    return 0.0;
}


impl _allocate_span(children: list[_FlowChild], span: float) -> _Allocation {
    n = len(children);
    alloc = _Allocation(targets=[0.0] * n);
    hard_sum = 0.0;
    soft_sum = 0.0;
    for i in range(n) {
        size = children[i].size;
        if _flow_weight(size) == 0.0 {
            hard_sum += max(0.0, _flow_hard_claim(size));
            soft_sum += max(0.0, _flow_soft_claim(size, children[i].natural));
        }
    }
    remaining = span - hard_sum;
    if remaining < 0.0 or soft_sum > span + 1e-8 {
        alloc.overflow = True;
        remaining = max(0.0, remaining);
    }
    if hard_sum > span + 1e-8 {
        alloc.hard_overflow = True;
    }
    active: list[int] = [];
    for i in range(n) {
        if _flow_weight(children[i].size) > 0.0 {
            active.append(i);
        } else {
            alloc.targets[i] = max(
                0.0, _flow_soft_claim(children[i].size, children[i].natural)
            );
        }
    }
    while len(active) {
        wsum = 0.0;
        for i in active {
            wsum += _flow_weight(children[i].size);
        }
        if wsum <= 0.0 {
            for i in active {
                alloc.targets[i] = 0.0;
            }
            break;
        }
        frozen: list[int] = [];
        for i in active {
            share = remaining * (_flow_weight(children[i].size) / wsum);
            mx = children[i].size.maximum;
            if share < children[i].size.minimum - 1e-8 {
                alloc.targets[i] = max(0.0, children[i].size.minimum);
                remaining -= alloc.targets[i];
                frozen.append(i);
            } elif mx is not None and share > mx + 1e-8 {
                alloc.targets[i] = mx;
                remaining -= mx;
                frozen.append(i);
            }
        }
        if not frozen {
            for i in active {
                alloc.targets[i] = max(
                    0.0, remaining * (_flow_weight(children[i].size) / wsum)
                );
            }
            break;
        }
        next_active: list[int] = [];
        for i in active {
            is_frozen = False;
            for f in frozen {
                if f == i {
                    is_frozen = True;
                }
            }
            if not is_frozen {
                next_active.append(i);
            }
        }
        active = next_active;
    }
    for i in range(n) {
        if alloc.targets[i] < 0.0 {
            alloc.targets[i] = 0.0;
        }
    }
    return alloc;
}


impl _emit_partition(
    result: CompileResult,
    owner: _Entry,
    entries_by_id: dict[str, _Entry],
    natural_sizes: dict[str, Size],
    span_w: float,
    span_h: float,
    phase: str,
) -> bool {
    spec = owner.spec;
    parent_edges = owner.edges;
    horizontal_flow = spec.flow_axis.value == "horizontal";
    flow_label = "h" if horizontal_flow else "v";

    flow_kids: list[_FlowChild] = [];
    for scoped in _ordered_flow_children(owner, entries_by_id) {
        child_spec = scoped.spec;
        nat: float | None = None;
        nid = scoped.edges.id_str;
        if horizontal_flow {
            size_axis = child_spec.width;
            if nid in natural_sizes {
                nat = float(natural_sizes[nid].width);
            }
        } else {
            size_axis = child_spec.height;
            if nid in natural_sizes {
                nat = float(natural_sizes[nid].height);
            }
        }
        flow_kids.append(_FlowChild(ent=scoped, size=size_axis, natural=nat));
    }

    span_flow = span_w if horizontal_flow else span_h;
    alloc = _allocate_span(flow_kids, span_flow);
    if _wants(phase, horizontal_flow) {
        info = PartitionInfo(
            parent_id=parent_edges.id_str, horizontal=horizontal_flow, span=span_flow,
        );
        for i in range(len(flow_kids)) {
            kid_size = flow_kids[i].size;
            mx = kid_size.maximum;
            if mx is None {
                mx = 1e308;
            }
            info.child_ids.append(flow_kids[i].ent.edges.id_str);
            info.targets.append(alloc.targets[i]);
            info.fixed.append(_flow_weight(kid_size) == 0.0);
            info.minimums.append(kid_size.minimum);
            info.maximums.append(mx);
        }
        result.partitions.append(info);
    }
    if alloc.overflow {
        result.diagnostics.append(
            LayoutDiagnostic(
                code=LayoutError.OVERFLOW,
                severity=LayoutSeverity.WARNING,
                message="flow partition exceeds parent span; "
                "non-flexible claims kept",
                node_ids=[parent_edges.id_str],
            )
        );
    }

    if len(flow_kids) and _wants(phase, horizontal_flow) {
        if not _emit(
            result,
            _expr(
                [
                    _t(_axis_start(flow_kids[0].ent.edges, horizontal_flow)),
                    _t(_axis_start(parent_edges, horizontal_flow), -1.0),

                ]
            ),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("flow", parent_edges.id_str, flow_label),
        ) {
            return False;
        }
        for i in range(1, len(flow_kids)) {
            if not _emit(
                result,
                _expr(
                    [
                        _t(_axis_start(flow_kids[i].ent.edges, horizontal_flow)),
                        _t(
                            _axis_end(flow_kids[i - 1].ent.edges, horizontal_flow), -1.0
                        ),

                    ]
                ),
                Relation.EQ,
                StrengthTier.REQUIRED,
                _prov("flow", parent_edges.id_str, flow_label),
            ) {
                return False;
            }
        }
    }

    has_flexible = False;
    for i in range(len(flow_kids)) {
        kid = flow_kids[i];
        kid_edges = kid.ent.edges;
        kid_scoped = kid.ent.scoped;
        if _wants(phase, horizontal_flow) and _flow_weight(kid.size) > 0.0 {
            has_flexible = True;
            if not _emit(
                result,
                _expr(
                    [
                        _t(_axis_end(kid_edges, horizontal_flow)),
                        _t(_axis_start(kid_edges, horizontal_flow), -1.0),

                    ],
                    -alloc.targets[i]
                ),
                Relation.EQ,
                StrengthTier.REQUIRED,
                _prov(
                    "grow",
                    kid_edges.id_str,
                    flow_label,
                    key=kid_edges.key,
                    parent=parent_edges.id_str,
                    rank=kid_scoped.rank,
                    src="spec",
                    extra="weight="
                        + repr(_flow_weight(kid.size))
                        + " target="
                        + repr(alloc.targets[i]),
                ),
            ) {
                return False;
            }
        } elif _wants(phase, horizontal_flow) {
            if not _emit_sized_axis(
                result,
                kid.size,
                _axis_start(kid_edges, horizontal_flow),
                _axis_end(kid_edges, horizontal_flow),
                horizontal_flow,
                kid_edges.id_str,
                kid.natural,
                "src=spec parent=" + parent_edges.id_str + "#" + str(kid_scoped.rank),
            ) {
                return False;
            }
        }

        if _wants(phase, not horizontal_flow) {
            if not _emit_cross_axis(
                result, kid.ent, owner, natural_sizes, not horizontal_flow,
            ) {
                return False;
            }
        }

        child_span_w = alloc.targets[i] if horizontal_flow else span_w;
        child_span_h = span_h if horizontal_flow else alloc.targets[i];
        if isinstance(kid.ent.scoped.target, UiContainer) {
            if not _emit_partition(
                result,
                kid.ent,
                entries_by_id,
                natural_sizes,
                child_span_w,
                child_span_h,
                phase,
            ) {
                return False;
            }
        }
    }

    if has_flexible and not alloc.hard_overflow and _wants(phase, horizontal_flow) {
        last_edges = flow_kids[len(flow_kids) - 1].ent.edges;
        if not _emit(
            result,
            _expr(
                [
                    _t(_axis_end(last_edges, horizontal_flow)),
                    _t(_axis_end(parent_edges, horizontal_flow), -1.0),

                ]
            ),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("flow", parent_edges.id_str, flow_label),
        ) {
            return False;
        }
    }
    return True;
}


impl _ordered_flow_children(
    owner: _Entry, entries_by_id: dict[str, _Entry],
) -> list[_Entry] {
    out: list[_Entry] = [];
    if not isinstance(owner.scoped.target, UiContainer) {
        return out;
    }
    for child in ordered_children(owner.scoped.target) {
        cid = node_id(child);
        if cid in entries_by_id and not entries_by_id[cid].scoped.is_overlay {
            out.append(entries_by_id[cid]);
        }
    }
    return out;
}
