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
