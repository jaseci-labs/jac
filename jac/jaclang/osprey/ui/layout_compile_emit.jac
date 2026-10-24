def _req(v: float | None) -> float;


def _t(v: Variable, coefficient: float = 1.0) -> Term;


def _expr(terms: list[Term], constant: float = 0.0) -> Expression;


def _prov(
    template: str,
    id_str: str,
    axis_label: str,
    key: str = "",
    parent: str = "",
    rank: int = -1,
    src: str = "",
    extra: str = "",
) -> str;


def _emit(
    result: CompileResult,
    expr: Expression,
    relation: Relation,
    strength: StrengthTier,
    provenance: str,
) -> bool;


def _axis_start(edges: NodeEdges, horizontal: bool) -> Variable;


def _axis_end(edges: NodeEdges, horizontal: bool) -> Variable;


def _emit_pin_edge(
    result: CompileResult, v: Variable, target: float, id_str: str, axis_label: str,
) -> bool;


def _emit_root(
    result: CompileResult, edges: NodeEdges, viewport: Viewport, phase: str,
) -> bool;


def _emit_invariants(result: CompileResult, edges: NodeEdges, phase: str,) -> bool;


def _emit_sized_axis(
    result: CompileResult,
    size: AxisSize,
    start: Variable,
    end: Variable,
    horizontal: bool,
    id_str: str,
    natural: float | None,
    src_extra: str,
) -> bool;


def _emit_pin(
    result: CompileResult,
    child_start: Variable,
    child_end: Variable,
    parent_start: Variable,
    parent_end: Variable,
    horizontal: bool,
    id_str: str,
    template: str,
) -> bool;


def _emit_cross_align(
    result: CompileResult,
    child: NodeEdges,
    parent: NodeEdges,
    spec: LayoutSpec,
    horizontal: bool,
) -> bool;


def _emit_cross_axis(
    result: CompileResult,
    kid: _Entry,
    parent: _Entry,
    natural_sizes: dict[str, Size],
    horizontal: bool,
) -> bool;

impl _req(v: float | None) -> float {
    if v is None {
        return 0.0;
    }
    return v;
}


impl _t(v: Variable, coefficient: float = 1.0) -> Term {
    return Term(variable=v, coefficient=coefficient);
}


impl _expr(terms: list[Term], constant: float = 0.0) -> Expression {
    return normalize_expression(Expression(terms=terms, constant=constant));
}


impl _prov(
    template: str,
    id_str: str,
    axis_label: str,
    key: str = "",
    parent: str = "",
    rank: int = -1,
    src: str = "",
    extra: str = "",
) -> str {
    out = "template=" + template + " node=" + id_str;
    if key != "" {
        out = out + ":" + key;
    }
    out = out + " axis=" + axis_label;
    if parent != "" {
        out = out + " parent=" + parent + "#" + str(rank);
    }
    if src != "" {
        out = out + " src=" + src;
    }
    if extra != "" {
        out = out + " " + extra;
    }
    return out;
}


impl _emit(
    result: CompileResult,
    expr: Expression,
    relation: Relation,
    strength: StrengthTier,
    provenance: str,
) -> bool {
    s = result.solver;
    if s is None {
        return False;
    }
    c = Constraint(expression=expr, relation=relation, strength=strength);
    res = s.add_constraint(c, provenance=provenance);
    if not res.ok {
        code = LayoutError.INVALID_RELATION;
        if res.error == SolveError.UNSATISFIABLE {
            code = LayoutError.UNSATISFIABLE;
        }
        witnesses = [provenance];
        for w in res.witness_provenance {
            witnesses.append(w);
        }
        result.diagnostics.append(
            LayoutDiagnostic(
                code=code,
                severity=LayoutSeverity.ERROR,
                message=res.message,
                provenance=witnesses,
            )
        );
        result.ok = False;
        return False;
    }
    return True;
}


impl _axis_start(edges: NodeEdges, horizontal: bool) -> Variable {
    return edges.left if horizontal else edges.top;
}


impl _axis_end(edges: NodeEdges, horizontal: bool) -> Variable {
    return edges.right if horizontal else edges.bottom;
}


impl _emit_pin_edge(
    result: CompileResult, v: Variable, target: float, id_str: str, axis_label: str,
) -> bool {
    return _emit(
        result,
        _expr([_t(v)], -target),
        Relation.EQ,
        StrengthTier.REQUIRED,
        _prov("root", id_str, axis_label),
    );
}


impl _emit_root(
    result: CompileResult, edges: NodeEdges, viewport: Viewport, phase: str,
) -> bool {
    id_str = edges.id_str;
    if _wants(phase, True) {
        if not _emit_pin_edge(result, edges.left, 0.0, id_str, "h") {
            return False;
        }
        if not _emit_pin_edge(
            result, edges.right, float(viewport.columns), id_str, "h"
        ) {
            return False;
        }
    }
    if _wants(phase, False) {
        if not _emit_pin_edge(result, edges.top, 0.0, id_str, "v") {
            return False;
        }
        if not _emit_pin_edge(
            result, edges.bottom, float(viewport.rows), id_str, "v"
        ) {
            return False;
        }
    }
    return True;
}


impl _emit_invariants(result: CompileResult, edges: NodeEdges, phase: str,) -> bool {
    id_str = edges.id_str;
    if _wants(phase, True) {
        if not _emit(
            result,
            _expr([_t(edges.right), _t(edges.left, -1.0)]),
            Relation.GEQ,
            StrengthTier.REQUIRED,
            _prov("invariant", edges.id_str, "h"),
        ) {
            return False;
        }
    }
    if _wants(phase, False) {
        return _emit(
            result,
            _expr([_t(edges.bottom), _t(edges.top, -1.0)]),
            Relation.GEQ,
            StrengthTier.REQUIRED,
            _prov("invariant", edges.id_str, "v"),
        );
    }
    return True;
}


