def fill_axis -> AxisSize;


def fixed_axis(n: float) -> AxisSize;


def grow_axis(weight: float) -> AxisSize;


def intrinsic_axis -> AxisSize;


def _error(
    code: LayoutError, message: str, node_ids: list[str] = []
) -> MutationResult;


def _ok -> MutationResult;


def create_layout_state(columns: int = 80, rows: int = 24) -> LayoutState;


def _validate_axis_size(
    axis_name: str, size: AxisSize, node_id_str: str
) -> list[LayoutDiagnostic];


def _kind_label(kind: LayoutRelationKind) -> str;


def _axis_label(axis: Axis) -> str;


def validate_spec(spec: LayoutSpec, node_id_str: str = "") -> list[LayoutDiagnostic];


def set_spec(state: LayoutState, target: UiNode, spec: LayoutSpec) -> MutationResult;


def _validate_relation_shape(rel: LayoutRelation) -> LayoutDiagnostic | None;


def add_relation(state: LayoutState, relation: LayoutRelation) -> MutationResult;


def remove_relation(state: LayoutState, handle: RelationHandle) -> MutationResult;


def set_content(
    state: LayoutState,
    target: UiNode,
    lines: list[str],
    content_revision: int,
    style_revision: int = 0,
) -> MutationResult;


def set_scroll_offset(
    state: LayoutState, target: UiNode, requested_offset: int
) -> MutationResult;


def clear_node(state: LayoutState, target: UiNode) -> MutationResult;


def frame_entry_of(state: LayoutState, target: UiNode) -> FrameEntry | None;


def rect_of(state: LayoutState, target: UiNode) -> Rect | None;


def _copy_rect(r: Rect) -> Rect;

impl fill_axis -> AxisSize {
    return AxisSize(mode=SizeMode.FILL);
}


impl fixed_axis(n: float) -> AxisSize {
    return AxisSize(mode=SizeMode.FIXED, preferred=n);
}


impl grow_axis(weight: float) -> AxisSize {
    return AxisSize(mode=SizeMode.GROW, grow_weight=weight);
}


impl intrinsic_axis -> AxisSize {
    return AxisSize(mode=SizeMode.INTRINSIC);
}


impl _error(
    code: LayoutError, message: str, node_ids: list[str] = []
) -> MutationResult {
    return MutationResult(
        ok=False,
        diagnostics=[
            LayoutDiagnostic(
                code=code,
                severity=LayoutSeverity.ERROR,
                message=message,
                node_ids=node_ids,
            )
        ],
    );
}


impl _ok -> MutationResult {
    return MutationResult(ok=True);
}


impl create_layout_state(columns: int = 80, rows: int = 24) -> LayoutState {
    return LayoutState(viewport=Viewport(columns=columns, rows=rows));
}


impl _validate_axis_size(
    axis_name: str, size: AxisSize, node_id_str: str
) -> list[LayoutDiagnostic] {
    diags: list[LayoutDiagnostic] = [];
    for value in [size.minimum, size.preferred, size.maximum] {
        if value is not None and not is_finite(value) {
            diags.append(
                LayoutDiagnostic(
                    code=LayoutError.INVALID_SPEC,
                    severity=LayoutSeverity.ERROR,
                    message=axis_name + " bound is not finite",
                    node_ids=[node_id_str],
                )
            );
        }
    }
    if diags {
        return diags;
    }
    if size.minimum < 0.0 {
        diags.append(
            LayoutDiagnostic(
                code=LayoutError.INVALID_SPEC,
                severity=LayoutSeverity.ERROR,
                message=axis_name + " minimum is negative",
                node_ids=[node_id_str],
            )
        );
    }
    if size.maximum is not None and size.minimum > size.maximum {
        diags.append(
            LayoutDiagnostic(
                code=LayoutError.INVALID_SPEC,
                severity=LayoutSeverity.ERROR,
                message=axis_name + " minimum exceeds maximum",
                node_ids=[node_id_str],
            )
        );
    }
    if size.mode == SizeMode.FIXED and size.preferred is None {
        diags.append(
            LayoutDiagnostic(
                code=LayoutError.INVALID_SPEC,
                severity=LayoutSeverity.ERROR,
                message=axis_name + " FIXED requires preferred",
                node_ids=[node_id_str],
            )
        );
    }
    if size.mode == SizeMode.GROW
        and (not is_finite(size.grow_weight) or size.grow_weight <= 0.0) {
        diags.append(
            LayoutDiagnostic(
                code=LayoutError.INVALID_SPEC,
                severity=LayoutSeverity.ERROR,
                message=axis_name + " GROW requires a positive finite weight",
                node_ids=[node_id_str],
            )
        );
    }
    return diags;
}


