def _emit_relation(
    result: CompileResult,
    rid: int,
    rel: LayoutRelation,
    edges_by_id: dict[str, NodeEdges],
    phase: str = "full",
) -> bool;

impl _emit_relation(
    result: CompileResult,
    rid: int,
    rel: LayoutRelation,
    edges_by_id: dict[str, NodeEdges],
    phase: str = "full",
) -> bool {
    s = edges_by_id[rel.source_id];
    tgt = edges_by_id[rel.target_id];
    k = rel.kind;
    gap = rel.gap;
    horizontal_axis = rel.axis.value == "horizontal";
    axis_label = "h" if horizontal_axis else "v";
    prov = (
        "template=relation rel="
        + str(rid)
        + " src="
        + rel.provenance
        + " axis="
        + axis_label
    );

    if not _wants(phase, rel.axis.value == "horizontal") {
        return True;
    }

    terms: list[Term] = [];
    constant = 0.0;

    if k == LayoutRelationKind.LEFT_OF {
        terms = [_t(s.right), _t(tgt.left, -1.0)];
        constant = -gap;
    } elif k == LayoutRelationKind.RIGHT_OF {
        terms = [_t(s.left), _t(tgt.right, -1.0)];
        constant = gap;
    } elif k == LayoutRelationKind.ABOVE {
        terms = [_t(s.bottom), _t(tgt.top, -1.0)];
        constant = -gap;
    } elif k == LayoutRelationKind.BELOW {
        terms = [_t(s.top), _t(tgt.bottom, -1.0)];
        constant = gap;
    } elif k == LayoutRelationKind.ALIGN_START {
        if horizontal_axis {
            terms = [_t(s.left), _t(tgt.left, -1.0)];
        } else {
            terms = [_t(s.top), _t(tgt.top, -1.0)];
        }
    } elif k == LayoutRelationKind.ALIGN_END {
        if horizontal_axis {
            terms = [_t(s.right), _t(tgt.right, -1.0)];
        } else {
            terms = [_t(s.bottom), _t(tgt.bottom, -1.0)];
        }
    } elif k == LayoutRelationKind.ALIGN_CENTER {
        if horizontal_axis {
            terms = [
                _t(s.left),
                _t(s.right),
                _t(tgt.left, -1.0),
                _t(tgt.right, -1.0),

            ];
        } else {
            terms = [
                _t(s.top),
                _t(s.bottom),
                _t(tgt.top, -1.0),
                _t(tgt.bottom, -1.0),

            ];
        }
    } else {
        if horizontal_axis {
            terms = [
                _t(s.right),
                _t(s.left, -1.0),
                _t(tgt.right, -1.0),
                _t(tgt.left, 1.0),

            ];
        } else {
            terms = [
                _t(s.bottom),
                _t(s.top, -1.0),
                _t(tgt.bottom, -1.0),
                _t(tgt.top, 1.0),

            ];
        }
    }

    return _emit(result, _expr(terms, constant), Relation.EQ, rel.strength, prov);
}