impl _emit_sized_axis(
    result: CompileResult,
    size: AxisSize,
    start: Variable,
    end: Variable,
    horizontal: bool,
    id_str: str,
    natural: float | None,
    src_extra: str,
) -> bool {
    label = "h" if horizontal else "v";
    span_terms = [_t(end), _t(start, -1.0)];
    if size.mode == SizeMode.FIXED {
        return _emit(
            result,
            _expr(span_terms, -_req(size.preferred)),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("fixed", id_str, label, src_extra),
        );
    }
    if size.mode == SizeMode.INTRINSIC {
        if natural is None {
            return True;
        }
        return _emit(
            result,
            _expr(span_terms, -natural),
            Relation.EQ,
            StrengthTier.WEAK,
            _prov("intrinsic", id_str, label, src_extra),
        );
    }
    if size.mode == SizeMode.BOUNDED {
        if size.minimum > 0.0 {
            if not _emit(
                result,
                _expr(span_terms, -size.minimum),
                Relation.GEQ,
                StrengthTier.REQUIRED,
                _prov("bounded", id_str, label, src_extra),
            ) {
                return False;
            }
        }
        if size.maximum is not None and is_finite(size.maximum) {
            if not _emit(
                result,
                _expr(span_terms, -size.maximum),
                Relation.LEQ,
                StrengthTier.REQUIRED,
                _prov("bounded", id_str, label, src_extra),
            ) {
                return False;
            }
        }
        if size.preferred is not None {
            return _emit(
                result,
                _expr(span_terms, -_req(size.preferred)),
                Relation.EQ,
                StrengthTier.WEAK,
                _prov("bounded", id_str, label, src_extra),
            );
        }
        return True;
    }

    return True;
}


impl _emit_pin(
    result: CompileResult,
    child_start: Variable,
    child_end: Variable,
    parent_start: Variable,
    parent_end: Variable,
    horizontal: bool,
    id_str: str,
    template: str,
) -> bool {
    label = "h" if horizontal else "v";
    if not _emit(
        result,
        _expr([_t(child_start), _t(parent_start, -1.0)]),
        Relation.EQ,
        StrengthTier.REQUIRED,
        _prov(template, id_str, label),
    ) {
        return False;
    }
    return _emit(
        result,
        _expr([_t(child_end), _t(parent_end, -1.0)]),
        Relation.EQ,
        StrengthTier.REQUIRED,
        _prov(template, id_str, label),
    );
}


impl _emit_cross_align(
    result: CompileResult,
    child: NodeEdges,
    parent: NodeEdges,
    spec: LayoutSpec,
    horizontal: bool,
) -> bool {
    label = "h" if horizontal else "v";
    start_c = _axis_start(child, horizontal);
    end_c = _axis_end(child, horizontal);
    start_p = _axis_start(parent, horizontal);
    end_p = _axis_end(parent, horizontal);
    if spec.cross_align == Align.START {
        return _emit(
            result,
            _expr([_t(start_c), _t(start_p, -1.0)]),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("align", child.id_str, label),
        );
    }
    if spec.cross_align == Align.END {
        return _emit(
            result,
            _expr([_t(end_c), _t(end_p, -1.0)]),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("align", child.id_str, label),
        );
    }
    if spec.cross_align == Align.CENTER {
        return _emit(
            result,
            _expr([_t(start_c), _t(end_c), _t(start_p, -1.0), _t(end_p, -1.0)]),
            Relation.EQ,
            StrengthTier.REQUIRED,
            _prov("align", child.id_str, label),
        );
    }
    return True;
}


impl _emit_cross_axis(
    result: CompileResult,
    kid: _Entry,
    parent: _Entry,
    natural_sizes: dict[str, Size],
    horizontal: bool,
) -> bool {
    kid_spec = kid.spec;
    kid_edges = kid.edges;
    parent_edges = parent.edges;
    cross_mode: SizeMode;
    natural: float | None = None;
    if horizontal {
        cross_mode = kid_spec.width.mode;
        if kid_edges.id_str in natural_sizes {
            natural = float(natural_sizes[kid_edges.id_str].width);
        }
        cross_size = kid_spec.width;
    } else {
        cross_mode = kid_spec.height.mode;
        if kid_edges.id_str in natural_sizes {
            natural = float(natural_sizes[kid_edges.id_str].height);
        }
        cross_size = kid_spec.height;
    }

    stretch = (
        cross_mode == SizeMode.FILL
        or cross_mode == SizeMode.GROW
        or (kid_spec.cross_align == Align.STRETCH and cross_mode != SizeMode.FIXED)
    );
    if stretch {
        template = "fill";
        if cross_mode == SizeMode.GROW {
            template = "stretch";
        }
        return _emit_pin(
            result,
            _axis_start(kid_edges, horizontal),
            _axis_end(kid_edges, horizontal),
            _axis_start(parent_edges, horizontal),
            _axis_end(parent_edges, horizontal),
            horizontal,
            kid_edges.id_str,
            template,
        );
    }

    if not _emit_sized_axis(
        result,
        cross_size,
        _axis_start(kid_edges, horizontal),
        _axis_end(kid_edges, horizontal),
        horizontal,
        kid_edges.id_str,
        natural,
        "parent=" + parent_edges.id_str,
    ) {
        return False;
    }
    if kid_spec.cross_align == Align.STRETCH {
        return True;
    }
    return _emit_cross_align(result, kid_edges, parent_edges, kid_spec, horizontal);
}