impl _kind_label(kind: LayoutRelationKind) -> str {
    if kind == LayoutRelationKind.LEFT_OF {
        return "LEFT_OF";
    }
    if kind == LayoutRelationKind.RIGHT_OF {
        return "RIGHT_OF";
    }
    if kind == LayoutRelationKind.ABOVE {
        return "ABOVE";
    }
    if kind == LayoutRelationKind.BELOW {
        return "BELOW";
    }
    if kind == LayoutRelationKind.ALIGN_START {
        return "ALIGN_START";
    }
    if kind == LayoutRelationKind.ALIGN_END {
        return "ALIGN_END";
    }
    if kind == LayoutRelationKind.ALIGN_CENTER {
        return "ALIGN_CENTER";
    }
    return "SAME_SIZE";
}


impl _axis_label(axis: Axis) -> str {
    if axis == Axis.HORIZONTAL {
        return "horizontal";
    }
    return "vertical";
}


impl validate_spec(spec: LayoutSpec, node_id_str: str = "") -> list[LayoutDiagnostic] {
    diags = _validate_axis_size("width", spec.width, node_id_str);
    for d in _validate_axis_size("height", spec.height, node_id_str) {
        diags.append(d);
    }
    return diags;
}


impl set_spec(state: LayoutState, target: UiNode, spec: LayoutSpec) -> MutationResult {
    id_str = node_id(target);
    diags = validate_spec(spec, id_str);
    if diags {
        return MutationResult(ok=False, diagnostics=diags);
    }
    state.specs[id_str] = spec;
    return _ok();
}


impl _validate_relation_shape(rel: LayoutRelation) -> LayoutDiagnostic | None {
    directional = (
        rel.kind == LayoutRelationKind.LEFT_OF
        or rel.kind == LayoutRelationKind.RIGHT_OF
        or rel.kind == LayoutRelationKind.ABOVE
        or rel.kind == LayoutRelationKind.BELOW
    );
    alignment = (
        rel.kind == LayoutRelationKind.ALIGN_START
        or rel.kind == LayoutRelationKind.ALIGN_END
        or rel.kind == LayoutRelationKind.ALIGN_CENTER
        or rel.kind == LayoutRelationKind.SAME_SIZE
    );
    if directional {
        horizontal_kind = (
            rel.kind == LayoutRelationKind.LEFT_OF
            or rel.kind == LayoutRelationKind.RIGHT_OF
        );
        expected = Axis.HORIZONTAL if horizontal_kind else Axis.VERTICAL;
        if rel.axis != expected {
            return LayoutDiagnostic(
                code=LayoutError.INVALID_RELATION,
                severity=LayoutSeverity.ERROR,
                message=_kind_label(rel.kind)
                    + " requires axis "
                    + _axis_label(expected),
            );
        }
    }
    if not is_finite(rel.gap) or rel.gap < 0.0 {
        return LayoutDiagnostic(
            code=LayoutError.INVALID_RELATION,
            severity=LayoutSeverity.ERROR,
            message="relation gap must be finite and non-negative",
        );
    }
    if alignment and rel.gap != 0.0 {
        return LayoutDiagnostic(
            code=LayoutError.INVALID_RELATION,
            severity=LayoutSeverity.ERROR,
            message="alignment/size relations require gap == 0",
        );
    }
    return None;
}


impl add_relation(state: LayoutState, relation: LayoutRelation) -> MutationResult {
    diag = _validate_relation_shape(relation);
    if diag is not None {
        return MutationResult(ok=False, diagnostics=[diag]);
    }
    missing: list[str] = [];
    if relation.source_id not in state.specs {
        missing.append(relation.source_id);
    }
    if relation.target_id not in state.specs {
        missing.append(relation.target_id);
    }
    if missing {
        return _error(
            LayoutError.STALE_NODE, "relation endpoints are not registered", missing,
        );
    }
    if relation.owner_id not in state.specs {
        return _error(
            LayoutError.STALE_NODE,
            "relation owner is not registered",
            [relation.owner_id],
        );
    }

    for existing in state.relations.values() {
        if (
            existing.source_id == relation.source_id
            and existing.target_id == relation.target_id
            and existing.kind == relation.kind
            and existing.axis == relation.axis
            and existing.gap == relation.gap
        ) {
            if existing.strength == relation.strength {
                if relation.provenance not in [p for p in [existing.provenance]] {
                    existing.provenance = (
                        existing.provenance + ";" + relation.provenance
                    );
                }
                return _ok();
            }
            return _error(
                LayoutError.INVALID_RELATION,
                "duplicate relation expression with different strength",
                [relation.source_id, relation.target_id],
            );
        }
    }

    handle = RelationHandle(id=state.next_relation_id);
    state.next_relation_id += 1;
    state.relations[handle.id] = LayoutRelation(
        owner_id=relation.owner_id,
        source_id=relation.source_id,
        target_id=relation.target_id,
        kind=relation.kind,
        axis=relation.axis,
        gap=relation.gap,
        strength=relation.strength,
        provenance=relation.provenance,
    );
    return MutationResult(ok=True, relation_handle=handle);
}


impl remove_relation(state: LayoutState, handle: RelationHandle) -> MutationResult {
    if handle.id not in state.relations {
        return _error(LayoutError.INVALID_RELATION, "unknown relation handle");
    }
    state.relations.pop(handle.id);
    return _ok();
}


impl set_content(
    state: LayoutState,
    target: UiNode,
    lines: list[str],
    content_revision: int,
    style_revision: int = 0,
) -> MutationResult {
    id_str = node_id(target);
    if id_str not in state.specs {
        return _error(
            LayoutError.STALE_NODE, "content for unregistered node", [id_str]
        );
    }
    prior = state.content.get(id_str);
    if prior is not None
        and (
            content_revision < prior.content_revision
            or style_revision < prior.style_revision
        ) {
        return _error(
            LayoutError.INVALID_SPEC,
            "content/style revisions cannot decrease",
            [id_str],
        );
    }
    state.content[id_str] = ContentEntry(
        lines=[line for line in lines],
        content_revision=content_revision,
        style_revision=style_revision,
    );
    state.measurement_cache.pop(id_str, None);
    invalidate_measurement_cache(id_str);
    return _ok();
}


impl set_scroll_offset(
    state: LayoutState, target: UiNode, requested_offset: int
) -> MutationResult {
    id_str = node_id(target);
    if id_str not in state.specs {
        return _error(LayoutError.STALE_NODE, "scroll for unregistered node", [id_str]);
    }
    state.specs[id_str].scroll_vertical = True;
    state.scroll_requests[id_str] = max(0, requested_offset);
    ent = state.content.get(id_str);
    if ent is None {
        state.content[id_str] = ContentEntry(
            lines=[], content_revision=0, style_revision=0,
        );
    }
    return _ok();
}


impl clear_node(state: LayoutState, target: UiNode) -> MutationResult {
    id_str = node_id(target);
    doomed: list[int] = [];
    for rid in sorted(state.relations.keys()) {
        rel = state.relations[rid];
        if (
            rel.owner_id == id_str or rel.source_id == id_str or rel.target_id == id_str
        ) {
            doomed.append(rid);
        }
    }
    for rid in doomed {
        state.relations.pop(rid);
    }
    state.specs.pop(id_str, None);
    state.content.pop(id_str, None);
    state.measurement_cache.pop(id_str, None);
    invalidate_measurement_cache(id_str);
    return _ok();
}


impl frame_entry_of(state: LayoutState, target: UiNode) -> FrameEntry | None {
    if state.last_frame is None {
        return None;
    }
    ent = state.last_frame.entries.get(node_id(target));
    if ent is None {
        return None;
    }
    return FrameEntry(
        measured=Size(width=ent.measured.width, height=ent.measured.height),
        rect=_copy_rect(ent.rect),
        clip=_copy_rect(ent.clip),
        wrapped_lines=[line for line in ent.wrapped_lines],
        requested_scroll_offset=ent.requested_scroll_offset,
        scroll_offset=ent.scroll_offset,
        max_scroll_offset=ent.max_scroll_offset,
    );
}


impl rect_of(state: LayoutState, target: UiNode) -> Rect | None {
    ent = frame_entry_of(state, target);
    if ent is None {
        return None;
    }
    return _copy_rect(ent.rect);
}


impl _copy_rect(r: Rect) -> Rect {
    return Rect(x=r.x, y=r.y, width=r.width, height=r.height);
}
